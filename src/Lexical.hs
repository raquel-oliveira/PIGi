  module Lexical where

import Text.Parsec
import Text.Parsec.Char
import qualified Text.ParserCombinators.Parsec.Number as Number
import PosParsec

-- | Lexical token type
data LexToken = LexLParen         -- ^ @(@ token
              | LexRParen         -- ^ @)@ token
              | LexLBracket       -- ^ @[@ token
              | LexRBracket       -- ^ @]@ token
              | LexLBraces        -- ^ @{@ token
              | LexRBraces        -- ^ @}@ token
              | LexColon          -- ^ @:@ token
              | LexSemicolon      -- ^ @;@ token
              | LexComma          -- ^ @,@ token
              | LexArrow          -- ^ @->@ token
              | LexParallel       -- ^ @//@ token
              | LexRange          -- ^ @..@ token
              | LexAttr           -- ^ @=@ token
              | LexPlusAttr       -- ^ @+=@ token
              | LexMinusAttr      -- ^ @-=@ token
              | LexTimesAttr      -- ^ @*=@ token
              | LexDivAttr        -- ^ @/=@ token
              | LexPlus           -- ^ @+@ token
              | LexMinus          -- ^ @-@ token
              | LexTimes          -- ^ @*@ token
              | LexDiv            -- ^ @/@ token
              | LexDotTimes       -- ^ @.*.@ token
              | LexDotDiv         -- ^ @./.@ token
              | LexMod            -- ^ @mod@ token
              | LexDot            -- ^ @.@ token
              | LexExp            -- ^ @^@ token
              | LexBitAnd         -- ^ @&@ token
              | LexBitOr          -- ^ @|@ token
              | LexBitNot         -- ^ @!@ token
              | LexBitXor         -- ^ @~@ token
              | LexLShift         -- ^ @<<@ token
              | LexRShift         -- ^ @>>@ token
              | LexEQ             -- ^ @==@ token
              | LexNEQ            -- ^ @=/=@ token
              | LexLT             -- ^ @<@ token
              | LexLE             -- ^ @<=@ token
              | LexGT             -- ^ @>@ token
              | LexGE             -- ^ @>=@ token
              | LexAnd            -- ^ @and@ token
              | LexOr             -- ^ @or@ token
              | LexNot            -- ^ @not@ token
              | LexXor            -- ^ @xor@ token
              | LexDef            -- ^ @def@ token
              | LexFunc           -- ^ @func@ token
              | LexProc           -- ^ @proc@ token
              | LexStruct         -- ^ @struct@ token
              | LexIf             -- ^ @if@ token
              | LexElse           -- ^ @else@ token
              | LexWhile          -- ^ @while@ token
              | LexFor            -- ^ @for@ token
              | LexIn             -- ^ @in@ token
              | LexModConst
              | LexModMut
              | LexRef
              | LexIdent String   -- ^ identifier
              | LexLitInt Int     -- ^ @int@ literal
              | LexLitFloat Float -- ^ @float@ literal
              | LexLitBool Bool   -- ^ @bool@ literal
              | LexLitStr String  -- ^ @string@ literal
              | LexModule
              | Comment
              deriving (Show, Eq)

-- | Map between keywords and lexical tokens
keywordTable :: [(String, LexToken)]
keywordTable = [("and", LexAnd)
               ,("or", LexOr)
               ,("not", LexNot)
               ,("xor", LexXor)
               ,("module", LexModule) -- This must come before mod, otherwise we'll have problems!
               ,("mod", LexMod)
               ,("def", LexDef)
               ,("func", LexFunc)
               ,("proc", LexProc) 
               ,("struct", LexStruct)
               ,("if", LexIf)
               ,("else", LexElse)
               ,("while", LexWhile)
               ,("for", LexFor)
               ,("in", LexIn)
               ,("true", LexLitBool True)
               ,("false", LexLitBool False)
               ,("const", LexModConst)
               ,("mut", LexModMut)
               ,("ref", LexRef)
               ]

