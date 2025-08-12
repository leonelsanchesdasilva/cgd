module backend.builder;

import std.stdio;
import std.exception : enforce;
import std.format;
import std.conv;
import std.variant;
import frontend.parser.ftype_info;
import frontend.parser.ast;
import frontend.values;
import backend.codegen.core;

alias GenerationResult = Variant;

// Estrutura para armazenar informações de símbolos
struct Symbol
{
    FTypeInfo type;
    string name;
    bool isFunction;

    this(FTypeInfo type, string name, bool isFunction = false)
    {
        this.type = type;
        this.name = name;
        this.isFunction = isFunction;
    }
}

class Builder
{
private:
    Program program;
    Function mainFunc;
    CodeGenerator codegen;

    Type[TypesNative] typeCache;

    // Sistema de escopo - stack de tabelas de símbolos
    Symbol[string][] scopeStack;

    // Escopo global para funções
    Symbol[string] globalScope;

    Type getType(FTypeInfo t)
    {
        if (auto cached = t.baseType in typeCache)
            return *cached;

        Type result;
        switch (t.baseType)
        {
        case TypesNative.STRING:
            result = this.codegen.makeStringType();
            break;
        case TypesNative.INT:
            result = this.codegen.makeIntType();
            break;
        case TypesNative.VOID:
        case TypesNative.NULL:
            result = this.codegen.makeVoidType();
            break;
        case TypesNative.BOOL:
            result = this.codegen.makeBoolType();
            break;
        case TypesNative.FLOAT:
            result = this.codegen.makeFloatType();
            break;
        default:
            throw new Exception(format("Tipo desconhecido '%s'.", t.baseType));
        }

        typeCache[t.baseType] = result;
        return result;
    }

    // Métodos para gerenciamento de escopo
    void pushScope()
    {
        scopeStack ~= (Symbol[string]).init;
        // writeln("DEBUG: Novo escopo criado. Stack size: ", scopeStack.length);
    }

    void popScope()
    {
        enforce(scopeStack.length > 0, "Tentativa de remover escopo inexistente");
        scopeStack = scopeStack[0 .. $ - 1];
        // writeln("DEBUG: Escopo removido. Stack size: ", scopeStack.length);
    }

    // Adiciona símbolo no escopo atual
    void addSymbol(string name, FTypeInfo type, bool isFunction = false)
    {
        if (isFunction)
        {
            globalScope[name] = Symbol(type, name, true);
            // writeln("DEBUG: Função adicionada ao escopo global: ", name, " tipo: ", type.baseType);
        }
        else
        {
            enforce(scopeStack.length > 0, "Nenhum escopo disponível para adicionar símbolo");
            scopeStack[$ - 1][name] = Symbol(type, name, false);
            // writeln("DEBUG: Variável adicionada ao escopo atual: ", name, " tipo: ", type.baseType);
        }
    }

    // Busca símbolo nos escopos (do mais interno para o mais externo)
    Symbol* lookupSymbol(string name)
    {
        // Primeiro procura nos escopos locais (de dentro para fora)
        foreach_reverse (ref scope_; scopeStack)
        {
            if (auto symbol = name in scope_)
            {
                // writeln("DEBUG: Símbolo encontrado no escopo local: ", name, " tipo: ", symbol
                //         .type.baseType);
                return symbol;
            }
        }

        // Depois procura no escopo global (funções)
        if (auto symbol = name in globalScope)
        {
            // writeln("DEBUG: Símbolo encontrado no escopo global: ", name, " tipo: ", symbol
            //         .type.baseType);
            return symbol;
        }

        writeln("DEBUG: Símbolo não encontrado: ", name);
        return null;
    }

