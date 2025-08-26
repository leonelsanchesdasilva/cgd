module backend.codegen.core;

import std.stdio;
import std.array;
import std.format;
import std.string;
import std.conv;
import std.algorithm;

enum TypeKind
{
    Void,
    Bool,
    Int8,
    Int16,
    Int32,
    Int64,
    UInt8,
    UInt16,
    UInt32,
    UInt64,
    Float32,
    Float64,
    String,
    Array,
    Pointer,
    Struct,
    Function,
    Custom
}

// Estrutura para representar tipos
struct Type
{
    TypeKind kind;
    string name;
    Type* elementType; // Para arrays, ponteiros
    Type*[] paramTypes; // Para funções
    Type* returnType; // Para funções

    string toString() const
    {
        final switch (kind)
        {
        case TypeKind.Void:
            return "void";
        case TypeKind.Bool:
            return "bool";
        case TypeKind.Int8:
            return "byte";
        case TypeKind.Int16:
            return "short";
        case TypeKind.Int32:
            return "int";
        case TypeKind.Int64:
            return "long";
        case TypeKind.UInt8:
            return "ubyte";
        case TypeKind.UInt16:
            return "ushort";
        case TypeKind.UInt32:
            return "uint";
        case TypeKind.UInt64:
            return "ulong";
        case TypeKind.Float32:
            return "float";
        case TypeKind.Float64:
            return "double";
        case TypeKind.String:
            return "string";
        case TypeKind.Array:
            return elementType ? elementType.toString() ~ "[]" : "void[]";
        case TypeKind.Pointer:
            return elementType ? elementType.toString() ~ "*" : "void*";
        case TypeKind.Struct:
        case TypeKind.Custom:
            return name;
        case TypeKind.Function:
            string params;
            if (paramTypes.length > 0)
            {
                string[] paramStrings;
                foreach (t; paramTypes)
                {
                    paramStrings ~= t.toString();
                }
                params = paramStrings.join(", ");
            }
            string ret = returnType ? returnType.toString() : "void";
            return format!"%s function(%s)"(ret, params);
        }
    }
}

// Representa uma expressão no IR
abstract class Expression
{
    Type type;

    this(Type type)
    {
        this.type = type;
    }

    abstract string generateD();
}

class LiteralExpression : Expression
{
    string value;

    this(Type type, string value)
    {
        super(type);
        string processedValue = value;

        if (type.kind == TypeKind.Int64 || type.kind == TypeKind.Int32)
        {
            string temp = "";
            for (long i = 0; i < value.length; i++)
            {
                temp ~= value[i];
                long remainingChars = value.length - i - 1;
                if (remainingChars > 0 && remainingChars % 3 == 0)
                    temp ~= "_";
            }
            processedValue = temp;
        }

        this.value = processedValue;
    }

    override string generateD()
    {
        if (type.kind == TypeKind.String)
        {
            return `"` ~ value ~ `"`;
        }
        return value;
    }
}

class VariableExpression : Expression
{
    string name;

    this(Type type, string name)
    {
        super(type);
        this.name = name;
    }

    override string generateD()
    {
        return name;
    }
}

class BinaryExpression : Expression
{
    Expression left, right;
    string operator;

    this(Type type, Expression left, string operator, Expression right)
    {
        super(type);
        this.left = left;
        this.operator = operator;
        this.right = right;
    }

    override string generateD()
    {
        return format!"(%s %s %s)"(left.generateD(), operator, right.generateD());
    }
}

class CallExpression : Expression
{
    string functionName;
    Expression[] arguments;

    this(Type type, string functionName, Expression[] arguments)
    {
        super(type);
        this.functionName = functionName;
        this.arguments = arguments;
    }

    override string generateD()
    {
        string[] args;
        foreach (arg; arguments)
        {
            args ~= arg.generateD();
        }
        return format!"%s(%s)"(functionName, args.join(", "));
    }
}

// Representa uma declaração/statement
abstract class Statement
{
    abstract string generateD(int indentLevel = 0);

    protected string indent(int level)
    {
        return "    ".replicate(level);
    }
}

class VariableDeclarationCore : Statement
{
    Type type;
    string name;
    Expression initializer;

    this(Type type, string name, Expression initializer = null)
    {
        this.type = type;
        this.name = name;
        this.initializer = initializer;
    }

