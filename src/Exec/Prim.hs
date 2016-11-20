module Exec.Prim where

import Control.Monad
import Data.List (find)
import Syntactic
import PosParsec
import Types

-- = Program State

-- | Scope level
data Scope = Global 
           | Local Int
           deriving (Show, Eq)


-- | Value
data Val = IntVal Int
         | FloatVal Float
         | BoolVal Bool
         | None
         deriving (Show, Eq)


instance Typed Val where
    toType (IntVal _) = IntType
    toType (FloatVal _) = FloatType
    toType (BoolVal _) = BoolType
    toType None = NoneType


-- | Variable
data Var = Var { getVarName :: String 
               , getVarType :: Type
               , getVarValue :: Val
               , getVarScope :: Scope
               } deriving (Show)


instance Typed Var where
    toType = getVarType


data Proc = NativeProc Name Type ([Val] -> Exec ())
          | Proc SynProc


instance Typed Proc where
    toType (NativeProc _ t _) = t
    toType (Proc sproc) = toType sproc


instance Named Proc where
    getName (NativeProc n _ _) = n
    getName (Proc sproc) = getName sproc


-- | Update variable value
setVarValue :: Var -> Val -> Var
setVarValue var val =
    Var (getVarName var) (getVarType var) val (getVarScope var)


-- | Update variable scope
setVarScope :: Var -> Scope -> Var
setVarScope var scope =
    Var (getVarName var) (getVarType var) (getVarValue var) scope


type ProcTable = [Proc]

-- | Program State
data ProgramState =
    State { getVarTable :: [Var] -- ^ Variable table
          , getStructTable :: [Type] -- ^ Struct table
          , getProcTable :: ProcTable -- ^ Procedure table
          , getFuncTable :: [SynFunc] -- ^ Function table
          }


-- | Initial program state
newProgramState :: ProgramState
newProgramState = State [] [] [] []


-- = Execution monad

-- | Execution monad
-- Contains a state updating function and
-- a value obtention function
data Exec a =
    Exec { execEvalIO :: ProgramState -> IO (ProgramState, a) }


-- | Run execution, ignore value
execIO :: Exec a -> ProgramState -> IO ProgramState
execIO ex state = fmap fst $ execEvalIO ex state


-- | Run execution, ignore new state
evalIO :: Exec a -> ProgramState -> IO a
evalIO ex state = fmap snd $ execEvalIO ex state


-- | Create valueless execution part
mkExec :: (ProgramState -> IO ProgramState)
       -> Exec ()
