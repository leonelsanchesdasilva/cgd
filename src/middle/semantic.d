module middle.semantic;

import std.string : toLower;
import std.stdio;
import std.conv;
import std.format;
import std.typecons : Nullable;
import middle.semantic_symbol_info;
import middle.function_builder;
import middle.std_lib_module_builder;
import middle.type_checker;
import frontend.parser.ast;
import frontend.values;
import frontend.parser.ftype_info;

class Semantic
{
public:
    SymbolInfo[string][] scopeStack;

    StdLibFunction[string] availableStdFunctions; // by compiler
    Function[string] availableFunctions; // by user
    bool[string] importedModules;
    StdLibModule[string] stdLibs;
    bool[string] identifiersUsed;

    this()
    {
        this.pushScope();
        this.typeChecker = getTypeChecker(this);
    }

    Program semantic(Program program)
    {
        Stmt[] analyzedNodes;

        foreach (Stmt node; program.body)
        {
            try
            {
                analyzedNodes ~= this.analyzeNode(node);
            }
            catch (Exception e)
            {
                writeln("Erro no semantic: ", e.message);
                writeln("Erro no semantic: ", e.file);
                writeln("Erro no semantic: ", e.line);
                break;
            }
        }

        program.body = analyzedNodes;
        return program;
    }

    static Semantic getInstance()
    {
        if (!Semantic.instance)
        {
            Semantic.instance = new Semantic();
        }
        return Semantic.instance.get;
    }

    void resetInstance()
    {
        Semantic.instance = null;
    }

private:
    static Nullable!Semantic instance = null;
    Stmt[] nodes;
    TypeChecker typeChecker;

    Stmt analyzeNode(Stmt node)
    {
        // writeln("DEBUG: node=", typeid(node), " kind=", node.kind);

        Stmt analyzedNode;
        switch (node.kind)
        {
        case NodeType.FunctionDeclaration:
            analyzedNode = this.analyzeFnDeclaration(cast(FunctionDeclaration) node);
            break;
        case NodeType.VariableDeclaration:
            analyzedNode = this.analyzeVarDeclaration(cast(VariableDeclaration) node);
            break;
        case NodeType.BinaryExpr:
            analyzedNode = this.analyzeBinaryExpr(cast(BinaryExpr) node);
            break;
        case NodeType.Identifier:
            analyzedNode = this.analyzeIdentifier(cast(Identifier) node);
            break;
        case NodeType.ReturnStatement:
            analyzedNode = this.analyzeReturnStatement(cast(ReturnStatement) node);
            break;
        case NodeType.CallExpr:
            break;

        case NodeType.StringLiteral:
        case NodeType.IntLiteral:
        case NodeType.FloatLiteral:
        case NodeType.NullLiteral:
        case NodeType.BoolLiteral:
            analyzedNode = node;
            string baseType = to!string(analyzedNode.type.baseType).toLower();
            analyzedNode.type.baseType = cast(TypesNative) this.typeChecker.mapToDType(
                baseType);
            break;

        default:
            throw new Error(format("Nó desconhecido '%s'.", to!string(node.kind)));
        }
        return analyzedNode;
    }

    ReturnStatement analyzeReturnStatement(ReturnStatement node)
    {
        node.expr = this.analyzeNode(node.expr);
        node.type = node.expr.type;
        return node;
    }