    override string generateD(int indentLevel = 0)
    {
        string result = indent(indentLevel) ~ type.toString() ~ " " ~ name;
        if (initializer)
        {
            result ~= " = " ~ initializer.generateD();
        }
        return result ~ ";";
    }
}

class AssignmentStatement : Statement
{
    string variableName;
    Expression value;

    this(string variableName, Expression value)
    {
        this.variableName = variableName;
        this.value = value;
    }

    override string generateD(int indentLevel = 0)
    {
        return indent(indentLevel) ~ variableName ~ " = " ~ value.generateD() ~ ";";
    }
}

class ExpressionStatement : Statement
{
    Expression expression;

    this(Expression expression)
    {
        this.expression = expression;
    }

    override string generateD(int indentLevel = 0)
    {
        return indent(indentLevel) ~ expression.generateD() ~ ";";
    }
}

class BlockStatement : Statement
{
    Statement[] statements;

    this(Statement[] statements...)
    {
        this.statements = statements.dup;
    }

    override string generateD(int indentLevel = 0)
    {
        auto result = appender!string();
        result.put(indent(indentLevel) ~ "{\n");

        foreach (stmt; statements)
        {
            result.put(stmt.generateD(indentLevel + 1) ~ "\n");
        }

        result.put(indent(indentLevel) ~ "}");
        return result.data;
    }
}

class IfStatementCore : Statement
{
    Expression condition;
    Statement thenStmt;
    Statement elseStmt;
    Statement elseIf;

    this(Expression condition, Statement thenStmt, Statement elseStmt = null, Statement elseIf = null)
    {
        this.condition = condition;
        this.thenStmt = thenStmt;
        this.elseStmt = elseStmt;
        this.elseIf = elseIf;
    }

    override string generateD(int indentLevel = 0)
    {
        string result = indent(indentLevel) ~ "if (" ~ condition.generateD() ~ ")\n";
        result ~= thenStmt.generateD(indentLevel) ~ "\n";

        if (elseStmt)
        {
            result ~= elseStmt.generateD(indentLevel);
        }

        if (elseIf)
        {
            result ~= indent(indentLevel) ~ "else ";
            result ~= elseIf.generateD(indentLevel);
        }

        return result;
    }
}

class ElseStatementCore : Statement
{
    Expression condition;
    Statement thenStmt;

    this(Statement thenStmt)
    {
        this.thenStmt = thenStmt;
    }

    override string generateD(int indentLevel = 0)
    {
        string result = thenStmt.generateD(indentLevel) ~ "\n";
        return result;
    }
}

class WhileStatementCore : Statement
{
    Expression condition;
    Statement body;

    this(Expression condition, Statement body)
    {
        this.condition = condition;
        this.body = body;
    }

    override string generateD(int indentLevel = 0)
    {
        string result = indent(indentLevel) ~ "while (" ~ condition.generateD() ~ ")\n";
        result ~= body.generateD(indentLevel);
        return result;
    }
}

class ForStatementCore : Statement
{
    Statement initialization;
    Expression condition;
    Statement increment;
    Statement body;

    this(Statement initialization, Expression condition, Statement increment, Statement body)
    {
        this.initialization = initialization;
        this.condition = condition;
        this.increment = increment;
        this.body = body;
    }

    override string generateD(int indentLevel = 0)
    {
        auto result = appender!string();
        result.put(indent(indentLevel) ~ "for (");

        if (initialization)
        {
            string initStr = initialization.generateD(0);
            if (initStr.endsWith(";"))
            {
                initStr = initStr[0 .. $ - 1];
            }
            result.put(initStr);
        }
        result.put("; ");

        if (condition)
        {
            result.put(condition.generateD());
        }
        result.put("; ");

        if (increment)
        {
            string incStr = increment.generateD(0);
            if (incStr.endsWith(";"))
            {
                incStr = incStr[0 .. $ - 1];
            }
            result.put(incStr);
        }

        result.put(")\n");
        result.put(body.generateD(indentLevel));
        return result.data;
    }
}

class ReturnStatementCore : Statement
{
    Expression value;

    this(Expression value = null)
    {
        this.value = value;
    }

    override string generateD(int indentLevel = 0)
    {
        string result = indent(indentLevel) ~ "return";
        if (value)
        {
            result ~= " " ~ value.generateD();
        }
        return result ~ ";";
    }
}

struct Parameter
{
    Type type;
    string name;

