module backend.builder;

import std.stdio;
import std.exception : enforce;
import std.format;
import std.conv;
import std.variant;
import std.algorithm;
import std.array;
import frontend.parser.ftype_info;
import frontend.parser.ast;
import frontend.parser.ast_utils;
import frontend.values;
import middle.std_lib_module_builder : StdLibFunction;
import backend.codegen.core;
import middle.semantic;
import middle.primitives;

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

    // Para suporte a classes
    StructDefinition currentClass;
    string[string] classTypes; // Mapeia nomes de classes para tipos
    bool[string] mangles;

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
        case TypesNative.LONG:
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
            // Verificar se é um tipo de classe customizado
            if (t.className in classTypes)
            {
                result = new Type(TypeKind.Custom, t.className);
            }
            else
            {
                throw new Exception(format("Tipo desconhecido '%s'.", t.baseType));
            }
        }

        if (t.isArray)
        {
            result = new Type(TypeKind.Array, cast(string) t.baseType, result);
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
        enforce(node !is null, "generate() recebeu null – verifique initializers no AST.");

        switch (node.kind)
        {
        case NodeType.Program:
            return GenerationResult(genProgram(cast(Program) node));

            // Declarações de variáveis
        case NodeType.VariableDeclaration:
            return GenerationResult(genVariableDeclaration(cast(VariableDeclaration) node));
        case NodeType.UninitializedVariableDeclaration:
            return GenerationResult(
                genUninitializedVariableDeclaration(cast(UninitializedVariableDeclaration) node));
        case NodeType.MultipleVariableDeclaration:
            return GenerationResult(
                genMultipleVariableDeclaration(cast(MultipleVariableDeclaration) node));
        case NodeType.MultipleUninitializedVariableDeclaration:
            return GenerationResult(
                genMultipleUninitializedVariableDeclaration(
                    cast(MultipleUninitializedVariableDeclaration) node));

            // Declarações de função
        case NodeType.FunctionDeclaration:
            return GenerationResult(genFunctionDeclaration(cast(FunctionDeclaration) node));
        case NodeType.ReturnStatement:
            return GenerationResult(genReturnStatement(cast(ReturnStatement) node));

            // Declarações de classe
        case NodeType.ClassDeclaration:
            return GenerationResult(genClassDeclaration(cast(ClassDeclaration) node));
        case NodeType.ConstructorDeclaration:
            return GenerationResult(genConstructorDeclaration(cast(ConstructorDeclaration) node));
        case NodeType.DestructorDeclaration:
            return GenerationResult(genDestructorDeclaration(cast(DestructorDeclaration) node));

            // Statements de controle
        case NodeType.IfStatement:
            return GenerationResult(genIfStatement(cast(IfStatement) node));
        case NodeType.ElseStatement:
            return GenerationResult(genElseStatement(cast(ElseStatement) node));
        case NodeType.WhileStatement:
            return GenerationResult(genWhileStatement(cast(WhileStatement) node));
        case NodeType.DoWhileStatement:
            return GenerationResult(genDoWhileStatement(cast(DoWhileStatement) node));
        case NodeType.ForStatement:
            return GenerationResult(genForStatement(cast(ForStatement) node));
        case NodeType.AssignmentDeclaration:
            return GenerationResult(genAssignmentDeclaration(cast(AssignmentDeclaration) node));
        case NodeType.SwitchStatement:
            return GenerationResult(genSwitchStatement(cast(SwitchStatement) node));
        case NodeType.CaseStatement:
            return GenerationResult(genCaseStatement(cast(CaseStatement) node));
        case NodeType.DefaultStatement:
            return GenerationResult(genDefaultStatement(cast(DefaultStatement) node));
        case NodeType.BreakStatement:
            return GenerationResult(genBreakStatement(cast(BreakStatement) node));
        case NodeType.ImportStatement:
            return Variant(null);

            // Literais
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
        case NodeType.ArrayLiteral:
            return GenerationResult(genArrayLiteral(cast(ArrayLiteral) node));

            // Identificadores
        case NodeType.Identifier:
            return GenerationResult(genIdentifier(cast(Identifier) node));

            // Expressões
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
        case NodeType.MemberCallExpr:
            return GenerationResult(genMemberCallExpr(cast(MemberCallExpr) node));
        case NodeType.NewExpr:
            return GenerationResult(genNewExpr(cast(NewExpr) node));
        case NodeType.ThisExpr:
            return GenerationResult(genThisExpr(cast(ThisExpr) node));

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

    Expression genArrayLiteral(ArrayLiteral node)
    {
        writeln(node.elements);
        Expression[] elements = node.elements.map!(x => generate(x).get!Expression).array;
        writeln(elements);
        return new ArrayLiteralExpression(new Type(TypeKind.Array, cast(string) node.type.baseType, this.getType(
                node.type)), elements);
    }

    Statement genClassDeclaration(ClassDeclaration node)
    {
        auto className = node.id.value.get!string;

        // Registrar o tipo de classe
        classTypes[className] = className;

        // Criar estrutura de classe
        currentClass = new StructDefinition(className, true); // true para class

        pushScope(); // Criar escopo para membros da classe
        scope (exit)
            popScope();

        // Processar propriedades
        foreach (prop; node.properties)
        {
            auto propName = prop.name.value.get!string;
            auto propType = getType(prop.type);

            string defaultValue = "";
            if (prop.defaultValue !is null)
            {
                auto defaultExpr = asExpression(generate(prop.defaultValue));
                defaultValue = defaultExpr.generateD();
            }

            currentClass.addField(propType, propName, defaultValue);

            // Adicionar propriedade ao escopo
            addSymbol(propName, prop.type, false);
        }

        // Processar construtor
        if (node.construct !is null)
        {
            auto constructor = genConstructorMethod(node.construct);
            currentClass.addMethod(constructor);
        }

        // Processar destrutor
        if (node.destruct !is null)
        {
            auto destructor = genDestructorMethod(node.destruct);
            currentClass.addMethod(destructor);
        }

        // Processar métodos
        foreach (method; node.methods)
        {
            auto methodGen = genClassMethod(method);
            currentClass.addMethod(methodGen);
        }

        // Adicionar classe ao módulo
        if (auto extCodegen = cast(ExtendedCodeGenerator) codegen)
        {
            extCodegen.addStruct(currentClass);
        }

        // Adicionar classe ao escopo global
        addSymbol(className, FTypeInfo(TypesNative.NULL), false);

        currentClass = null;
        return null;
    }

    Method genConstructorMethod(ConstructorDeclaration node)
    {
        Parameter[] params;
        params.reserve(node.args.length);
        foreach (arg; node.args)
        {
            params ~= Parameter(getType(arg.type), arg.id.value.get!string);
        }

        auto constructor = new Method(
            new Type(TypeKind.Void),
            "this",
            params,
            false,
            "public"
        );

        // Processar corpo do construtor
        pushScope();
        scope (exit)
            popScope();

        // Adicionar parâmetros ao escopo
        foreach (arg; node.args)
        {
            addSymbol(arg.id.value.get!string, arg.type, false);
        }

        foreach (stmt; node.body)
        {
            auto result = generate(stmt);
            if (result.type == typeid(Statement))
            {
                auto statement = result.get!Statement;
                if (statement !is null)
                {
                    constructor.addStatement(statement);
                }
            }
            else if (result.type == typeid(Expression))
            {
                auto statement = result.get!Expression;
                if (statement !is null)
                {
                    constructor.addStatement(new ExpressionStatement(statement));
                }
            }
        }

        return constructor;
    }

    Method genDestructorMethod(DestructorDeclaration node)
    {
        auto destructor = new Method(
            new Type(TypeKind.Void),
            "~this",
            [],
            false,
            "public"
        );

        // Processar corpo do destrutor
        pushScope();
        scope (exit)
            popScope();

        foreach (stmt; node.body)
        {
            auto result = generate(stmt);
            if (result.type == typeid(Statement))
            {
                auto statement = result.get!Statement;
                if (statement !is null)
                {
                    destructor.addStatement(statement);
                }
            }
            else if (result.type == typeid(Expression))
            {
                auto statement = result.get!Expression;
                if (statement !is null)
                {
                    destructor.addStatement(new ExpressionStatement(statement));
                }
            }
        }

        return destructor;
    }

    Method genClassMethod(ClassMethodDeclaration node)
    {
        auto methodName = node.id.value.get!string;

        Parameter[] params;
        params.reserve(node.args.length);
        foreach (arg; node.args)
        {
            params ~= Parameter(getType(arg.type), arg.id.value.get!string);
        }

        string visibility = node.visibility == ClassVisibility.PRIVATE ? "private" : "public";

        auto method = new Method(
            getType(node.type),
            methodName,
            params,
            false,
            visibility
        );

        // Processar corpo do método
        pushScope();
        scope (exit)
            popScope();

        // Adicionar parâmetros ao escopo
        foreach (arg; node.args)
        {
            addSymbol(arg.id.value.get!string, arg.type, false);
        }

        foreach (stmt; node.body)
        {
            auto result = generate(stmt);
            if (result.type == typeid(Statement))
            {
                auto statement = result.get!Statement;
                if (statement !is null)
                {
                    method.addStatement(statement);
                }
            }
            else if (result.type == typeid(Expression))
            {
                auto statement = result.get!Expression;
                if (statement !is null)
                {
                    method.addStatement(new ExpressionStatement(statement));
                }
            }
        }

        return method;
    }

    Statement genConstructorDeclaration(ConstructorDeclaration node)
    {
        // Este método é chamado quando encontramos um construtor fora de uma classe
        // Normalmente isso não deveria acontecer, mas podemos tratar como erro
        throw new Exception("Construtor encontrado fora de uma declaração de classe");
    }

    Statement genDestructorDeclaration(DestructorDeclaration node)
    {
        // Este método é chamado quando encontramos um destrutor fora de uma classe
        // Normalmente isso não deveria acontecer, mas podemos tratar como erro
        throw new Exception("Destrutor encontrado fora de uma declaração de classe");
    }

    Expression genNewExpr(NewExpr node)
    {
        auto className = node.className.value.get!string;

        if (className !in classTypes)
        {
            throw new Exception(format("Classe '%s' não foi declarada", className));
        }

        Expression[] args;
        args.reserve(node.args.length);
        foreach (arg; node.args)
        {
            args ~= asExpression(generate(arg));
        }

        auto classType = new Type(TypeKind.Custom, className);
        return new NewExpression(classType, args);
    }

    Expression genThisExpr(ThisExpr node)
    {
        if (currentClass is null)
        {
            throw new Exception("'isto' usado fora de uma classe");
        }

        auto classType = new Type(TypeKind.Custom, currentClass.name);

        return new VariableExpression(classType, "this");
    }

    // Métodos existentes (mantidos como estavam)
    Statement genProgram(Program node)
    {
        pushScope();

        // Primeiro passo: registrar todas as funções e classes
        foreach (stmt; node.body)
        {
            if (stmt.kind == NodeType.FunctionDeclaration)
            {
                auto funcDecl = cast(FunctionDeclaration) stmt;
                auto funcName = funcDecl.id.value.get!string;
                addSymbol(funcName, funcDecl.type, true);
            }
            else if (stmt.kind == NodeType.ClassDeclaration)
            {
                auto classDecl = cast(ClassDeclaration) stmt;
                auto className = classDecl.id.value.get!string;
                classTypes[className] = className;
                addSymbol(className, FTypeInfo(TypesNative.NULL), false);
            }
        }

        // Segundo passo: processar todas as declarações
        foreach (stmt; node.body)
        {
            auto result = generate(stmt);

            if (result.type == typeid(Statement))
            {
                auto _stmt = result.get!Statement;
                if (mainFunc !is null && _stmt !is null)
                {
                    if (currentFunc !is null)
                    {
                        currentFunc.addStatement(_stmt);
                    }
                    else
                    {
                        mainFunc.addStatement(_stmt);
                    }
                }
            }

            if (result.type == typeid(Expression))
            {
                auto expr = result.get!Expression;
                if (expr !is null && mainFunc !is null)
                {
                    auto exprStmt = new ExpressionStatement(expr);
                    if (currentFunc !is null)
                    {
                        currentFunc.addStatement(exprStmt);
                    }
                    else
                    {
                        mainFunc.addStatement(exprStmt);
                    }
                }
            }
        }

        popScope();
        return null;
    }

    Expression genPrimitive(MemberCallExpr node, Expression[] args = [
        ])
    {
        // vamos traduzir pra uma chamada de função
        PrimitiveProperty fn;

        if (node.object.type.isArray)
        {
            fn = semantic.primitive.get("array")
                .properties[node.member.value.get!string];
            fn.args[0] = node.object.type; // atualiza o primeiro argumento pro tipo atual
            // fn.args[0].baseType = TypesNative.T;
        }
        else
            fn = semantic.primitive.get(cast(string) node.object.type.baseType)
                .properties[node.member.value.get!string];

        if (fn.mangle !in mangles)
        {
            mangles[fn.mangle] = true;
            codegen.currentModule.addStdFunction(fn.generateD());
        }

        return new CallExpression(getType(node.object.type), fn.mangle, args);
    }

    Expression genMemberCallExpr(MemberCallExpr node)
    {
        Expression objectExpr = asExpression(generate(node.object));
        string memberName = node.member.value.get!string;
        string type = cast(string) node.object.type.baseType; // a esquerda do ponto
        GenerationResult obj = generate(node.object);
        Expression[] args;

        if (node.object.type.isArray)
            type = "array";

        if (node.isMethodCall)
        {
            foreach (arg; node.args)
                args ~= asExpression(generate(arg));
            if (semantic.primitive.exists(type))
            {
                args = asExpression(obj) ~ args;
                return genPrimitive(node, args);
            }
            return new MethodCallExpression(getType(node.type), objectExpr, memberName, args);
        }
        else
        {
            if (semantic.primitive.exists(type))
            {
                args = asExpression(obj) ~ args;
                return genPrimitive(node, args);
            }
            return new MemberAccessExpression(getType(node.type), objectExpr, memberName);
        }
    }

    Statement genSwitchStatement(SwitchStatement node)
    {
        Expression condition = asExpression(generate(node.condition));
        auto switchStmt = new SwitchStatementCore(condition);

        foreach (case_; node.cases)
        {
            Expression[] caseValues = [asExpression(generate(case_.value))];
            Statement[] caseBody;

            foreach (stmt; case_.body)
            {
                auto result = generate(stmt);
                genBlock(result, caseBody);
            }

            switchStmt.addCase(caseValues, caseBody);
        }

        if (node.defaultCase !is null)
        {
            Statement[] defaultBody;
            foreach (stmt; node.defaultCase.body)
            {
                auto result = generate(stmt);
                genBlock(result, defaultBody);
            }
            switchStmt.setDefault(defaultBody);
        }

        return switchStmt;
    }

    Statement genCaseStatement(CaseStatement node)
    {
        Statement[] body;
        foreach (stmt; node.body)
        {
            auto result = generate(stmt);
            genBlock(result, body);
        }
        return new BlockStatement(body);
    }

    Statement genDefaultStatement(DefaultStatement node)
    {
        Statement[] body;
        foreach (stmt; node.body)
        {
            auto result = generate(stmt);
            genBlock(result, body);
        }
        return new BlockStatement(body);
    }

    Statement genBreakStatement(BreakStatement node)
    {
        return new BreakStatementCore();
    }

    Statement genMultipleUninitializedVariableDeclaration(
        MultipleUninitializedVariableDeclaration node)
    {
        if (node.ids !is null && node.ids.length > 0)
        {
            Statement[] declarations;

            foreach (id; node.ids)
            {
                auto varName = id.value.get!string;
                addSymbol(varName, node.commonType, false);

                auto var = new VariableDeclarationCore(
                    getType(node.commonType),
                    varName,
                    null
                );

                declarations ~= var;
                if (currentFunc !is null)
                {
                    currentFunc.addStatement(var);
                }
                else
                {
                    mainFunc.addStatement(var);
                }
            }

            return null;
        }
        else
        {
            throw new Exception(
                "Declaração não inicializada deve ter pelo menos um identificador.");
        }
    }

    Statement genUninitializedVariableDeclaration(UninitializedVariableDeclaration node)
    {
        if (node.id !is null)
        {
            auto varName = node.id.value.get!string;
            addSymbol(varName, node.type, false);

            auto var = new VariableDeclarationCore(
                getType(node.type),
                varName,
                null
            );

            return var;
        }
        else
        {
            throw new Exception(
                "Declaração não inicializada deve ter pelo menos um identificador.");
        }
    }

    Statement genMultipleVariableDeclaration(MultipleVariableDeclaration node)
    {
        if (node.declarations.length == 0)
        {
            throw new Exception("Declaração múltipla deve conter pelo menos uma variável.");
        }

        Statement[] declarations;
        declarations.reserve(node.declarations.length);

        foreach (decl; node.declarations)
        {
            auto varName = decl.id.value.get!string;

            addSymbol(varName, decl.type, false);

            Expression expr = null;
            if (decl.value !is null)
            {
                expr = asExpression(generate(decl.value));
            }
            else
            {
                expr = createDefaultValue(decl.type);
            }

            auto var = new VariableDeclarationCore(
                expr.type,
                varName,
                expr
            );

            declarations ~= var;

            if (currentFunc !is null)
            {
                currentFunc.addStatement(var);
            }
            else
            {
                mainFunc.addStatement(var);
            }
        }

        if (declarations.length == 1)
        {
            return declarations[0];
        }

        return null;
    }

    Statement convertToStatement(GenerationResult result)
    {
        if (result.type == typeid(Statement))
        {
            return result.get!Statement;
        }
        else if (result.type == typeid(Expression))
        {
            auto expr = result.get!Expression;
            return new ExpressionStatement(expr);
        }
        else
        {
            throw new Exception("Resultado deve ser Statement ou Expression");
        }
    }

    void processVariableDeclarationForScope(Stmt node)
    {
        switch (node.kind)
        {
        case NodeType.VariableDeclaration:
            auto varDecl = cast(VariableDeclaration) node;
            addSymbol(varDecl.id.value.get!string, varDecl.type, false);
            break;

        case NodeType.UninitializedVariableDeclaration:
            auto uninitDecl = cast(UninitializedVariableDeclaration) node;
            if (uninitDecl.id !is null)
            {
                addSymbol(uninitDecl.id.value.get!string, uninitDecl.type, false);
            }
            break;

        case NodeType.MultipleUninitializedVariableDeclaration:
            auto multiDecl = cast(MultipleUninitializedVariableDeclaration) node;
            if (multiDecl.ids !is null)
            {
                foreach (id; multiDecl.ids)
                {
                    addSymbol(id.value.get!string, multiDecl.commonType, false);
                }
            }
            break;

        case NodeType.MultipleVariableDeclaration:
            auto multiDecl = cast(MultipleVariableDeclaration) node;
            foreach (decl; multiDecl.declarations)
            {
                addSymbol(decl.id.value.get!string, decl.type, false);
            }
            break;

        default:
            // Não é uma declaração de variável
            break;
        }
    }

    Expression createInitializerExpression(Stmt node)
    {
        if (node is null)
        {
            return null;
        }

        switch (node.kind)
        {
        case NodeType.VariableDeclaration:
            auto varDecl = cast(VariableDeclaration) node;
            if (varDecl.value.type == typeid(Stmt))
            {
                auto stmt = varDecl.value.get!Stmt;
                if (stmt !is null)
                {
                    return asExpression(generate(stmt));
                }
            }
            return createDefaultValue(varDecl.type);

        case NodeType.UninitializedVariableDeclaration:
            auto uninitDecl = cast(UninitializedVariableDeclaration) node;
            return createDefaultValue(uninitDecl.type);

        case NodeType.MultipleVariableDeclaration:
            throw new Exception(
                "createInitializerExpression não deve ser chamado para declarações múltiplas");

        default:
            return asExpression(generate(node));
        }
    }

    bool isValidForLoopInitialization(Stmt node)
    {
        return node.kind == NodeType.VariableDeclaration ||
            node.kind == NodeType.MultipleVariableDeclaration ||
            node.kind == NodeType.AssignmentDeclaration;
    }

    FTypeInfo getDeclarationType(Stmt node)
    {
        switch (node.kind)
        {
        case NodeType.VariableDeclaration:
            return (cast(VariableDeclaration) node).type;

        case NodeType.UninitializedVariableDeclaration:
            auto uninitDecl = cast(UninitializedVariableDeclaration) node;
            return uninitDecl.type;

        case NodeType.MultipleVariableDeclaration:
            auto multiDecl = cast(MultipleVariableDeclaration) node;
            return multiDecl.commonType.baseType != TypesNative.NULL ?
                multiDecl.commonType : multiDecl.declarations[0].type;

        default:
            throw new Exception("Tipo de nó não é uma declaração de variável");
        }
    }

    void genBlock(GenerationResult result, ref Statement[] body)
    {
        if (result.type == typeid(Statement))
        {
            auto statement = result.get!Statement;
            if (statement !is null)
            {
                body ~= statement;
            }
        }
        else if (result.type == typeid(Expression))
        {
            auto expr = result.get!Expression;
            if (expr !is null)
            {
                body ~= new ExpressionStatement(expr);
            }
        }
    }

    Statement genForStatement(ForStatement node)
    {
        Statement _init = generate(node._init).get!Statement;
        Expression cond = generate(node.cond).get!Expression;
        auto temp_incr = generate(node.expr);
        Statement incr = temp_incr.type == typeid(Expression) ? new ExpressionStatement(
            temp_incr.get!Expression) : temp_incr.get!Statement;

        Statement[] body = [];
        foreach (Stmt stmt; node.body)
        {
            auto result = this.generate(stmt);
            genBlock(result, body);
        }

        auto _for = new ForStatementCore(_init, cond, incr, new BlockStatement(body));
        return _for;
    }

    Statement genDoWhileStatement(DoWhileStatement node)
    {
        Expression cond = generate(node.cond).get!Expression;
        Statement[] body = [];
        foreach (Stmt stmt; node.body)
        {
            auto result = this.generate(stmt);
            genBlock(result, body);
        }

        auto _while = new DoWhileStatementCore(cond, new BlockStatement(body));
        return _while;
    }

    Statement genWhileStatement(WhileStatement node)
    {
        Expression cond = generate(node.cond).get!Expression;
        Statement[] body = [];
        foreach (Stmt stmt; node.body)
        {
            auto result = this.generate(stmt);
            genBlock(result, body);
        }

        auto _while = new WhileStatementCore(cond, new BlockStatement(body));
        return _while;
    }

    Statement genAssignmentDeclaration(AssignmentDeclaration node)
    {
        auto varName = node.id.value.get!string;
        Expression expr = generate(node.value.get!Stmt).get!Expression;
        auto ass = new AssignmentStatement(varName, expr);
        return ass;
    }

    Statement genElseStatement(ElseStatement node)
    {
        Statement[] stmts = [];
        foreach (Stmt stmt; node.primary)
        {
            auto result = this.generate(stmt);
            genBlock(result, stmts);
        }

        auto then = new BlockStatement(stmts);
        auto _else = new ElseStatementCore(then);
        return _else;
    }

    Statement genIfStatement(IfStatement node)
    {
        Statement[] stmts = [];
        Statement elseIf = null;
        Statement elseStmt = null;

        if (!node.secondary.isNull && node.secondary != null)
        {
            elseIf = this.generate(node.secondary.get).get!Statement;
        }

        foreach (Stmt stmt; node.primary)
        {
            auto result = this.generate(stmt);
            genBlock(result, stmts);
        }

        auto condition = this.generate(node.condition).get!Expression;
        auto then = new BlockStatement(stmts);
        auto _if = new IfStatementCore(condition, then, elseStmt, elseIf);
        return _if;
    }

    Expression genStringLiteral(StringLiteral node)
    {
        return new LiteralExpression(getType(node.type), format("\"%s\"", node.value.get!string));
    }

    Expression genIntLiteral(IntLiteral node)
    {
        auto value = node.value.get!long;
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

    Expression genIdentifier(Identifier node, bool isThis = false)
    {
        auto name = node.value.get!string;
        Type type;

        if (node.type.baseType == TypesNative.CLASS)
        {
            // node.value = Variant("this"); // vamos substituir o 'isto' para 'this'
            type = getType(node.type);
        }
        else
        {
            auto symbol = lookupSymbol(name);
            if (symbol is null)
            {
                throw new Exception(format("Variável/função '%s' não foi declarada", name));
            }

            type = getType((*symbol).type);
        }

        return new VariableExpression(type, name);
    }

    import std.math : abs;

    Expression genBinaryExpr(BinaryExpr node)
    {
        auto leftExpr = asExpression(generate(node.left));
        auto rightExpr = asExpression(generate(node.right));

        if (node.op == "**")
        {
            if (leftExpr.type.kind == TypeKind.Float64 || rightExpr.type.kind == TypeKind.Float64)
            {
                codegen.currentModule.addImport("std.math");

                // Verificar se o expoente é 0.5 (raiz quadrada)
                if (auto floatLit = cast(FloatLiteral) node.right)
                {
                    if (auto floatVal = floatLit.value.peek!float)
                    {
                        if (abs(*floatVal - 0.5f) < 1e-6f)
                        {
                            // Retornar sqrt diretamente com o tipo correto
                            auto doubleType = new Type(TypeKind.Float64, "double");
                            return new CallExpression(doubleType, "sqrt", [
                                    new CastExpression(doubleType, leftExpr)
                                ]);
                        }
                    }
                }

                // Verificar também se é um IntLiteral com valor 0 (para casos como x ** 0)
                if (auto intLit = cast(IntLiteral) node.right)
                {
                    if (auto intVal = intLit.value.peek!long)
                    {
                        if (*intVal == 0)
                        {
                            // x ** 0 = 1
                            return new LiteralExpression(leftExpr.type, "1");
                        }
                        else if (*intVal == 1)
                        {
                            // x ** 1 = x
                            return leftExpr;
                        }
                    }
                }

                auto doubleType = new Type(TypeKind.Float64, "double");
                return new CallExpression(doubleType, "pow", [
                        new CastExpression(doubleType, leftExpr),
                        new CastExpression(doubleType, rightExpr)
                    ]);
            }
            else
            {
                node.op = "^^";
            }
        }

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

        auto previousFunc = currentFunc;
        scope (exit)
            currentFunc = previousFunc;

        currentFunc = func;

        pushScope();
        scope (exit)
            popScope();

        foreach (arg; node.args)
        {
            addSymbol(arg.id.value.get!string, arg.type, false);
        }

        foreach (stmt; node.body)
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
            else if (result.type == typeid(Expression))
            {
                auto statement = result.get!Expression;
                if (statement !is null)
                {
                    func.addStatement(new ExpressionStatement(statement));
                }
            }
        }

        codegen.currentModule.addFunction(func);

        return null;
    }

    Statement genVariableDeclaration(VariableDeclaration node)
    {
        auto varName = node.id.value.get!string;

        addSymbol(varName, node.type, false);

        Expression expr = createInitializerExpression(node);

        auto var = new VariableDeclarationCore(
            expr.type,
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
        case TypesNative.LONG:
            return new LiteralExpression(type, "0");
        case TypesNative.BOOL:
            return new LiteralExpression(type, "false");
        case TypesNative.FLOAT:
            return new LiteralExpression(type, "0.0");
        case TypesNative.STRING:
            return new LiteralExpression(type, "");
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

        // Usar ExtendedCodeGenerator para suporte a classes
        this.codegen = new ExtendedCodeGenerator("main");
        this.mainFunc = new Function(getType(FTypeInfo(TypesNative.VOID)), "main");

        // importando as funções std para nosso contexto atual
        foreach (string name, StdLibFunction func; semantic.availableStdFunctions)
            this.globalScope[name] = Symbol(func.returnType, name, true);
    }

    void build()
    {
        codegen.currentModule.addFunction(mainFunc);
        this.genProgram(this.program);

        // Adicionando as bibliotecas
        if (this.semantic.availableStdFunctions.length > 0)
            foreach (string name, StdLibFunction fn; this.semantic.availableStdFunctions)
                codegen.currentModule.addStdFunction(fn.ir);
    }
}