mkExec f = Exec $ \state ->
    do state' <- f state
       return (state', ())


-- | Create evaluation execution part with no side effects
mkEval :: (ProgramState -> IO a)
       -> Exec a
mkEval f = Exec $ \state ->
    do val <- f state
       return (state, val)


execfmap :: (a -> b) -> Exec a -> Exec b
execfmap f (Exec x) = Exec $
    \state -> do evalexec <- x state
                 let state' = fst evalexec
                     val = snd evalexec
                 return (state', f val)


execunit :: a -> Exec a
execunit u = Exec $
    \state -> return (state, u)


execbind :: Exec a -> (a -> Exec b) -> Exec b
execbind m k = Exec $
    \state -> do mid <- execEvalIO m state
                 let state' = fst mid
                     val = snd mid
                 execEvalIO (k val) state'


instance Functor Exec where
    fmap = execfmap


instance Applicative Exec where
    pure = execunit
    (<*>) = ap


instance Monad Exec where
    return = execunit
    (>>=) = execbind


-- = Table access execution

-- | Get current variable table
obtainVarTable :: Exec [Var]
obtainVarTable = mkEval $ return . getVarTable


-- | Set current variable table
modifyVarTable :: [Var] -> Exec ()
modifyVarTable vt = mkExec $
    \state -> let st = getStructTable state
                  pt = getProcTable state
                  ft = getFuncTable state
               in return (State vt st pt ft)


-- | Get current struct table
obtainStructTable :: Exec [Type]
obtainStructTable = mkEval $ return . getStructTable


-- | Get current procedure table
obtainProcTable :: Exec ProcTable
obtainProcTable = mkEval $ return . getProcTable


-- | Set current procedure table
modifyProcTable :: ProcTable -> Exec ()
modifyProcTable pt = mkExec $
    \state -> let vt = getVarTable state
                  st = getStructTable state
                  ft = getFuncTable state
               in return (State vt st pt ft)


-- | Get current function table
obtainFuncTable :: Exec [SynFunc]
obtainFuncTable = mkEval $ return . getFuncTable


-- | Set current procedure table
modifyFuncTable :: [SynFunc] -> Exec ()
modifyFuncTable ft = mkExec $
    \state -> let vt = getVarTable state
                  st = getStructTable state
                  pt = getProcTable state
               in return (State vt st pt ft)



-- = Auxiliary functions

-- == Debug

-- | Print line
runPrintLn :: String -> Exec ()
runPrintLn s = mkExec $ \state ->
    do putStrLn s
       return state

-- | Prints full variable table
runStatus :: Exec ()
runStatus =
    do vt <- obtainVarTable
       runPrintLn "status> "
       mapM_ (runPrintLn . show) vt


-- == Procedure table auxiliary functions

findProc :: String -> Type -> Exec Proc
findProc procname proctype =
    do procs <- obtainProcTable
       let matchname = (==procname) . getName
           matchtype = (==proctype) . toType
           proc = find (\s -> matchname s && matchtype s) procs
       case proc of
         Just p -> return p
         Nothing -> error $ "couldn't find procedure " ++ procname


-- | Register procedure into procedure table
registerProc :: SynProc -> Exec ()
registerProc p =
    do procs <- obtainProcTable
       modifyProcTable $ (Proc p) : procs


-- == Function table auxiliary functions

findFunc :: String -> Exec SynFunc
findFunc funcname =
    do funcs <- obtainFuncTable
       let func = find ((==funcname) . getFuncName) funcs
       case func of
         Just d -> return d
         Nothing -> error $ "couldn't find function " ++ funcname


-- | Register function into function table
registerFunc :: SynFunc -> Exec ()
registerFunc f =
    do funcs <- obtainFuncTable
       modifyFuncTable $ f : funcs


-- == Struct table auxiliary functions

findType :: SynType -> Exec Type
findType (SynType locident)
  | i == "int" = return IntType
  | i == "float" = return FloatType
  | i == "bool" = return BoolType
  | otherwise = error $ "couldn't find type " ++ i
  where i = getlabel . ignorepos $ locident


-- == Variable table auxiliary functions

-- | Search for variable on table
findVar :: String -> Exec Var
findVar varname =
    do vars <- obtainVarTable
       let var = find ((== varname) . getVarName) vars
       case var of
         Just p -> return p
         Nothing -> error $ "variable not found: " ++ varname


-- | Define local variable
registerLocalVar :: String -> Type -> Val -> Exec ()
registerLocalVar vname vtype vvalue =
    do vt <- obtainVarTable
       modifyVarTable $ Var vname vtype vvalue (Local 0) : vt 


-- | Define local variable with no value
registerLocalUndefVar :: String -> Type -> Exec ()
registerLocalUndefVar vname vtype =
    registerLocalVar vname vtype None 


-- | Increment scope level for local variables
raiseScope :: Exec ()
raiseScope =
    do vt <- obtainVarTable
       modifyVarTable $ foldl raise [] vt
    where
        raise vt var =
            case getVarScope var of
              (Local n) -> setVarScope var (Local $ n+1) : vt
              _ -> var:vt


-- | Decrement scope level for local variables
dropScope :: Exec ()
dropScope =
    do vt <- obtainVarTable
       modifyVarTable $ foldl drop [] vt
    where
        drop vt var =
            case getVarScope var of
              (Local 0) -> vt
              (Local n) -> setVarScope var (Local $ n-1) : vt
              _ -> var:vt


-- | Return scope and clear local variables
saveAndClearScope :: Exec [Var]
saveAndClearScope =
    do vt <- obtainVarTable
       modifyVarTable $ filter ((== Global) . getVarScope) vt
       return vt


-- | Change variable value by name
changeVar :: String -> Val -> Exec ()
changeVar vname val =
    do vt <- obtainVarTable
       let vt' = updateWhen ((==vname) . getVarName) vt val
       modifyVarTable vt'
    where 
        updateWhen _ [] _ = []
        updateWhen cond (v:vs) value
          | cond v = setVarValue v value : vs
          | otherwise = v : updateWhen cond vs value


