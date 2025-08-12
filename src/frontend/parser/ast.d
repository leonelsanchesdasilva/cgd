module frontend.parser.ast;

import frontend.values;
import frontend.lexer.token;
import middle.semantic_symbol_info;
import frontend.parser.ftype_info;
import frontend.parser.ast_utils;
import std.variant : Variant, Algebraic;
import std.typecons;

alias NullStmt = Nullable!Stmt;

enum NodeType
{
    Program,
    Identifier,

    VariableDeclaration,
    ReturnStatement,
    FunctionDeclaration,

    IntLiteral,
    FloatLiteral,
    StringLiteral,
    NullLiteral,
    BoolLiteral,

    DereferenceExpr,
    AddressOfExpr,
    UnaryExpr,
    CallExpr,
    CastExpr,
    BinaryExpr,
}

class Stmt
{
    NodeType kind;
    FTypeInfo type;
    Variant value;
    Loc loc;
}

class Program : Stmt
{
    Stmt[] body;

    this(Stmt[] body)
    {
        this.kind = NodeType.Program;
        this.body = body;
    }
}

class BinaryExpr : Stmt
{
    Stmt left, right;
    string op;

    this(Stmt left, Stmt right, string op, Loc loc)
    {
        this.kind = NodeType.BinaryExpr;
        this.left = left;
        this.right = right;
        this.op = op;
        this.loc = loc;
    }
}

class IntLiteral : Stmt
{
    this(int value, Loc loc)
    {
        this.kind = NodeType.IntLiteral;
        this.type = createTypeInfo(TypesNative.INT);
        this.value = value;
        this.loc = loc;
    }
}

class NullLiteral : Stmt
{
    this(Loc loc)
    {
        this.kind = NodeType.NullLiteral;
        this.type = createTypeInfo(TypesNative.NULL);
        this.value = null;
        this.loc = loc;
    }
}

class BoolLiteral : Stmt
{
    this(bool value, Loc loc)
    {
        this.kind = NodeType.BoolLiteral;
        this.type = createTypeInfo(TypesNative.BOOL);
        this.value = value;
        this.loc = loc;
    }
}

class FloatLiteral : Stmt
{
    this(float value, Loc loc)
    {
        this.kind = NodeType.FloatLiteral;
        this.type = createTypeInfo(TypesNative.FLOAT);
        this.value = value;
        this.loc = loc;
    }
}

class StringLiteral : Stmt
{
    this(string value, Loc loc)
    {
        this.kind = NodeType.StringLiteral;
        this.type = createTypeInfo(TypesNative.STRING);
        this.value = value;
        this.loc = loc;
    }
}

class CastExpr : Stmt
{
    Stmt expr;

    this(FTypeInfo type, Stmt expr, Loc loc)
    {
        this.kind = NodeType.CastExpr;
        this.type = type;
        this.expr = expr;
        this.value = null;
        this.loc = loc;
    }
}

class Identifier : Stmt
{
    this(string id, Loc loc)
    {
        this.kind = NodeType.Identifier;
        this.type = createTypeInfo(TypesNative.ID);
        this.value = id;
        this.loc = loc;
    }
}

class VariableDeclaration : Stmt
{
    Identifier id;
    bool mut;

    this(Identifier id, Stmt value, FTypeInfo type, bool mut, Loc loc)
    {
        this.kind = NodeType.VariableDeclaration;
        this.id = id;
        this.value = value;
        this.type = type;
        this.mut = mut;
        this.loc = loc;
    }
}

class CallExpr : Stmt
{
    Identifier calle;
    Stmt[] args;

    this(Identifier calle, Stmt[] args, Loc loc)
    {
        this.kind = NodeType.CallExpr;
        this.calle = calle;
        this.loc = loc;
        this.type = createTypeInfo(TypesNative.NULL);
    }
}

// class IfStatement : Stmt
// {
//     Stmt condition, primary;
//     NullStmt secondary;

//     this(Stmt condition, Stmt primary, FTypeInfo type, Variant value, Loc loc, NullStmt secondary = null)
//     {
//         this.kind = NodeType.IfStatement;
//         this.condition = condition;
//         this.primary = primary;
//         this.secondary = secondary;
//         this.value = value;
//         this.loc = loc;
//         this.type = type;
//     }
// }

// class ElifStatement : IfStatement
// {
//     this(Stmt condition, Stmt primary, FTypeInfo type, Variant value, Loc loc, NullStmt secondary = null)
//     {
//         super(condition, primary, type, value, loc);
//     }
// }

// class ElseStatement : Stmt
// {
//     Stmt primary;

//     this(Stmt primary, FTypeInfo type, Variant value, Loc loc)
//     {
//         this.kind = NodeType.ElseStatement;
//         this.primary = primary;
//         this.value = value;
//         this.loc = loc;
//         this.type = type;
//     }
// }

class UnaryExpr : Stmt
{
    string op; // "-", "!", "&", "*"
    Stmt operand;

    this(string op, Stmt operand, Loc loc)
    {
        this.kind = NodeType.UnaryExpr;
        this.op = op;
        this.operand = operand;
        this.value = null;
        this.type = createTypeInfo(TypesNative.NULL);
        this.loc = loc;
    }
}

class DereferenceExpr : Stmt
{
    Stmt operand;

    this(Stmt operand, Loc loc)
    {
        this.kind = NodeType.DereferenceExpr;
        this.operand = operand;
        this.value = null;
        this.type = createTypeInfo(TypesNative.NULL);
        this.loc = loc;
    }
}

class AddressOfExpr : Stmt
{
    Stmt operand;

    this(Stmt operand, Loc loc)
    {
        this.kind = NodeType.AddressOfExpr;
        this.operand = operand;
        this.value = null;
        this.type = createTypeInfo(TypesNative.NULL);
        this.loc = loc;
    }
}

// FunctionDeclaration

class FunctionArg
{
    Identifier id;
    FTypeInfo type;
    Nullable!Stmt def; // Default, like: function fernando(x: int = 10) {}

    this(Identifier id, FTypeInfo type, Nullable!Stmt def = null)
    {
        this.id = id;
        this.type = type;
        this.def = def;
    }
}

alias FunctionArgs = FunctionArg[];

class FunctionDeclaration : Stmt
{
    Identifier id;
    FunctionArgs args;
    Stmt[] block;
    SymbolInfo[string] context;

    this(Identifier id, FunctionArgs args, Stmt[] block, FTypeInfo type, Loc loc)
    {
        this.id = id;
        this.args = args;
        this.kind = NodeType.FunctionDeclaration;
        this.block = block;
        this.loc = loc;
        this.type = type;
        this.value = null;
    }
}

class ReturnStatement : Stmt
{

    Stmt expr;

    this(Stmt expr, Loc loc)
    {
        this.kind = NodeType.ReturnStatement;
        this.expr = expr;
        this.value = null;
        this.loc = loc;
        this.type = createTypeInfo(TypesNative.NULL);
    }
}
