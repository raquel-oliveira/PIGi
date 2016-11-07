module Syntactic where

import Control.Monad.Identity
import Text.Parsec (eof)
import Text.Parsec.Prim
import Text.Parsec.Expr
import PosParsec
import Lexical

type SynParser a = Parsec [PosLexToken] () (Located a)

-- | Create a SynParser from an lexical test function
syntoken :: Show a => (LexToken -> Maybe a) -> SynParser a
syntoken test =
    token showTok nextPos testTok
        where showTok = show . ignorepos
              nextPos = getpos
              reloc t = fmap $ mklocated . getpos $ t
              testTok t = reloc t . test . ignorepos $ t


-- | Generic syntactic construct, based on lexical token
-- use only with informationless tokens, like {, ( and =
data SynToken = SynToken { getlex :: LexToken } deriving (Show)

-- | SynParser for SynToken, given the original lexical token.
-- For example, to create an '(' parser,
-- > synlex LexLParen
synlex :: LexToken -> SynParser SynToken
synlex lextok = syntoken $
    \t -> if t == lextok then Just (SynToken t) else Nothing


-- | Syntactic construct for identifier
data SynIdent = SynIdent { getlabel :: String } deriving (Show)

-- | SynParser for identifier
synident :: SynParser SynIdent
synident = syntoken $
    \t -> case t of
            (LexIdent s) -> Just (SynIdent s)
            _ -> Nothing


-- | Syntactic construct for integer literal
data SynLitInt = SynLitInt { getint :: Int } deriving (Show)

-- | SynParser for integer literal
synlitint :: SynParser SynLitInt
synlitint = syntoken $
    \t -> case t of
            (LexLitInt i) -> Just (SynLitInt i)
            _ -> Nothing


data SynExpr = SynVal (Located SynIdent)
             | SynPlus (Located SynExpr) (Located SynExpr)
             | SynTimes (Located SynExpr) (Located SynExpr)
             deriving (Show)

synexprval :: SynParser SynExpr
synexprval = locate $
    do val <- synident
       return $ SynVal val

synexprop :: LexToken
          -> (Located SynExpr -> Located SynExpr -> SynExpr)
          -> Parsec [PosLexToken] () (Located SynExpr
                                     -> Located SynExpr
                                     -> Located SynExpr)
synexprop opToken constr =
    do tok <- synlex opToken
       return $ \e1 e2 -> mklocated (getpos tok) $ constr e1 e2

synoptable :: OperatorTable [PosLexToken] () Identity (Located SynExpr)
synoptable = [[Infix (synexprop LexPlus SynPlus) AssocLeft],
              [Infix (synexprop LexTimes SynTimes) AssocLeft]]

synexpr :: SynParser SynExpr
synexpr = buildExpressionParser synoptable synexprval

-- !! EVERYTHING BELOW THIS LINE IS WRONG !!

-- | Syntactic construct for module
data SynModule = SynModule [Located SynExpr] deriving (Show)

-- | SynParser for whole module
synmodule :: SynParser SynModule
synmodule = locate $
    do ids <- many synexpr
       eof
       return (SynModule ids)
