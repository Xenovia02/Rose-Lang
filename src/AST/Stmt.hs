module AST.Stmt (
    Stmt(..),
    MatchCase(..),
) where

import AST.Value
import AST.Pattern
import Common.Specifiers
import Common.SrcPos
import Common.Var
import Text.Pretty
import Typing.TypeDecl


data Stmt
    = IfElse Value Stmt Stmt
    | Loop Stmt Stmt Stmt Stmt
    | Match Value [MatchCase]
    | NewVar Mutab !Var TypeDecl Value
    | Reassignment !Var Value
    | Return Value
    | ValStmt Value
    | Break
    | Continue
    | NullStmt
    | Compound [Stmt]

data MatchCase = Case Pattern Stmt


instance HasSrcPos Stmt where
    getPos (IfElse val _ _) = getPos val
    getPos (Loop stmt _ _ _) = getPos stmt
    getPos (Match val _) = getPos val
    getPos (NewVar _ name _ _) = getPos name
    getPos (Reassignment name _) = getPos name
    getPos (Return val) = getPos val
    getPos (ValStmt val) = getPos val
    getPos _ = UnknownPos

instance Pretty Stmt where
    pretty (IfElse val tb fb) =
        "if ("+|val|+") "+|tb|+"\n    else"+|fb
    pretty (Loop NullStmt cond NullStmt body) =
        "loop ("+|cond|+") "+|body
    pretty (Loop init' cond iter body) =
        "loop ("+|init'|+"; "+|cond|+"; "+|iter|+") "+|body
    pretty (Match val cases) = "match ("+|val|+") {\n"
        +|indentCatLns cases|+"}"
    pretty (NewVar mut name typ val) =
        "let "+|mut|+" "+|name|+|typ|+" = "+|val|+";"
    pretty (Reassignment var val) = var|+" = "+|val|+";"
    pretty Continue = "continue;"
    pretty Break = "break;"
    pretty (Return val) = "return "+|val|+";"
    pretty (ValStmt val) = val|+";"
    pretty NullStmt = ";"
    pretty (Compound ss) = "{\n"+|indentCatLns ss|+"}"
    detailed (IfElse val tb NullStmt) =
        "If: "*|val|*|indentLnsD tb|*"Else:"
    detailed (IfElse val tb fb) =
        "If: "*|val|*|indentLnsD tb|+
        "Else:\n"+|indentLnsD fb
    detailed (Loop init' cond iter body) =
        "Loop:\n    Initial: "*|init'|*
        "\n    Condition: "*|cond|*
        "\n    Iteration: "*|iter|*
        "\n    Body:\n"
            +|indentLnsD body
    detailed (Match val cases) =
        "Match: "*|val|*"\n"+|
            (indentCatLns $ fmap ("Case: "*|) cases)
    detailed (NewVar mut name typ val) =
        "New Variable:\n    Mutab.: "*|mut|*
        "\n    Type: "*|typ|*
        "\n    Name: "+|name|+
        "\n    Value: "*|val
    detailed (Reassignment var val) =
        "Reassignment:\n    Variable: "*|var|*
        "\n    Value: "*|val
    detailed Continue = "Continue"
    detailed Break = "Break"
    detailed (Return val) = "Return: "*|val
    detailed (ValStmt val) = "Expr: "*|val
    detailed NullStmt = "Null Statement"
    detailed (Compound ss) = indentCatLns ss

instance Pretty MatchCase where
    pretty (Case p b) = p|+" "+|b