    FunctionDeclaration analyzeFnDeclaration(FunctionDeclaration node)
    {
        string id = node.id.value.get!string;

        if ((id in this.availableFunctions) || id in this.availableStdFunctions)
        {
            throw new Error(format(`A função '%s' já está definida.`, id));
        }

        this.pushScope(); // Escopo para a função

        FunctionArgs args;

        foreach (FunctionArg arg; node.args)
        {
            string _id = arg.id.value.get!string;
            if (_id in this.currentScope())
            {
                throw new Error(format(
                        `Parâmetro '%s' já foi definido.`, _id
                ));
            }

            string baseType = to!string(arg.type.baseType).toLower();
            arg.type.baseType = cast(TypesNative) this.typeChecker.mapToDType(
                baseType);
            this.addSymbol(_id, SymbolInfo(_id, arg.type, true, false, arg.id.loc));
            args ~= arg;
        }

        FTypeInfo returnType = node.type;
        string t2 = to!string(returnType.baseType).toLower();

        FunctionParam[] params;
        foreach (FunctionArg arg; args)
        {
            params ~= FunctionParam(arg.id.value.get!string, arg.type, to!string(arg.type.baseType));
        }

        Function func = Function(id, returnType, params, false, to!string(returnType.baseType));
        this.availableFunctions[id] = func;

        Stmt[] analyzedBlock;
        bool hasReturn = false;

        foreach (Stmt stmt; node.block)
        {
            Stmt analyzedStmt = this.analyzeNode(stmt);
            analyzedBlock ~= analyzedStmt;

            if (stmt.kind == NodeType.ReturnStatement)
            {
                hasReturn = true;
                ReturnStatement returnStmt = cast(ReturnStatement) analyzedStmt;
                writeln(returnStmt);
                if (returnStmt.value.hasValue())
                {
                    string t1 = to!string(returnStmt.type.baseType).toLower();
                    if (!this.typeChecker.areTypesCompatible(t1, t2) && t2 != "void")
                    {
                        throw new Error(format(
                                "A função '%s' está retornando '%s' ao invés de '%s' como esperado.",
                                id, t1, t2
                        ));
                    }
                }
            }
        }

        if (t2 != "void" && !hasReturn)
        {
            throw new Error(format(
                    "A função esperava um retorno '%s', mas não foi encontrado qualquer tipo de retorno nela.", t2),
            );
        }

        node.args = args;
        node.block = analyzedBlock;
        node.type = returnType;
        node.context = this.currentScope();
        this.popScope();

        return node;
    }

    Stmt analyzeIdentifier(Identifier node)
    {
        string id = node.value.get!string;
        SymbolInfo* symbol = this.lookupSymbol(id);

        if (!symbol)
        {
            throw new Error(
                format(
                    `O identificador '%s' não existe no escopo`, id));
        }

        if (!(id in this.identifiersUsed))
        {
            this.identifiersUsed[id] = true;
        }

        return node;
    }

    Stmt analyzeBinaryExpr(BinaryExpr node)
    {
        Stmt left = this.analyzeNode(node.left);
        Stmt right = this.analyzeNode(node.right);
        FTypeInfo resultType = this.typeChecker.checkBinaryExprTypes(left, right, node.op);

        node.left = left;
        node.right = right;
        node.type = resultType;

        return node;
    }

    Stmt analyzeVarDeclaration(VariableDeclaration node)
    {
        string id = node.id.value.get!string;

        if (id in this.currentScope())
        {
            throw new Error(
                format(
                    `A variavel '%s' já está definida no escopo em %d:%d`, id, cast(int) node.id.loc.line, cast(
                    int) node.id.loc.start));
        }

        if (!node.value.hasValue)
        {
            throw new Error(format("Erro: o valor do nó '%s' é nulo.", to!string(node.kind)));
        }

        Stmt analyzedValue = this.analyzeNode(node.value.get!Stmt);
        node.value = analyzedValue;

        string baseType = to!string(node.type.baseType).toLower();
        node.type.baseType = cast(TypesNative) this.typeChecker.mapToDType(
            baseType);
        this.addSymbol(id, SymbolInfo(id, node.type, true, true, node.loc));

        return node;
    }

    void pushScope()
    {
        scopeStack ~= (SymbolInfo[string]).init;
    }

    void popScope()
    {
        if (scopeStack.length > 0)
        {
            scopeStack.length -= 1;
        }
    }

    SymbolInfo[string] currentScope()
    {
        if (scopeStack.length > 0)
        {
            return scopeStack[$ - 1];
        }
        else
        {
            return (SymbolInfo[string]).init;
        }
    }

    void addSymbol(string name, SymbolInfo info)
    {
        if (scopeStack.length > 0)
        {
            scopeStack[$ - 1][name] = info;
        }
    }

    SymbolInfo* lookupSymbol(string name)
    {
        for (int i = cast(int) scopeStack.length - 1; i >= 0; i--)
        {
            if (name in scopeStack[i])
            {
                return &scopeStack[i][name];
            }
        }
        return null;
    }
}
