module backend.builder;

import std.stdio;
import std.exception : enforce;
import std.format;
import std.conv;
import std.variant;
import frontend.parser.ftype_info;
import frontend.parser.ast;
import frontend.values;
import middle.std_lib_module_builder : StdLibFunction;
import backend.codegen.core;
import middle.semantic;

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
    Function currentFunc;

    Type[TypesNative] typeCache;
    Symbol[string][] scopeStack;
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

    Symbol* lookupSymbol(string name)
    {
        foreach_reverse (ref scope_; scopeStack)
        {
            if (auto symbol = name in scope_)
            {
                // writeln("DEBUG: Símbolo encontrado no escopo local: ", name, " tipo: ", symbol
                //         .type.baseType);
                return symbol;
            }
        }

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
        case NodeType.IfStatement:
            return GenerationResult(genIfStatement(cast(IfStatement) node));

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
        pushScope();

        foreach (stmt; node.body)
        {
            if (stmt.kind == NodeType.FunctionDeclaration)
            {
                auto funcDecl = cast(FunctionDeclaration) stmt;
                auto funcName = funcDecl.id.value.get!string;
                addSymbol(funcName, funcDecl.type, true);
            }
        }

        foreach (stmt; node.body)
        {
            auto result = generate(stmt);

            // writeln("DEBUG: Processando statement do tipo: ", stmt.kind);
            // writeln("DEBUG: Result type: ", result.type);

            // if (stmt.kind == NodeType.VariableDeclaration)
            // {
            if (result.type == typeid(Statement))
            {
                auto _stmt = result.get!Statement;
                if (mainFunc !is null && _stmt !is null)
                {
                    mainFunc.addStatement(_stmt);
                }
            }

            if (result.type == typeid(Expression))
            {
                auto expr = result.get!Expression;
                if (expr !is null && mainFunc !is null)
                {
                    auto exprStmt = new ExpressionStatement(expr);
                    mainFunc.addStatement(exprStmt);
                }
            }
            // }
        }

        popScope();
        return null;
    }

    Statement genIfStatement(IfStatement node)
    {
        writeln(node.secondary);
        Statement[] stmts = [];
        foreach (Stmt stmt; node.primary)
        {
            auto result = this.generate(stmt);
            if (result.type == typeid(Statement))
            {
                auto statement = result.get!Statement;
                if (statement !is null)
                {
                    stmts ~= statement;
                }
            }
            else if (result.type == typeid(Expression))
            {
                auto expr = result.get!Expression;
                if (expr !is null)
                {
                    stmts ~= new ExpressionStatement(expr);
                }
            }
        }

        auto condition = this.generate(node.condition).get!Expression;
        auto then = new BlockStatement(stmts);
        auto _if = new IfStatementCore(condition, then);
        return _if;
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
        return ret;
    }

    Statement genFunctionDeclaration(FunctionDeclaration node)
    {
        auto funcName = node.id.value.get!string;

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

        // Salva a função atual e define a nova como atual
        auto previousFunc = currentFunc;
        scope (exit)
            currentFunc = previousFunc;

        currentFunc = func;

        // Cria novo escopo para a função
        pushScope();
        scope (exit)
            popScope(); // Remove escopo da função ao sair

        // Adiciona parâmetros ao escopo da função
        foreach (arg; node.args)
        {
            addSymbol(arg.id.value.get!string, arg.type, false);
        }

        // Processa o corpo da função
        foreach (stmt; node.block)
        {
            auto result = generate(stmt);
            if (result.type == typeid(Statement))
            {
                auto statement = result.get!Statement;
                if (statement !is null)
                {
                    func.addStatement(statement);
                }
            }
        }

        // Adiciona a função ao módulo
        codegen.currentModule.addFunction(func);

        // Não retorna nada porque declarações de função não são statements
        return null;
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
    Semantic semantic;
    CodeGenerator codegen;

    this(Program program, Semantic semantic)
    {
        this.semantic = semantic;
        this.program = program;
        this.codegen = new CodeGenerator("main");
        this.mainFunc = new Function(getType(FTypeInfo(TypesNative.VOID)), "main");

        // importando as funções std para nosso contexto atual
        foreach (string name, StdLibFunction func; semantic.availableStdFunctions)
        {
            this.globalScope[name] = Symbol(func.returnType, name, true);
        }
    }

    void build()
    {
        codegen.currentModule.addFunction(mainFunc);
        this.genProgram(this.program);
    }
}