-- | Map between symbols and lexical tokens
symbolTable :: [(String, LexToken)]
symbolTable = [("(", LexLParen)
              ,(")", LexRParen)
              ,("[", LexLBracket)
              ,("]", LexRBracket)
              ,("{", LexLBraces)
              ,("}", LexRBraces)
              ,(":", LexColon)
              ,(";", LexSemicolon)
              ,(",", LexComma)
              ,("=/=", LexNEQ)
              ,("==", LexEQ)
              ,("=", LexAttr)
              ,("<<", LexLShift)
              ,("<=", LexLE)
              ,("<", LexLT)
              ,(">>", LexRShift)
              ,(">=", LexGE)
              ,(">", LexGT)
              ,("//", LexParallel)
              ,("+=", LexPlusAttr)
              ,("+", LexPlus)
              ,("->", LexArrow)
              ,("-=", LexMinusAttr)
              ,("-", LexMinus)
              ,("*=", LexTimesAttr)
              ,("*", LexTimes)
              ,("/=", LexDivAttr)
              ,("/", LexDiv)
              ,("&", LexBitAnd)
              ,("|", LexBitOr)
              ,("~", LexBitXor)
              ,("!", LexBitNot)
              ,("..", LexRange)
              ,(".*.", LexDotTimes)
              ,("./.", LexDotDiv)
              ,(".", LexDot)
              ,("^", LexExp)]

-- | Lists all keywords.
keywords :: [String]
keywords = (map fst keywordTable)

-- | A lexical token combined with its source code position
type PosLexToken = Located LexToken

-- | A parser for a lexical token.
type LexParser = Parsec String () PosLexToken

-- | Parses token by corresponding string.
lextoken :: LexToken -> String -> LexParser
lextoken token s = locate $
    do string s
       return token 

-- | Parses identifier.
lexident :: LexParser
lexident = locate $
    do c  <- letter <|> char '_'
       cs <- many (alphaNum <|> char '_')
       let word = c:cs in
           if word `elem` keywords
              then fail "identifier"
              else return (LexIdent word)

-- | Parses a token based on the given table
lextable :: [(String, LexToken)] -> LexParser
lextable [] = fail "tabled"
lextable ((s, token):ts) = try(lextoken token s) <|> lextable ts

-- | Parses a reserved word
lexreserved :: LexParser
lexreserved = lextable keywordTable <|> lextable symbolTable

-- | Parses a floating number literal
lexfloat :: LexParser
lexfloat = locate $ do
    v <- Number.floating
    return (LexLitFloat v)

-- | Parses a integer literal
lexint :: LexParser
lexint = locate $ do
    v <- Number.decimal
    return (LexLitInt v)

-- | Parses a number
lexnumber :: LexParser
lexnumber = try lexfloat <|> lexint

-- | Parses an escaped string character
escaped :: Parsec String () Char
escaped = do
    b <- char '\\'
    c <- oneOf "\\\"nrt"
    return . read $ ['\'', b, c, '\'']

-- | Parses a non-escaped string character
nonescaped :: Parsec String () Char
nonescaped = noneOf "\\\0\n\r\t\""

-- | Parses a string literal
lexstr :: LexParser
lexstr = locate $ do 
    char '\"'
    str <- many (escaped <|> nonescaped)
    char '\"'
    return $ LexLitStr str

-- | Parses any valid lexical token
lexunit :: LexParser
lexunit = do
    tk <- lexstr <|> try lexnumber <|> try lexident <|> lexreserved
    spaces
    return tk

-- | Parses a comment
comment :: LexParser
comment = locate $ do
    char '#'
    manyTill anyChar newline
    spaces
    return Comment

-- | PIG full lexical parser
lexparser :: Parsec String () [PosLexToken]
lexparser = do
    spaces
    tks <- many (comment <|> lexunit)
    eof
    return $ filter ((/=Comment) . ignorepos) tks
