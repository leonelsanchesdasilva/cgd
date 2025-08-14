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

        // Vamos adicionar isso aqui temporariamente
        StdLibModuleBuilder mod = new StdLibModuleBuilder("io");
        importedModules["io"] = true;

        auto fn1 = new FunctionBuilder("escreva", mod)
            .returns(createTypeInfo(TypesNative.NULL))
            .variadic()
            .customTargetType("void")
            .libraryName("io")
            .generateDExternComplete();

        auto fn2 = new FunctionBuilder("escrevaln", mod)
            .returns(createTypeInfo(TypesNative.NULL))
            .variadic()
            .customTargetType("void")
            .libraryName("io")
            .generateDExternComplete();

        auto escreva = fn1.done();
        auto escrevaln = fn2.done();

        availableStdFunctions["escreva"] = escreva.getFunction("escreva");
        availableStdFunctions["escrevaln"] = escrevaln.getFunction("escrevaln");
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
        case NodeType.AssignmentDeclaration:
            analyzedNode = this.analyzeAssignmentDeclaration(cast(AssignmentDeclaration) node);
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
            throw new Exception(format("Nó desconhecido '%s'.", to!string(node.kind)));
        }
        return analyzedNode;
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

    WhileStatement analyzeWhileStatement(WhileStatement node)
    {
        // this(Stmt cond, Stmt[] body, Loc loc)
        node.cond = this.analyzeNode(node.cond);

        for (long i; i < node.body.length; i++)
        {
            node.body[i] = this.analyzeNode(node.body[i]);
        }

        return node;
    }

    ForStatement analyzeForStatement(ForStatement node)
    {
        // this(Stmt _init, Stmt cond, Stmt expr, Stmt[] body, Loc loc)
        node._init = this.analyzeNode(node._init);
        node.cond = this.analyzeNode(node.cond);
        node.expr = this.analyzeNode(node.expr);

        for (long i; i < node.body.length; i++)
        {
            node.body[i] = this.analyzeNode(node.body[i]);
        }

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

        // Define o tipo de retorno da chamada
        node.type = returnType;

        // Marca a função como usada
        if (!(funcName in this.identifiersUsed))
        {
            this.identifiersUsed[funcName] = true;
        }

        // Analisa e valida cada argumento
        Stmt[] analyzedArgs;
        analyzedArgs.reserve(node.args.length);

        for (size_t i = 0; i < node.args.length; i++)
        {
            // Analisa o argumento
            Stmt analyzedArg = this.analyzeNode(node.args[i]);

            // Se é função variadic e não temos mais parâmetros definidos, aceita qualquer tipo
            if (i >= expectedArgCount && isVariadic)
            {
                analyzedArgs ~= analyzedArg;
                continue;
            }

            // Verifica se temos parâmetro definido para este argumento
            if (i >= expectedArgCount)
            {
                throw new Exception(format(
                        "Muitos argumentos para a função '%s'. Esperado %d, recebido %d.",
                        funcName, expectedArgCount, node.args.length
                ));
            }

            // Obtém o tipo esperado baseado no tipo de função
            TypesNative expectedParamType;
            string expectedParamTypeStr;

            if (isStdFunction)
            {
                // Para std functions, params é string[]
                expectedParamTypeStr = stdExpectedParams[i];
                expectedParamType = cast(TypesNative) this.typeChecker.mapToDType(
                    expectedParamTypeStr);
            }
            else
            {
                // Para user functions, params é FunctionParam[]
                expectedParamType = userExpectedParams[i].type.baseType;
                expectedParamTypeStr = userExpectedParams[i].targetType;
            }

            FTypeInfo argType = analyzedArg.type;

            // Conversão especial: qualquer tipo para string
            if (argType.baseType != TypesNative.STRING && expectedParamType == TypesNative.STRING)
            {
                analyzedArg.type.baseType = TypesNative.STRING;

                // Converte o valor para string baseado no tipo original
                switch (argType.baseType)
                {
                case TypesNative.INT:
                    if (analyzedArg.value.hasValue())
                    {
                        analyzedArg.value = to!string(analyzedArg.value.get!int);
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

            // Verifica compatibilidade de tipos
            string argTypeStr = to!string(argType.baseType).toLower();
            string paramTypeStr = expectedParamTypeStr.toLower();

            if (!this.typeChecker.areTypesCompatible(argTypeStr, paramTypeStr))
            {
                throw new Exception(format(
                        "O argumento %d da função '%s' espera tipo '%s', mas recebeu '%s'.",
                        i + 1, funcName, expectedParamTypeStr, argTypeStr
                ));
            }

            // Se os tipos são compatíveis mas diferentes, faz a conversão
            if (this.typeChecker.areTypesCompatible(argTypeStr, paramTypeStr) &&
                argType.baseType != expectedParamType)
            {
                analyzedArg.type.baseType = expectedParamType;

                // Aqui você poderia adicionar conversão de valores se necessário
                // analyzedArg.llvmType = this.typeChecker.mapToLLVMType(paramTypeStr);
            }

            analyzedArgs ~= analyzedArg;
        }

        // Atualiza os argumentos analisados
        node.args = analyzedArgs;

        return node;
    }

    // Também adicione este case ao switch em analyzeNode():

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

            string baseType = to!string(arg.type.baseType).toLower();
            // writeln("FN BASE TYPE: ", baseType);
            arg.type.baseType = cast(TypesNative) this.typeChecker.mapToDType(
                baseType);
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

        string baseType = to!string(analyzedValue.type.baseType).toLower();
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