    string toString() const
    {
        return type.toString() ~ " " ~ name;
    }
}

// Representa uma função
class Function
{
    Type returnType;
    string name;
    Parameter[] parameters;
    Statement[] body;

    this(Type returnType, string name, Parameter[] parameters = [])
    {
        this.returnType = returnType;
        this.name = name;
        this.parameters = parameters;
    }

    void addStatement(Statement stmt)
    {
        body ~= stmt;
    }

    string generateD()
    {
        auto result = appender!string();

        // Assinatura da função
        result.put(returnType.toString() ~ " " ~ name ~ "(");

        string[] paramStrings;
        foreach (p; parameters)
        {
            paramStrings ~= p.toString();
        }
        result.put(paramStrings.join(", "));
        result.put(") {\n");

        // Corpo da função
        foreach (stmt; body)
        {
            result.put(stmt.generateD(1) ~ "\n");
        }

        result.put("}\n");
        return result.data;
    }
}

// Representa um módulo/arquivo D
class Module
{
    string name;
    bool[string] imports;
    Function[] functions;
    string[] stdFunctions;
    Statement[] globalStatements;

    this(string name)
    {
        this.name = name;
    }

    void addImport(string importName)
    {
        if (importName !in imports)
            imports[importName] = true;
    }

    void addFunction(Function func)
    {
        functions ~= func;
    }

    void addStdFunction(string func)
    {
        stdFunctions ~= func;
    }

    void addGlobalStatement(Statement stmt)
    {
        globalStatements ~= stmt;
    }

    string generateD()
    {
        auto result = appender!string();

        // Nome do módulo
        if (name.length > 0)
        {
            result.put("module " ~ name ~ ";\n\n");
        }

        // Imports
        foreach (imp, value; imports)
        {
            result.put("import " ~ imp ~ ";\n");
        }
        if (imports.length > 0)
        {
            result.put("\n");
        }

        // Funções std
        foreach (fn; stdFunctions)
        {
            result.put(fn ~ "\n");
        }
        if (stdFunctions.length > 0)
        {
            result.put("\n");
        }

        // Statements globais
        foreach (stmt; globalStatements)
        {
            result.put(stmt.generateD() ~ "\n");
        }
        if (globalStatements.length > 0)
        {
            result.put("\n");
        }

        // Funções
        foreach (func; functions)
        {
            result.put(func.generateD() ~ "\n");
        }

        return result.data;
    }
}

class CodeGenerator
{
    Module currentModule;

    this(string moduleName)
    {
        currentModule = new Module(moduleName);
    }

    // Helpers para criar tipos comuns
    static Type makeVoidType()
    {
        return Type(TypeKind.Void);
    }

    static Type makeFloatType()
    {
        return Type(TypeKind.Float64);
    }

    static Type makeIntType()
    {
        return Type(TypeKind.Int64);
    }

    static Type makeBoolType()
    {
        return Type(TypeKind.Bool);
    }

    static Type makeStringType()
    {
        return Type(TypeKind.String);
    }

    static Type makeArrayType(Type elementType)
    {
        Type arrayType = Type(TypeKind.Array);
        arrayType.elementType = new Type(elementType.kind, elementType.name); // Correção aqui
        return arrayType;
    }

    // Helpers para criar expressões
    static Expression makeLiteral(Type type, string value)
    {
        return new LiteralExpression(type, value);
    }

    static Expression makeVariable(Type type, string name)
    {
        return new VariableExpression(type, name);
    }

    static Expression makeBinary(Type type, Expression left, string op, Expression right)
    {
        return new BinaryExpression(type, left, op, right);
    }

    static Expression makeCall(Type returnType, string funcName, Expression[] args...)
    {
        return new CallExpression(returnType, funcName, args.dup);
    }

    // Gera o código D final
    string generate()
    {
        return currentModule.generateD();
    }

    // Salva o código em um arquivo
    void saveToFile(string filename)
    {
        import std.file;

        write(filename, generate());
    }
}

class StructDefinition
{
    string name;
    Field[] fields;
    Method[] methods;
    bool isClass; // true para class, false para struct

    this(string name, bool isClass = false)
    {
        this.name = name;
        this.isClass = isClass;
    }

    void addField(Type type, string name, string defaultValue = "")
    {
        fields ~= Field(type, name, defaultValue);
    }

