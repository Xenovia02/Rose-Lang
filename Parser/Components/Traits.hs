module Parser.Components.Traits (
    traitDecl,
    traitImpl,
) where

import Text.Parsec (
    option, many, many1, (<|>),
    )

import Parser.Components.Functions
import Parser.Components.Identifiers
import Parser.Components.Internal.LangDef (
    keyword,
    angles, braces,
    commaSep1,
    )
import Parser.Components.Specifiers
import Parser.Components.Types
import Parser.Data (
    Parser,
    Context,
    Expr(TraitDecl,TraitImpl),
    )


-- = "<", constraint, { ",", constraint }, ">";
traitCtx :: Parser Context
traitCtx = option [] (angles (commaSep1 constraint))

-- = visib, "trait", [trait-ctx], big-ident,
--     small-ident, {small-ident},
--     "{", {func-decl}, "}";
traitDecl :: Parser Expr
traitDecl = do
    vis <- visibility
    keyword "trait"
    ctx <- traitCtx
    name <- bigIdent
    tVars <- many1 smallIdent
    fns <- braces (many (funcDecl <|> funcDef))
    return (TraitDecl vis ctx name tVars fns)

-- = "impl", [trait-ctx], big-ident, type, {type},
--     "{", {func-def}, "}";
traitImpl :: Parser Expr
traitImpl = do
    keyword "impl"
    ctx <- traitCtx
    name <- bigIdent
    tVars <- many1 ttype
    fns <- braces (many funcDef)
    return (TraitImpl ctx name tVars fns)