    GenerationResult generate(Stmt node)
    {
        enforce(node !is null, "generate() recebeu null — verifique initializers no AST.");

        switch (node.kind)
        {
        case NodeType.Program:
            return GenerationResult(genProgram(cast(Program) node));

        case NodeType.VariableDeclaration:
            return GenerationResult(genVariableDeclaration(cast(VariableDeclaration) node));
        case NodeType.FunctionDeclaration:
            return GenerationResult(genFunctionDeclaration(cast(FunctionDeclaration) node));
        case NodeType.ReturnStatement:
            return GenerationResult(genReturnStatement(cast(ReturnStatement) node));

        case NodeType.StringLiteral:
            return GenerationResult(genStringLiteral(cast(StringLiteral) node));
        case NodeType.IntLiteral:
            return GenerationResult(genIntLiteral(cast(IntLiteral) node));
        case NodeType.FloatLiteral:
            return GenerationResult(genFloatLiteral(cast(FloatLiteral) node));
        case NodeType.BoolLiteral:
            return GenerationResult(genBoolLiteral(cast(BoolLiteral) node));
        case NodeType.NullLiteral:
            return GenerationResult(genNullLiteral(cast(NullLiteral) node));

        case NodeType.Identifier:
            return GenerationResult(genIdentifier(cast(Identifier) node));

        case NodeType.BinaryExpr:
            return GenerationResult(genBinaryExpr(cast(BinaryExpr) node));
        case NodeType.UnaryExpr:
            return GenerationResult(genUnaryExpr(cast(UnaryExpr) node));
        case NodeType.CallExpr:
            return GenerationResult(genCallExpr(cast(CallExpr) node));
        case NodeType.CastExpr:
            return GenerationResult(genCastExpr(cast(CastExpr) node));
        case NodeType.DereferenceExpr:
            return GenerationResult(genDereferenceExpr(cast(DereferenceExpr) node));
        case NodeType.AddressOfExpr:
            return GenerationResult(genAddressOfExpr(cast(AddressOfExpr) node));

        default:
            throw new Exception(format("NodeType desconhecido '%s'.", node.kind));
        }
    }

    Statement asStatement(GenerationResult result)
    {
        enforce(result.type == typeid(Statement), "Resultado não é um Statement");
        return result.get!Statement;
    }

    Expression asExpression(GenerationResult result)
    {
        enforce(result.type == typeid(Expression), "Resultado não é uma Expression");
        return result.get!Expression;
    }

    Statement genProgram(Program node)
    {
        // Cria escopo global para o programa
        pushScope();
        scope (exit)
            popScope();

        Statement[] statements;
        foreach (stmt; node.body)
        {
            auto result = generate(stmt);
            if (result.type == typeid(Statement))
            {
                statements ~= result.get!Statement;
            }
        }
        return statements.length > 0 ? statements[0] : null;
    }

    Expression genStringLiteral(StringLiteral node)
    {
        return new LiteralExpression(getType(node.type), node.value.get!string);
    }

    Expression genIntLiteral(IntLiteral node)
    {
        auto value = node.value.get!int;
        return new LiteralExpression(getType(node.type), to!string(value));
    }

    Expression genFloatLiteral(FloatLiteral node)
    {
        auto value = node.value.get!float;
        return new LiteralExpression(getType(node.type), to!string(value));
    }

    Expression genBoolLiteral(BoolLiteral node)
    {
        auto value = node.value.get!bool;
        return new LiteralExpression(getType(node.type), value ? "true" : "false");
    }

    Expression genNullLiteral(NullLiteral node)
    {
        return new LiteralExpression(getType(node.type), "null");
    }

    Expression genIdentifier(Identifier node)
    {
        auto name = node.value.get!string;

        auto symbol = lookupSymbol(name);
        if (symbol is null)
        {
            throw new Exception(format("Variável/função '%s' não foi declarada", name));
        }

        auto type = getType((*symbol).type);
        return new VariableExpression(type, name);
    }

    Expression genBinaryExpr(BinaryExpr node)
    {
        auto leftExpr = asExpression(generate(node.left));
        auto rightExpr = asExpression(generate(node.right));

        return codegen.makeBinary(
            getType(node.type),
            leftExpr,
            node.op,
            rightExpr
        );
    }

    Expression genUnaryExpr(UnaryExpr node)
    {
        auto operandExpr = asExpression(generate(node.operand));

        return new UnaryExpressionCore(
            getType(node.type),
            node.op,
            operandExpr
        );
    }

    Expression genCallExpr(CallExpr node)
    {
        auto funcName = node.calle.value.get!string;

        // Verifica se a função existe
        auto symbol = lookupSymbol(funcName);
        if (symbol is null)
        {
            throw new Exception(format("Função '%s' não foi declarada", funcName));
        }

        if (!symbol.isFunction)
        {
            throw new Exception(format("'%s' não é uma função", funcName));
        }

        Expression[] args;
        args.reserve(node.args.length);
        foreach (arg; node.args)
        {
            args ~= asExpression(generate(arg));
        }

        auto returnType = getType(node.type);
        return codegen.makeCall(returnType, funcName, args);
    }