    void addMethod(Method method)
    {
        methods ~= method;
    }

    string generateD()
    {
        auto result = appender!string();

        result.put((isClass ? "class " : "struct ") ~ name ~ " {\n");

        // Campos
        foreach (field; fields)
        {
            result.put("    " ~ field.toString() ~ "\n");
        }

        if (fields.length > 0 && methods.length > 0)
        {
            result.put("\n");
        }

        // Métodos
        foreach (method; methods)
        {
            auto methodCode = method.generateD();
            // Indenta o código do método
            auto lines = methodCode.split("\n");
            foreach (line; lines)
            {
                if (line.strip().length > 0)
                {
                    result.put("    " ~ line ~ "\n");
                }
            }
            if (methods.length > 1)
            {
                result.put("\n");
            }
        }

        result.put("}\n");
        return result.data;
    }
}

struct Field
{
    Type type;
    string name;
    string defaultValue;

    string toString() const
    {
        string result = type.toString() ~ " " ~ name;
        if (defaultValue.length > 0)
        {
            result ~= " = " ~ defaultValue;
        }
        return result ~ ";";
    }
}

// Classe para métodos (similar a Function mas para dentro de structs/classes)
class Method : Function
{
    bool isStatic;
    string visibility; // public, private, protected

    this(Type returnType, string name, Parameter[] parameters = [], bool isStatic = false, string visibility = "public")
    {
        super(returnType, name, parameters);
        this.isStatic = isStatic;
        this.visibility = visibility;
    }

    override string generateD()
    {
        auto result = appender!string();

        // Visibilidade
        if (visibility != "public")
        {
            result.put(visibility ~ " ");
        }

        // Static
        if (isStatic)
        {
            result.put("static ");
        }

        // Assinatura
        result.put(returnType.toString() ~ " " ~ name ~ "(");
        result.put(parameters.map!(p => p.toString()).join(", "));
        result.put(") {\n");

        // Corpo
        foreach (stmt; body)
        {
            result.put(stmt.generateD(1) ~ "\n");
        }

        result.put("}");
        return result.data;
    }
}

// Suporte para enums
class EnumDefinition
{
    string name;
    Type baseType;
    EnumMember[] members;

    struct EnumMember
    {
        string name;
        string value;

        string toString() const
        {
            return value.length > 0 ? name ~ " = " ~ value : name;
        }
    }

    this(string name, Type baseType = Type(TypeKind.Int32))
    {
        this.name = name;
        this.baseType = baseType;
    }

    void addMember(string name, string value = "")
    {
        members ~= EnumMember(name, value);
    }

    string generateD()
    {
        auto result = appender!string();

        result.put("enum " ~ name);
        if (baseType.kind != TypeKind.Int32)
        {
            result.put(" : " ~ baseType.toString());
        }
        result.put(" {\n");

        foreach (i, member; members)
        {
            result.put("    " ~ member.toString());
            if (i < cast(int) members.length - 1)
            {
                result.put(",");
            }
            result.put("\n");
        }

        result.put("}\n");
        return result.data;
    }
}

// Expressão para acesso a membros (obj.field)
class MemberAccessExpression : Expression
{
    Expression object;
    string memberName;

    this(Type type, Expression object, string memberName)
    {
        super(type);
        this.object = object;
        this.memberName = memberName;
    }

    override string generateD()
    {
        string obj = object.generateD();
        return (obj == "isto" ? "this" : obj) ~ "." ~ memberName;
    }
}

// Expressão para indexação de arrays (arr[index])
class IndexExpression : Expression
{
    Expression array;
    Expression index;

    this(Type type, Expression array, Expression index)
    {
        super(type);
        this.array = array;
        this.index = index;
    }

    override string generateD()
    {
        return array.generateD() ~ "[" ~ index.generateD() ~ "]";
    }
}

// Expressão para casting (cast(Type)expr)
class CastExpression : Expression
{
    Expression expression;

    this(Type targetType, Expression expression)
    {
        super(targetType);
        this.expression = expression;
    }

    override string generateD()
    {
        return "cast(" ~ type.toString() ~ ")" ~ expression.generateD();
    }
}

// Expressão para criação de arrays ([1, 2, 3])
class ArrayLiteralExpression : Expression
{
    Expression[] elements;

    this(Type type, Expression[] elements)
    {
        super(type);
        this.elements = elements;
    }

