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
import middle.primitives;
import frontend.parser.ast;
import frontend.values;
import frontend.parser.ftype_info;
import error;

class Semantic
{
public:
    SymbolInfo[string][] scopeStack;

    StdLibFunction[string] availableStdFunctions; // by compiler
    Function[string] availableFunctions; // by user
    bool[string] importedModules;
    StdLibModule[string] stdLibs;
    bool[string] identifiersUsed;
    string currentClassName = ""; // Para rastrear contexto de classe
    StdPrimitive primitive;

    this(DiagnosticError e)
    {
        this.error = e;
        this.pushScope();
        this.typeChecker = getTypeChecker(this);
        this.primitive = new StdPrimitive(); // carrega tudo

        // TODO: Criar uma classe para setar os módulos|libs
        // Vamos adicionar isso aqui temporariamente
        StdLibModuleBuilder mod = new StdLibModuleBuilder("io")
            .defineFunction("escreva")
            .returns(createTypeInfo(TypesNative.NULL))
            .variadic()
            .customTargetType("void")
            .libraryName("io_escreva")
            .generateDExternComplete()
            .done()
            .defineFunction("escrevaln")
            .returns(createTypeInfo(TypesNative.NULL))
            .variadic()
            .customTargetType("void")
            .libraryName("io_escrevaln")
            .generateDExternComplete()
            .done();

        this.stdLibs["io"] = mod.moduleData;
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
                // da pra ignorar isso não ironicamente
                writeln("Erro no semantic: ", e.message);
                writeln("Erro no semantic: ", e.file);
                writeln("Erro no semantic: ", e.line);
                break;
            }
        }

        program.body = analyzedNodes;
        return program;
    }