    Expression genCastExpr(CastExpr node)
    {
        auto expr = asExpression(generate(node.expr));
        return new CastExpression(getType(node.type), expr);
    }

    Expression genDereferenceExpr(DereferenceExpr node)
    {
        auto operandExpr = asExpression(generate(node.operand));
        return new DereferenceExpressionCore(
            getType(node.type),
            operandExpr
        );
    }

    Expression genAddressOfExpr(AddressOfExpr node)
    {
        auto operandExpr = asExpression(generate(node.operand));
        return new AddressOfExpressionCore(
            getType(node.type),
            operandExpr
        );
    }

    Statement genReturnStatement(ReturnStatement node)
    {
        Expression expr = null;
        if (node.expr !is null)
        {
            expr = asExpression(generate(node.expr));
        }

        auto ret = new ReturnStatementCore(expr);
        if (mainFunc !is null)
        {
            mainFunc.addStatement(ret);
        }
        return ret;
    }

    Statement genFunctionDeclaration(FunctionDeclaration node)
    {
        auto funcName = node.id.value.get!string;

        // Adiciona função ao escopo global ANTES de processar o corpo
        addSymbol(funcName, node.type, true);

        Parameter[] params;
        params.reserve(node.args.length);
        foreach (arg; node.args)
        {
            params ~= Parameter(getType(arg.type), arg.id.value.get!string);
        }

        auto func = new Function(
            getType(node.type),
            funcName,
            params
        );

        auto previousFunc = mainFunc;
        scope (exit)
            mainFunc = previousFunc;

        mainFunc = func;

        // Cria novo escopo para a função
        pushScope();

        // Adiciona parâmetros ao escopo da função
        foreach (arg; node.args)
        {
            addSymbol(arg.id.value.get!string, arg.type, false);
        }

        Statement[] statements;
        statements.reserve(node.block.length);
        foreach (stmt; node.block)
        {
            auto result = generate(stmt);
            if (result.type == typeid(Statement))
            {
                statements ~= result.get!Statement;
            }
        }

        codegen.currentModule.addFunction(func);

        return statements.length > 0 ? statements[0] : null;
    }

    Statement genVariableDeclaration(VariableDeclaration node)
    {
        auto varName = node.id.value.get!string;

        // Adiciona variável ao escopo atual
        addSymbol(varName, node.type, false);

        Expression expr = createInitializerExpression(node);

        auto var = new VariableDeclarationCore(
            getType(node.type),
            varName,
            expr
        );

        if (mainFunc !is null)
        {
            mainFunc.addStatement(var);
        }
        return var;
    }

    Expression createInitializerExpression(VariableDeclaration node)
    {
        if (node.value.type == typeid(Stmt))
        {
            auto stmt = node.value.get!Stmt;
            if (stmt !is null)
            {
                return asExpression(generate(stmt));
            }
        }

        return createDefaultValue(node.type);
    }

    Expression createDefaultValue(FTypeInfo typeInfo)
    {
        auto type = getType(typeInfo);

        switch (typeInfo.baseType)
        {
        case TypesNative.INT:
            return new LiteralExpression(type, "0");
        case TypesNative.BOOL:
            return new LiteralExpression(type, "false");
        case TypesNative.FLOAT:
            return new LiteralExpression(type, "0.0");
        case TypesNative.STRING:
            return new LiteralExpression(type, `""`);
        default:
            return new LiteralExpression(type, "null");
        }
    }

public:
    this(Program program)
    {
        this.program = program;
        this.codegen = new CodeGenerator("main");
        this.mainFunc = new Function(getType(FTypeInfo(TypesNative.VOID)), "main");
    }

    void build()
    {
        foreach (node; program.body)
        {
            try
            {
                generate(node);
            }
            catch (Exception e)
            {
                writeln("Erro no codegen: ", e.message);
                writeln("Arquivo: ", e.file, ":", e.line);
                return;
            }
        }

        codegen.currentModule.addFunction(mainFunc);
        write(codegen.generate());
    }
}