    override string generateD()
    {
        auto elementsStr = elements.map!(e => e.generateD()).join(", ");
        return "[" ~ elementsStr ~ "]";
    }
}

// Statement for-each
class ForeachStatement : Statement
{
    string variableName;
    Type variableType;
    Expression iterable;
    Statement body;

    this(Type variableType, string variableName, Expression iterable, Statement body)
    {
        this.variableType = variableType;
        this.variableName = variableName;
        this.iterable = iterable;
        this.body = body;
    }

    override string generateD(int indentLevel = 0)
    {
        auto result = indent(indentLevel);
        result ~= "foreach (";
        if (variableType.kind != TypeKind.Void)
        {
            result ~= variableType.toString() ~ " ";
        }
        result ~= variableName ~ "; " ~ iterable.generateD() ~ ")\n";
        result ~= body.generateD(indentLevel);
        return result;
    }
}

class ExtendedModule : Module
{
    StructDefinition[] structs;
    EnumDefinition[] enums;

    this(string name)
    {
        super(name);
    }

    void addStruct(StructDefinition struct_)
    {
        structs ~= struct_;
    }

    void addEnum(EnumDefinition enum_)
    {
        enums ~= enum_;
    }

    override string generateD()
    {
        auto result = appender!string();

        // Nome do módulo
        if (name.length > 0)
        {
            result.put("module " ~ name ~ ";\n\n");
        }

        // Imports
        foreach (imp, value; imports)
        {
            result.put("import " ~ imp ~ ";\n");
        }
        if (imports.length > 0)
        {
            result.put("\n");
        }

        // Funções std
        foreach (fn; stdFunctions)
        {
            result.put(fn ~ "\n");
        }
        if (stdFunctions.length > 0)
        {
            result.put("\n");
        }

        // Enums
        foreach (enum_; enums)
        {
            result.put(enum_.generateD() ~ "\n");
        }

        // Structs
        foreach (struct_; structs)
        {
            result.put(struct_.generateD() ~ "\n");
        }

        // Statements globais
        foreach (stmt; globalStatements)
        {
            result.put(stmt.generateD() ~ "\n");
        }
        if (globalStatements.length > 0)
        {
            result.put("\n");
        }

        // Funções
        foreach (func; functions)
        {
            result.put(func.generateD() ~ "\n");
        }

        return result.data;
    }
}

class ExtendedCodeGenerator : CodeGenerator
{
    ExtendedModule extendedModule;

    this(string moduleName)
    {
        super(moduleName);
        extendedModule = new ExtendedModule(moduleName);
        currentModule = extendedModule;
    }

    void addStruct(StructDefinition struct_)
    {
        extendedModule.addStruct(struct_);
    }

    void addEnum(EnumDefinition enum_)
    {
        extendedModule.addEnum(enum_);
    }
}

class UnaryExpressionCore : Expression
{
    string operator;
    Expression operand;

    this(Type type, string operator, Expression operand)
    {
        super(type);
        this.operator = operator;
        this.operand = operand;
    }

    override string generateD()
    {
        return format!"%s%s"(operator, operand.generateD());
    }
}

class DereferenceExpressionCore : Expression
{
    Expression operand;

    this(Type type, Expression operand)
    {
        super(type);
        this.operand = operand;
    }

    override string generateD()
    {
        return format!"*%s"(operand.generateD());
    }
}

class AddressOfExpressionCore : Expression
{
    Expression operand;

    this(Type type, Expression operand)
    {
        super(type);
        this.operand = operand;
    }

    override string generateD()
    {
        return format!"&%s"(operand.generateD());
    }
}

class BreakStatementCore : Statement
{
    this()
    {
        // Break simples
    }

    override string generateD(int indentLevel = 0)
    {
        return indent(indentLevel) ~ "break;";
    }
}

// Statement para continue (útil para loops)
class ContinueStatementCore : Statement
{
    this()
    {
        // Continue simples
    }

    override string generateD(int indentLevel = 0)
    {
        return indent(indentLevel) ~ "continue;";
    }
}

// Switch statement aprimorado
class SwitchStatementCore : Statement
{
    Expression expression;
    CaseStatementCore[] cases;
    Statement[] defaultCase;

    this(Expression expression)
    {
        this.expression = expression;
    }

    void addCase(Expression[] values, Statement[] statements)
    {
        cases ~= new CaseStatementCore(values, statements);
    }

