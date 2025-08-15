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
    UninitializedVariableDeclaration,
    MultipleVariableDeclaration,
    MultipleUninitializedVariableDeclaration,
    ReturnStatement,
    FunctionDeclaration,
    AssignmentDeclaration,

    IfStatement,
    ElseStatement,
    ForStatement,
    WhileStatement,

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
    Stmt[] args;
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

class UninitializedVariableDeclaration : Stmt
{
    Identifier id;
    bool mut;

    this(Identifier id, FTypeInfo type, bool mut, Loc loc)
    {
        this.kind = NodeType.UninitializedVariableDeclaration;
        this.id = id;
        this.type = type;
        this.mut = mut;
        this.loc = loc;
        this.value = null;
    }
}

struct VariablePair
{
    Identifier id;
    Stmt value;
    FTypeInfo type;
    bool mut;

    this(Identifier id, Stmt value, FTypeInfo type, bool mut)
    {
        this.id = id;
        this.value = value;
        this.type = type;
        this.mut = mut;
    }
}

class MultipleVariableDeclaration : Stmt
{
    VariablePair[] declarations;
    FTypeInfo commonType;

    this(VariablePair[] declarations, FTypeInfo commonType, Loc loc)
    {
        this.kind = NodeType.MultipleVariableDeclaration;
        this.declarations = declarations;
        this.commonType = commonType;
        this.loc = loc;
        this.type = createTypeInfo(TypesNative.VOID);
        this.value = null;
    }

    Identifier[] getIdentifiers()
    {
        Identifier[] ids;
        foreach (decl; declarations)
        {
            ids ~= decl.id;
        }
        return ids;
    }

    Stmt[] getValues()
    {
        Stmt[] values;
        foreach (decl; declarations)
        {
            values ~= decl.value;
        }
        return values;
    }

    FTypeInfo[] getTypes()
    {
        FTypeInfo[] types;
        foreach (decl; declarations)
        {
            types ~= decl.type;
        }
        return types;
    }
}

class MultipleUninitializedVariableDeclaration : Stmt
{
    Identifier[] ids;
    FTypeInfo commonType;
    bool mut;

    this(Identifier[] ids, FTypeInfo commonType, bool mut, Loc loc)
    {
        this.kind = NodeType.MultipleUninitializedVariableDeclaration;
        this.ids = ids;
        this.commonType = commonType;
        this.mut = mut;
        this.loc = loc;
        this.type = commonType;
        this.value = null;
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

    bool isInitialized()
    {
        return this.value.hasValue();
    }
}

class VariableDeclarationFactory
{
    static VariableDeclaration createInitialized(Identifier id, Stmt value, FTypeInfo type, bool mut, Loc loc)
    {
        return new VariableDeclaration(id, value, type, mut, loc);
    }

    static UninitializedVariableDeclaration createUninitialized(Identifier id, FTypeInfo type, bool mut, Loc loc)
    {
        return new UninitializedVariableDeclaration(id, type, mut, loc);
    }

    static MultipleVariableDeclaration createMultipleInitialized(
        Identifier[] ids,
        Stmt[] values,
        FTypeInfo commonType,
        bool mut,
        Loc loc
    )
    {
        if (ids.length != values.length)
        {
            throw new Exception(
                "Número de identificadores deve corresponder ao número de valores");
        }

        VariablePair[] pairs;
        foreach (i; 0 .. ids.length)
        {
            FTypeInfo finalType = commonType.baseType != TypesNative.NULL ? commonType
                : values[i].type;
            pairs ~= VariablePair(ids[i], values[i], finalType, mut);
        }

        return new MultipleVariableDeclaration(pairs, commonType, loc);
    }

    static MultipleUninitializedVariableDeclaration createMultipleUninitialized(
        Identifier[] ids,
        FTypeInfo commonType,
        bool mut,
        Loc loc
    )
    {
        if (commonType.baseType == TypesNative.NULL)
        {
            throw new Exception(
                "Tipo deve ser especificado para declarações múltiplas não inicializadas");
        }

        return new MultipleUninitializedVariableDeclaration(ids, commonType, mut, loc);
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
        this.args = args;
        this.type = createTypeInfo(TypesNative.NULL);
    }
}

class IfStatement : Stmt
{
    Stmt condition;
    Stmt[] primary;
    NullStmt secondary;

    this(Stmt condition, Stmt[] primary, FTypeInfo type, Variant value, Loc loc, NullStmt secondary = null)
    {
        this.kind = NodeType.IfStatement;
        this.condition = condition;
        this.primary = primary;
        this.secondary = secondary;
        this.value = value;
        this.loc = loc;
        this.type = type;
    }
}

class ElifStatement : IfStatement
{
    this(Stmt condition, Stmt[] primary, FTypeInfo type, Variant value, Loc loc, NullStmt secondary = null)
    {
        super(condition, primary, type, value, loc);
    }
}

class ElseStatement : Stmt
{
    Stmt[] primary;

    this(Stmt[] primary, FTypeInfo type, Variant value, Loc loc)
    {
        this.kind = NodeType.ElseStatement;
        this.primary = primary;
        this.value = value;
        this.loc = loc;
        this.type = type;
    }
}

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
    Stmt[] body;
    SymbolInfo[string] context;

    this(Identifier id, FunctionArgs args, Stmt[] body, FTypeInfo type, Loc loc)
    {
        this.id = id;
        this.args = args;
        this.kind = NodeType.FunctionDeclaration;
        this.body = body;
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

class ForStatement : Stmt
{
    // varDecl, cond, expr, body
    // for var i = 10; cond; expr {}
    // for i = 10; cond; expr {}
    Stmt _init;
    Stmt cond;
    Stmt expr;
    Stmt[] body;

    this(Stmt _init, Stmt cond, Stmt expr, Stmt[] body, Loc loc)
    {
        this.kind = NodeType.ForStatement;
        this.value = null;
        this._init = _init;
        this.cond = cond;
        this.expr = expr;
        this.body = body;
        this.loc = loc;
        this.type = createTypeInfo(TypesNative.NULL);
    }
}

class WhileStatement : Stmt
{
    // while cond body
    Stmt cond;
    Stmt[] body;

    this(Stmt cond, Stmt[] body, Loc loc)
    {
        this.kind = NodeType.WhileStatement;
        this.value = null;
        this.cond = cond;
        this.body = body;
        this.loc = loc;
        this.type = createTypeInfo(TypesNative.NULL);
    }
}

class AssignmentDeclaration : Stmt
{
    Identifier id;

    this(Identifier id, Stmt value, FTypeInfo type, Loc loc)
    {
        this.kind = NodeType.AssignmentDeclaration;
        this.id = id;
        this.value = value;
        this.type = type;
        this.loc = loc;
    }
}