private:
    static Nullable!Semantic instance = null;
    Stmt[] nodes;
    TypeChecker typeChecker;
    DiagnosticError error;

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
        case NodeType.UninitializedVariableDeclaration:
            analyzedNode = this.analyzeUninitializedVarDeclaration(
                cast(UninitializedVariableDeclaration) node);
            break;
        case NodeType.MultipleVariableDeclaration:
            analyzedNode = this.analyzeMultipleVarDeclaration(
                cast(MultipleVariableDeclaration) node);
            break;
        case NodeType.MultipleUninitializedVariableDeclaration:
            analyzedNode = this.analyzeMultipleUninitializedVariableDeclaration(
                cast(MultipleUninitializedVariableDeclaration) node);
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
            analyzedNode = this.analyzeCallExpr(cast(CallExpr) node);
            break;
        case NodeType.IfStatement:
            analyzedNode = this.analyzeIfStatement(cast(IfStatement) node);
            break;
        case NodeType.ElseStatement:
            analyzedNode = this.analyzeElseStatement(cast(ElseStatement) node);
            break;
        case NodeType.ForStatement:
            analyzedNode = this.analyzeForStatement(cast(ForStatement) node);
            break;
        case NodeType.WhileStatement:
            analyzedNode = this.analyzeWhileStatement(cast(WhileStatement) node);
            break;
        case NodeType.DoWhileStatement:
            analyzedNode = this.analyzeDoWhileStatement(cast(DoWhileStatement) node);
            break;
        case NodeType.AssignmentDeclaration:
            analyzedNode = this.analyzeAssignmentDeclaration(cast(AssignmentDeclaration) node);
            break;
        case NodeType.UnaryExpr:
            analyzedNode = analyzeUnaryExpr(cast(UnaryExpr) node);
            break;
        case NodeType.MemberCallExpr:
            analyzedNode = this.analyzeMemberCallExpr(cast(MemberCallExpr) node);
            break;
        case NodeType.SwitchStatement:
            analyzedNode = this.analyzeSwitchStatement(cast(SwitchStatement) node);
            break;
        case NodeType.CaseStatement:
            analyzedNode = this.analyzeCaseStatement(cast(CaseStatement) node);
            break;
        case NodeType.DefaultStatement:
            analyzedNode = this.analyzeDefaultStatement(cast(DefaultStatement) node);
            break;
        case NodeType.BreakStatement:
            analyzedNode = this.analyzeBreakStatement(cast(BreakStatement) node);
            break;
        case NodeType.ImportStatement:
            analyzedNode = this.analyzeImportStatement(cast(ImportStatement) node);
            break;
        case NodeType.ClassDeclaration:
            analyzedNode = this.analyzeClassDeclaration(cast(ClassDeclaration) node);
            break;
        case NodeType.ConstructorDeclaration:
            analyzedNode = this.analyzeConstructorDeclaration(cast(ConstructorDeclaration) node);
            break;
        case NodeType.DestructorDeclaration:
            analyzedNode = this.analyzeDestructorDeclaration(cast(DestructorDeclaration) node);
            break;
        case NodeType.NewExpr:
            analyzedNode = this.analyzeNewExpr(cast(NewExpr) node);
            break;
        case NodeType.ThisExpr:
            analyzedNode = this.analyzeThisExpr(cast(ThisExpr) node);
            break;

        case NodeType.StringLiteral:
        case NodeType.IntLiteral:
        case NodeType.FloatLiteral:
        case NodeType.NullLiteral:
        case NodeType.BoolLiteral:
            analyzedNode = node;
            string baseType = this.typeChecker.getTypeStringFromNative(analyzedNode.type.baseType);
            analyzedNode.type.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));
            break;

        default:
            throw new Exception(format("Nó desconhecido '%s'.", to!string(node.kind)));
        }
        return analyzedNode;
    }

    ClassDeclaration analyzeClassDeclaration(ClassDeclaration node)
    {
        string className = node.id.value.get!string;

        if (className in this.availableFunctions || className in this.availableStdFunctions)
        {
            throw new Exception(format("Nome '%s' já está em uso.", className));
        }

        // Criar tipo personalizado para a classe
        FTypeInfo classType = createClassType(className);

        // Registrar a classe no TypeChecker
        this.typeChecker.registerClass(className, node);

        // Analisar propriedades
        foreach (ref prop; node.properties)
        {
            string baseType = this.typeChecker.getTypeStringFromNative(prop.type.baseType);
            prop.type.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));

            if (prop.defaultValue !is null)
            {
                prop.defaultValue = this.analyzeNode(prop.defaultValue);
            }
        }

        // Analisar métodos
        ClassMethodDeclaration[] analyzedMethods;
        this.currentClassName = className;
        foreach (method; node.methods)
        {
            this.pushScope(); // Escopo do método

            // Adicionar 'isto' ao escopo
            this.addSymbol("isto", SymbolInfo("isto", classType, false, true, method.loc));

            // Adicionar propriedades ao escopo
            foreach (prop; node.properties)
            {
                string propName = prop.name.value.get!string;
                this.addSymbol(propName, SymbolInfo(propName, prop.type, true, true, prop.name.loc));
            }

            // Analisar argumentos do método
            foreach (arg; method.args)
            {
                string argName = arg.id.value.get!string;
                string baseType = this.typeChecker.getTypeStringFromNative(arg.type.baseType);
                arg.type.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));
                this.addSymbol(argName, SymbolInfo(argName, arg.type, true, false, arg.id.loc));
            }

            // Analisar corpo do método
            Stmt[] analyzedBody;
            foreach (stmt; method.body)
            {
                analyzedBody ~= this.analyzeNode(stmt);
            }
            method.body = analyzedBody;
            method.context = this.currentScope();
            method.type.className = className;

            analyzedMethods ~= method;
            this.popScope();
        }

        node.methods = analyzedMethods;

        // Analisar construtor se existir
        if (node.construct !is null)
        {
            node.construct = cast(
                ConstructorDeclaration) this.analyzeConstructorDeclaration(node.construct);
        }

        // Analisar destrutor se existir  
        if (node.destruct !is null)
        {
            node.destruct = cast(
                DestructorDeclaration) this.analyzeDestructorDeclaration(node.destruct);
        }

        this.currentClassName = "";
        node.type = classType;
        return node;
    }

    ConstructorDeclaration analyzeConstructorDeclaration(ConstructorDeclaration node)
    {
        this.pushScope();

        // Analisar argumentos
        foreach (arg; node.args)
        {
            string argName = arg.id.value.get!string;
            string baseType = this.typeChecker.getTypeStringFromNative(arg.type.baseType);
            arg.type.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));
            this.addSymbol(argName, SymbolInfo(argName, arg.type, true, false, arg.id.loc));
        }

        // Analisar corpo
        Stmt[] analyzedBody;
        foreach (stmt; node.body)
        {
            analyzedBody ~= this.analyzeNode(stmt);
        }
        node.body = analyzedBody;
        node.context = this.currentScope();

        this.popScope();
        return node;
    }

    DestructorDeclaration analyzeDestructorDeclaration(DestructorDeclaration node)
    {
        this.pushScope();

        // Analisar corpo
        Stmt[] analyzedBody;
        foreach (stmt; node.body)
        {
            analyzedBody ~= this.analyzeNode(stmt);
        }
        node.body = analyzedBody;
        node.context = this.currentScope();

        this.popScope();
        return node;
    }

    NewExpr analyzeNewExpr(NewExpr node)
    {
        string className = node.className.value.get!string;

        if (!this.typeChecker.isValidClass(className))
        {
            throw new Exception(format("Classe '%s' não foi declarada.", className));
        }

        // Analisar argumentos
        Stmt[] analyzedArgs;
        foreach (arg; node.args)
        {
            analyzedArgs ~= this.analyzeNode(arg);
        }
        node.args = analyzedArgs;

        // O tipo será o da classe
        node.type = createClassType(className);

        return node;
    }

    ThisExpr analyzeThisExpr(ThisExpr node)
    {
        if (this.currentClassName == "")
        {
            throw new Exception("'isto' só pode ser usado dentro de métodos de classe.");
        }
        node.type = createClassType(this.currentClassName);
        return node;
    }

    ImportStatement analyzeImportStatement(ImportStatement node)
    {
        // TODO: suporte para aliases
        // TODO: precisa validar qual tipo de exportação é
        this.importedModules[node.from] = true; // ativa a importação do modulo
        if (node.targets.length > 0)
        {
            foreach (Identifier id; node.targets)
            {
                // TODO: deve verificar se o ID da importação existe
                string _id = id.value.get!string;
                this.availableStdFunctions[_id] = this.stdLibs[node.from].functions[_id];
            }
        }
        else
        {
            StdLibFunction[string] fns = this.stdLibs[node.from].functions;
            foreach (StdLibFunction fn; fns)
            {
                this.availableStdFunctions[fn.name] = fn;
            }
        }
        return node;
    }

    MemberCallExpr analyzeMemberCallExpr(MemberCallExpr node)
    {
        // Analisa o objeto à esquerda do ponto
        node.object = this.analyzeNode(node.object);

        if (node.object.type.baseType == TypesNative.CLASS)
        {
            string className = node.object.type.className;
            // string memberName = node.member.value.get!string;

            // Verificar se a propriedade/método existe na classe
            if (!this.typeChecker.isValidClass(className))
                throw new Exception(format("Classe '%s' não encontrada.", className));

            // TODO: Implementar verificação de membros da classe
        }

        // Analisa o membro (já deve ser um Identifier)
        // node.member = cast(Identifier) this.analyzeNode(node.member);

        // TODO: Verificar se é um primitivo, se for deve haver validação, baseado no tipo do node.object
        string id = node.member.value.get!string;
        string type = cast(string) node.object.type.baseType;
        if (primitive.exists(type) && id in primitive.get(type)
            .properties)
        {
            node.type = createTypeInfo(primitive.get(type)
                    .properties[id].type);
        }
        else
        {
            // Por enquanto, definimos o tipo como o tipo do objeto
            // Em uma implementação mais completa, isso seria determinado
            // baseado no tipo do objeto e no membro acessado
            node.type = node.object.type;
        }

        // Se for uma chamada de método, analisa os argumentos
        if (node.isMethodCall && node.args.length > 0)
        {
            Stmt[] analyzedArgs;
            foreach (arg; node.args)
                analyzedArgs ~= this.analyzeNode(arg);
            node.args = analyzedArgs;
        }

        return node;
    }

    SwitchStatement analyzeSwitchStatement(SwitchStatement node)
    {
        node.condition = this.analyzeNode(node.condition);

        CaseStatement[] analyzedCases;
        foreach (case_; node.cases)
        {
            analyzedCases ~= this.analyzeCaseStatement(case_);
        }
        node.cases = analyzedCases;

        if (node.defaultCase !is null)
        {
            node.defaultCase = this.analyzeDefaultStatement(node.defaultCase);
        }

        return node;
    }

    CaseStatement analyzeCaseStatement(CaseStatement node)
    {
        if (node.value !is null)
        {
            node.value = this.analyzeNode(node.value);
        }

        Stmt[] analyzedBody;
        foreach (stmt; node.body)
        {
            analyzedBody ~= this.analyzeNode(stmt);
        }
        node.body = analyzedBody;

        return node;
    }

    DefaultStatement analyzeDefaultStatement(DefaultStatement node)
    {
        Stmt[] analyzedBody;
        foreach (stmt; node.body)
        {
            analyzedBody ~= this.analyzeNode(stmt);
        }
        node.body = analyzedBody;

        return node;
    }

    BreakStatement analyzeBreakStatement(BreakStatement node)
    {
        return node;
    }

    UnaryExpr analyzeUnaryExpr(UnaryExpr node)
    {
        node.operand = this.analyzeNode(node.operand);

        if (node.op == "++" || node.op == "--")
        {
            if (node.operand.kind != NodeType.Identifier)
            {
                throw new Exception("Operadores '++' e '--' só podem ser aplicados a variáveis.");
            }

            // Usar o novo método do TypeChecker
            node.type = this.typeChecker.checkUnaryExprType(node.operand, node.op, node.postFix);
        }
        else
        {
            // Para outros operadores unários
            node.type = this.typeChecker.checkUnaryExprType(node.operand, node.op, false);
        }

        return node;
    }

    MultipleUninitializedVariableDeclaration analyzeMultipleUninitializedVariableDeclaration(
        MultipleUninitializedVariableDeclaration node)
    {
        if (node.ids !is null && node.ids.length > 0)
        {
            if (node.commonType.baseType == TypesNative.NULL)
            {
                throw new Exception(
                    "Tipo comum deve ser especificado para declarações múltiplas não inicializadas.");
            }

            string baseType = this.typeChecker.getTypeStringFromNative(node.commonType.baseType);
            node.commonType.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));
            node.type = node.commonType;

            foreach (id; node.ids)
            {
                string idName = id.value.get!string;

                if (idName in this.currentScope())
                {
                    throw new Exception(
                        format("A variável '%s' já está definida no escopo em %d:%d",
                            idName, cast(int) id.loc.line, cast(int) id.loc.start));
                }

                this.addSymbol(idName, SymbolInfo(idName, node.commonType, node.mut, true, id.loc));
            }
        }
        else
        {
            throw new Exception(
                "Declaração de variável não inicializada deve ter pelo menos um identificador.");
        }

        return node;
    }

    UninitializedVariableDeclaration analyzeUninitializedVarDeclaration(
        UninitializedVariableDeclaration node)
    {
        if (node is null)
        {
            throw new Exception("Received null UninitializedVariableDeclaration node");
        }

        if (node.id !is null)
        {
            string id = node.id.value.get!string;

            if (id in this.currentScope())
            {
                throw new Exception(
                    format("A variável '%s' já está definida no escopo em %d:%d",
                        id, cast(int) node.id.loc.line, cast(int) node.id.loc.start));
            }

            string baseType = this.typeChecker.getTypeStringFromNative(node.type.baseType);
            node.type.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));

            this.addSymbol(id, SymbolInfo(id, node.type, node.mut, true, node.loc));
        }
        else
        {
            throw new Exception(
                "Declaração de variável não inicializada deve ter pelo menos um identificador.");
        }

        return node;
    }

    MultipleVariableDeclaration analyzeMultipleVarDeclaration(MultipleVariableDeclaration node)
    {
        if (node.declarations.length == 0)
        {
            throw new Exception("Declaração múltipla deve conter pelo menos uma variável.");
        }

        VariablePair[] analyzedDeclarations;

        foreach (i, decl; node.declarations)
        {
            string id = decl.id.value.get!string;

            if (id in this.currentScope())
            {
                throw new Exception(
                    format("A variável '%s' já está definida no escopo em %d:%d",
                        id, cast(int) decl.id.loc.line, cast(int) decl.id.loc.start));
            }

            if (decl.value is null)
            {
                throw new Exception(format("Valor não pode ser nulo para a variável '%s'.", id));
            }

            Stmt analyzedValue = this.analyzeNode(decl.value);

            FTypeInfo finalType;
            if (node.commonType.baseType != TypesNative.NULL)
            {
                finalType = node.commonType;

                string valueTypeStr = this.typeChecker.getTypeStringFromNative(
                    analyzedValue.type.baseType);
                string commonTypeStr = this.typeChecker.getTypeStringFromNative(
                    node.commonType.baseType);

                if (!this.typeChecker.areTypesCompatible(valueTypeStr, commonTypeStr))
                {
                    throw new Exception(
                        format(
                            "Tipo do valor '%s' não é compatível com o tipo declarado '%s' para a variável '%s'.",
                            valueTypeStr, commonTypeStr, id));
                }
            }
            else
            {
                finalType = analyzedValue.type;
            }

            string baseType = this.typeChecker.getTypeStringFromNative(finalType.baseType);
            finalType.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));

            VariablePair analyzedPair = VariablePair(decl.id, analyzedValue, finalType, decl.mut);
            analyzedDeclarations ~= analyzedPair;

            this.addSymbol(id, SymbolInfo(id, finalType, decl.mut, true, decl.id.loc));
        }

        node.declarations = analyzedDeclarations;

        if (node.commonType.baseType != TypesNative.NULL)
        {
            string baseType = this.typeChecker.getTypeStringFromNative(node.commonType.baseType);
            node.commonType.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));
        }

        return node;
    }

    bool hasInitialization(Stmt node)
    {
        switch (node.kind)
        {
        case NodeType.VariableDeclaration:
            auto varDecl = cast(VariableDeclaration) node;
            return varDecl.isInitialized();

        case NodeType.UninitializedVariableDeclaration:
            return false;

        case NodeType.MultipleVariableDeclaration:
            return true;

        default:
            return false;
        }
    }

    Identifier[] getAllDeclaredIdentifiers(Stmt node)
    {
        Identifier[] ids;

        switch (node.kind)
        {
        case NodeType.VariableDeclaration:
            auto varDecl = cast(VariableDeclaration) node;
            ids ~= varDecl.id;
            break;

        case NodeType.UninitializedVariableDeclaration:
            auto uninitDecl = cast(UninitializedVariableDeclaration) node;
            if (uninitDecl.id !is null)
            {
                ids ~= uninitDecl.id;
            }
            break;
        case NodeType.MultipleUninitializedVariableDeclaration:
            auto multiDecl = cast(MultipleUninitializedVariableDeclaration) node;
            if (multiDecl.ids !is null)
            {
                ids ~= multiDecl.ids;
            }
            break;

        case NodeType.MultipleVariableDeclaration:
            auto multiDecl = cast(MultipleVariableDeclaration) node;
            ids = multiDecl.getIdentifiers();
            break;

        default:
            break;
        }

        return ids;
    }

    void validateForLoopInitialization(Stmt node)
    {
        if (node.kind != NodeType.VariableDeclaration &&
            node.kind != NodeType.UninitializedVariableDeclaration &&
            node.kind != NodeType.MultipleVariableDeclaration &&
            node.kind != NodeType.AssignmentDeclaration)
        {
            throw new Exception(
                "É esperado uma declaração ou redeclaração de variável no início do 'para'.");
        }

        if (node.kind == NodeType.UninitializedVariableDeclaration)
        {
            throw new Exception(
                "Declarações não inicializadas não são permitidas na inicialização de loops 'para'.");
        }
    }

    AssignmentDeclaration analyzeAssignmentDeclaration(AssignmentDeclaration node)
    {
        string id = node.id.value.get!string;

        if (!(id in this.currentScope()))
            throw new Exception(format(
                    "Não é possível redeclarar uma variável inexistente '%s'.", id));

        node.id = cast(Identifier) this.analyzeIdentifier(node.id);
        node.value = this.analyzeNode(node.value.get!Stmt);

        return node;
    }

    DoWhileStatement analyzeDoWhileStatement(DoWhileStatement node)
    {
        // this(Stmt cond, Stmt[] body, Loc loc)
        node.cond = this.analyzeNode(node.cond);
        for (long i; i < node.body.length; i++)
            node.body[i] = this.analyzeNode(node.body[i]);
        return node;
    }

    WhileStatement analyzeWhileStatement(WhileStatement node)
    {
        // this(Stmt cond, Stmt[] body, Loc loc)
        node.cond = this.analyzeNode(node.cond);
        for (long i; i < node.body.length; i++)
            node.body[i] = this.analyzeNode(node.body[i]);
        return node;
    }

    ForStatement analyzeForStatement(ForStatement node)
    {
        // this(Stmt _init, Stmt cond, Stmt expr, Stmt[] body, Loc loc)
        node._init = this.analyzeNode(node._init);
        node.cond = this.analyzeNode(node.cond);
        node.expr = this.analyzeNode(node.expr);
        for (long i; i < node.body.length; i++)
            node.body[i] = this.analyzeNode(node.body[i]);
        return node;
    }

    ElseStatement analyzeElseStatement(ElseStatement node)
    {
        for (long i; i < node.primary.length; i++)
        {
            node.primary[i] = this.analyzeNode(node.primary[i]);
        }
        return node;
    }

    IfStatement analyzeIfStatement(IfStatement node)
    {
        node.condition = this.analyzeNode(node.condition);

        for (long i; i < node.primary.length; i++)
        {
            node.primary[i] = this.analyzeNode(node.primary[i]);
        }

        if (!node.secondary.isNull && node.secondary != null)
        {
            node.secondary = this.analyzeNode(node.secondary.get);
        }

        return node;
    }

    CallExpr analyzeCallExpr(CallExpr node)
    {
        string funcName = node.calle.value.get!string;

        Function* userFunc = funcName in this.availableFunctions;
        StdLibFunction* stdFunc = funcName in this.availableStdFunctions;

        if (!userFunc && !stdFunc)
        {
            throw new Exception(format("A função '%s' não está definida.", funcName));
        }

        FTypeInfo returnType;
        FunctionParam[] userExpectedParams;
        string[] stdExpectedParams;
        bool isVariadic = false;
        string funcType;
        bool isStdFunction = false;

        if (userFunc)
        {
            returnType = userFunc.returnType;
            userExpectedParams = userFunc.params;
            isVariadic = userFunc.isVariadic;
            funcType = userFunc.targetType;
            isStdFunction = false;
        }
        else if (stdFunc)
        {
            returnType = stdFunc.returnType;
            stdExpectedParams = stdFunc.params;
            isVariadic = stdFunc.isVariadic;
            funcType = stdFunc.targetType;
            isStdFunction = true;
        }

        // Verifica número de argumentos (apenas se não for variadic)
        size_t expectedArgCount = isStdFunction ? stdExpectedParams.length
            : userExpectedParams.length;

        if (!isVariadic && node.args.length != expectedArgCount)
        {
            throw new Exception(format(
                    "A função '%s' espera %d argumentos, mas recebeu %d.",
                    funcName, expectedArgCount, node.args.length
            ));
        }

        node.type = returnType;

        if (!(funcName in this.identifiersUsed))
        {
            this.identifiersUsed[funcName] = true;
        }

        Stmt[] analyzedArgs;
        analyzedArgs.reserve(node.args.length);

        for (size_t i = 0; i < node.args.length; i++)
        {
            Stmt analyzedArg = this.analyzeNode(node.args[i]);

            if (i >= expectedArgCount && isVariadic)
            {
                analyzedArgs ~= analyzedArg;
                continue;
            }

            if (i >= expectedArgCount)
            {
                throw new Exception(format(
                        "Muitos argumentos para a função '%s'. Esperado %d, recebido %d.",
                        funcName, expectedArgCount, node.args.length
                ));
            }

            TypesNative expectedParamType;
            string expectedParamTypeStr;

            if (isStdFunction)
            {
                // Para std functions, params é string[]
                expectedParamTypeStr = stdExpectedParams[i];
                expectedParamType = stringToTypesNative(
                    this.typeChecker.mapToDType(expectedParamTypeStr));
                // expectedParamType = cast(TypesNative) this.typeChecker.mapToDType(
                //     expectedParamTypeStr);
            }
            else
            {
                // Para user functions, params é FunctionParam[]
                expectedParamType = userExpectedParams[i].type.baseType;
                expectedParamTypeStr = userExpectedParams[i].targetType;
            }

            FTypeInfo argType = analyzedArg.type;

            if (argType.baseType != TypesNative.STRING && expectedParamType == TypesNative.STRING)
            {
                analyzedArg.type.baseType = TypesNative.STRING;

                switch (argType.baseType)
                {
                case TypesNative.LONG:
                    if (analyzedArg.value.hasValue())
                    {
                        analyzedArg.value = to!string(analyzedArg.value.get!long);
                    }
                    break;
                case TypesNative.FLOAT:
                    if (analyzedArg.value.hasValue())
                    {
                        analyzedArg.value = to!string(analyzedArg.value.get!float);
                    }
                    break;
                case TypesNative.BOOL:
                    if (analyzedArg.value.hasValue())
                    {
                        analyzedArg.value = analyzedArg.value.get!bool ? "true" : "false";
                    }
                    break;
                default:
                    break;
                }

                analyzedArgs ~= analyzedArg;
                continue;
            }

            string argTypeStr = to!string(argType.baseType).toLower();
            string paramTypeStr = expectedParamTypeStr.toLower();

            if (!this.typeChecker.areTypesCompatible(argTypeStr, paramTypeStr))
            {
                throw new Exception(format(
                        "O argumento %d da função '%s' espera tipo '%s', mas recebeu '%s'.",
                        i + 1, funcName, expectedParamTypeStr, argTypeStr
                ));
            }

            if (this.typeChecker.areTypesCompatible(argTypeStr, paramTypeStr) &&
                argType.baseType != expectedParamType)
            {
                analyzedArg.type.baseType = expectedParamType;
            }

            analyzedArgs ~= analyzedArg;
        }

        node.args = analyzedArgs;

        return node;
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
            throw new Exception(format(`A função '%s' já está definida.`, id));
        }

        this.pushScope(); // Escopo para a função

        FunctionArgs args;

        foreach (FunctionArg arg; node.args)
        {
            string _id = arg.id.value.get!string;
            if (_id in this.currentScope())
            {
                throw new Exception(format(
                        `Parâmetro '%s' já foi definido.`, _id
                ));
            }

            // string baseType = to!string(arg.type.baseType).toLower();
            // writeln("FN BASE TYPE: ", baseType);
            // writeln("C: ", baseType);
            string baseType = this.typeChecker.getTypeStringFromNative(arg.type.baseType);
            arg.type.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));
            // arg.type.baseType = cast(TypesNative) this.typeChecker.mapToDType(
            //     baseType);
            // writeln("ARG BASE TYPE: ", arg.type.baseType);
            this.addSymbol(_id, SymbolInfo(_id, arg.type, true, false, arg.id.loc));
            args ~= arg;
        }

        FTypeInfo returnType = node.type;
        string t2 = to!string(returnType.baseType).toLower();

        FunctionParam[] params;
        foreach (FunctionArg arg; args)
        {
            // writeln("PARAMS ", FunctionParam(arg.id.value.get!string, arg.type, to!string(
            //         arg.type.baseType)));
            params ~= FunctionParam(arg.id.value.get!string, arg.type, to!string(arg.type.baseType));
        }

        Function func = Function(id, returnType, params, false, to!string(returnType.baseType));
        this.availableFunctions[id] = func;

        Stmt[] analyzedBlock;
        bool hasReturn = false;

        foreach (Stmt stmt; node.body)
        {
            Stmt analyzedStmt = this.analyzeNode(stmt);
            analyzedBlock ~= analyzedStmt;

            if (stmt.kind == NodeType.ReturnStatement)
            {
                hasReturn = true;
                ReturnStatement returnStmt = cast(ReturnStatement) analyzedStmt;
                if (returnStmt.value.hasValue())
                {
                    string t1 = to!string(returnStmt.type.baseType).toLower();
                    if (!this.typeChecker.areTypesCompatible(t1, t2) && t2 != "void")
                    {
                        throw new Exception(format(
                                "A função '%s' está retornando '%s' ao invés de '%s' como esperado.",
                                id, t1, t2
                        ));
                    }
                }
            }
        }

        if (t2 != "void" && !hasReturn)
        {
            throw new Exception(format(
                    "A função esperava um retorno '%s', mas não foi encontrado qualquer tipo de retorno nela.", t2),
            );
        }

        node.args = args;
        // writeln("T: ", node.args[0].type.baseType);
        node.body = analyzedBlock;
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
            throw new Exception(
                format(
                    `O identificador '%s' não existe no escopo`, id));
        }

        if (!(id in this.identifiersUsed))
        {
            this.identifiersUsed[id] = true;
        }
        node.type = symbol.type;

        return node;
    }

    Stmt analyzeBinaryExpr(BinaryExpr node)
    {
        Stmt left = this.analyzeNode(node.left);
        Stmt right = this.analyzeNode(node.right);

        // Operações bitwise mantêm o tipo mais abrangente
        if (node.op == "&" || node.op == "|" || node.op == "^" ||
            node.op == "<<" || node.op == ">>")
        {
            if (left.type.baseType != TypesNative.LONG)
            {
                left.type.baseType = TypesNative.LONG;
            }
            if (right.type.baseType != TypesNative.LONG)
            {
                right.type.baseType = TypesNative.LONG;
            }
        }

        if (node.op == "+" && (left.type.baseType == TypesNative.STRING || right.type.baseType == TypesNative
                .STRING))
        {
            // Concat
            node.op = "~";
        }

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
            throw new Exception(
                format(
                    `A variavel '%s' já está definida no escopo em %d:%d`, id, cast(int) node.id.loc.line, cast(
                    int) node.id.loc.start));
        }

        if (!node.value.hasValue)
        {
            throw new Exception(format("Erro: o valor do nó '%s' é nulo.", to!string(node.kind)));
        }

        Stmt analyzedValue = this.analyzeNode(node.value.get!Stmt);
        node.value = analyzedValue;

        string baseType = this.typeChecker.getTypeStringFromNative(analyzedValue.type.baseType);
        node.type.baseType = stringToTypesNative(this.typeChecker.mapToDType(baseType));
        node.type.className = analyzedValue.type.className;
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