    void setDefault(Statement[] defaultCase)
    {
        this.defaultCase = defaultCase;
    }

    override string generateD(int indentLevel = 0)
    {
        auto result = appender!string();
        result.put(indent(indentLevel) ~ "switch (" ~ expression.generateD() ~ ") {\n");

        foreach (case_; cases)
        {
            result.put(case_.generateD(indentLevel + 1));
        }

        if (defaultCase)
        {
            result.put(indent(indentLevel + 1) ~ "default:\n");
            foreach (case_; defaultCase)
            {
                result.put(case_.generateD(indentLevel + 2) ~ "\n");
            }
        }

        result.put(indent(indentLevel) ~ "}");
        return result.data;
    }
}

// Case statement individual
class CaseStatementCore : Statement
{
    Expression[] values;
    Statement[] statements;

    this(Expression[] values, Statement[] statements)
    {
        this.values = values;
        this.statements = statements;
    }

    override string generateD(int indentLevel = 0)
    {
        auto result = appender!string();

        // Gera os labels de caso
        foreach (value; values)
        {
            result.put(indent(indentLevel) ~ "case " ~ value.generateD() ~ ":\n");
        }

        // Gera o corpo do caso
        foreach (stmt; statements)
        {
            result.put(stmt.generateD(indentLevel + 1) ~ "\n");
        }

        return result.data;
    }
}

// Expressão para chamadas de método em objetos
class MethodCallExpression : Expression
{
    Expression object;
    string methodName;
    Expression[] arguments;

    this(Type type, Expression object, string methodName, Expression[] arguments)
    {
        super(type);
        this.object = object;
        this.methodName = methodName;
        this.arguments = arguments;
    }

    override string generateD()
    {
        string[] args;
        foreach (arg; arguments)
        {
            args ~= arg.generateD();
        }
        string obj = object.generateD();
        return format!"%s.%s(%s)"(obj == "isto" ? "this" : obj, methodName, args.join(", "));
    }
}

// Expressão ternária (condição ? valor1 : valor2)
class TernaryExpression : Expression
{
    Expression condition;
    Expression trueValue;
    Expression falseValue;

    this(Type type, Expression condition, Expression trueValue, Expression falseValue)
    {
        super(type);
        this.condition = condition;
        this.trueValue = trueValue;
        this.falseValue = falseValue;
    }

    override string generateD()
    {
        return format!"(%s ? %s : %s)"(
            condition.generateD(),
            trueValue.generateD(),
            falseValue.generateD()
        );
    }
}

// Expressão para new (criação de objetos)
class NewExpression : Expression
{
    Expression[] arguments;

    this(Type type, Expression[] arguments = [])
    {
        super(type);
        this.arguments = arguments;
    }

    override string generateD()
    {
        if (arguments.length > 0)
        {
            string[] args;
            foreach (arg; arguments)
            {
                args ~= arg.generateD();
            }
            return format!"new %s(%s)"(type.toString(), args.join(", "));
        }
        return format!"new %s()"(type.toString());
    }
}

// Statement para try-catch (para futuras extensões)
class TryStatementCore : Statement
{
    Statement tryBlock;
    CatchClause[] catchClauses;
    Statement finallyBlock;

    struct CatchClause
    {
        Type exceptionType;
        string variableName;
        Statement handler;
    }

    this(Statement tryBlock)
    {
        this.tryBlock = tryBlock;
    }

    void addCatch(Type exceptionType, string variableName, Statement handler)
    {
        catchClauses ~= CatchClause(exceptionType, variableName, handler);
    }

    void setFinally(Statement finallyBlock)
    {
        this.finallyBlock = finallyBlock;
    }

    override string generateD(int indentLevel = 0)
    {
        auto result = appender!string();

        result.put(indent(indentLevel) ~ "try\n");
        result.put(tryBlock.generateD(indentLevel) ~ "\n");

        foreach (catch_; catchClauses)
        {
            result.put(indent(indentLevel) ~ "catch (");
            result.put(catch_.exceptionType.toString() ~ " " ~ catch_.variableName);
            result.put(")\n");
            result.put(catch_.handler.generateD(indentLevel) ~ "\n");
        }

        if (finallyBlock)
        {
            result.put(indent(indentLevel) ~ "finally\n");
            result.put(finallyBlock.generateD(indentLevel));
        }

        return result.data;
    }
}
