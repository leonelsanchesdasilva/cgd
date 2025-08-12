module middle.type_checker;

import std.string;
import std.conv;
import std.exception;
import std.algorithm;
import frontend.lexer.token;
import frontend.parser.ast;
import frontend.values;
import middle.semantic;

class TypeChecker
{
    private string[string] typeMap;
    private int[string] typeHierarchy;
    private Semantic semanticAnalyzer;

    this(Semantic semanticAnalyzer = null)
    {
        this.reporter = reporter;
        this.semanticAnalyzer = semanticAnalyzer;

        typeHierarchy = [
            "i1": 1,
            "bool": 1,
            "int": 2,
            "i32": 2,
            "binary": 2,
            "i64": 3,
            "i128": 3,
            "long": 3,
            "float": 4,
            "double": 5
        ];

        initializeTypeMap();
    }

    private void initializeTypeMap()
    {
        typeMap["int"] = "i32";
        typeMap["i32"] = "i32";
        typeMap["i64"] = "i64";
        typeMap["long"] = "i128";
        typeMap["i128"] = "i128";
        typeMap["float"] = "double";
        typeMap["double"] = "double";
        typeMap["string"] = "string";
        typeMap["bool"] = "bool";
        typeMap["binary"] = "i32";
        typeMap["null"] = "ptr";
        typeMap["ptr"] = "ptr";
        typeMap["id"] = "void";
        typeMap["void*"] = "void*";
        typeMap["void"] = "void";
    }

    public bool isValidType(string type)
    {
        return (type in typeMap) !is null;
    }

    public string mapToDType(string sourceType)
    {
        if (sourceType in typeMap)
        {
            return typeMap[sourceType];
        }

        if (semanticAnalyzer !is null)
        {
            auto structInfo = semanticAnalyzer.getStruct(sourceType);
            if (structInfo !is null)
            {
                return "%" ~ structInfo.name;
            }
        }

        throw new Exception("Unsupported type mapping for " ~ sourceType);
    }

    public string getTypeString(string type)
    {
        switch (type)
        {
        case "i1":
            return "i1";
        case "i32":
            return "i32";
        case "i64":
            return "i64";
        case "double":
            return "double";
        case "i128":
            return "long";
        case "string":
            return "i8*";
        case "void":
            return "void";
        case "ptr":
            return "ptr";
        default:
            return "i8*";
        }
    }

    public bool isNumericType(string type)
    {
        string[] numericTypes = [
            "int", "i32", "i64", "long", "float", "double", "binary"
        ];
        return numericTypes.canFind(type);
    }

    public bool isFloat(string left, string right)
    {
        return left == "float" || right == "float" ||
            left == "double" || right == "double";
    }

    // Gets the promoted type between two numeric types
    private TypeInfo promoteTypes(string leftType, string rightType)
    {
        int leftRank = typeHierarchy.get(leftType, 0);
        int rightRank = typeHierarchy.get(rightType, 0);

        if (leftRank >= rightRank)
        {
            return createTypeInfo(leftType);
        }
        return createTypeInfo(rightType);
    }

    public bool areTypesCompatible(string sourceType, string targetType)
    {
        if (sourceType == targetType)
            return true;

        if (isNumericType(sourceType) && isNumericType(targetType))
        {
            return true;
        }

        string[][string] compatibilityMap = [
            "int": ["float", "double", "i64", "long", "bool", "i128"],
            "i32": ["float", "double", "i64", "long", "bool"],
            "float": ["double", "int", "i32", "i64", "long", "bool"],
            "double": ["int", "i32", "float", "i64", "long", "bool"],
            "binary": ["int", "i32", "i64", "long"],
            "i64": ["float", "double", "bool"],
            "long": ["float", "double", "bool"],
            "string": ["const char", "char", "binary"],
            "bool": ["int", "i32", "long", "float", "double", "string", "i64"]
        ];

        if (sourceType in compatibilityMap &&
            compatibilityMap[sourceType].canFind(targetType))
        {
            return true;
        }

        if (sourceType == "id" || targetType == "id")
            return true;

        return false;
    }

    public TypeInfo checkBinaryExprTypes(Expr left, Expr right, string operator)
    {
        string leftType = left.type.baseType;
        string rightType = right.type.baseType;

        if (leftType != rightType && !areTypesCompatible(leftType, rightType))
        {
            throw new Exception(
                "Operator '" ~ operator ~ "' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );
        }

        switch (operator)
        {
        case "+":
            if (leftType == "string" || rightType == "string")
            {
                return createTypeInfo("string");
            }
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return promoteTypes(leftType, rightType);
            }
            throw new Exception(
                "Operator '+' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "-":
        case "*":
        case "/":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return promoteTypes(leftType, rightType);
            }
            if (right.value == 0 && operator == "/")
            {
                throw new Exception("Division by zero detected during type checking");
            }
            throw new Exception(
                "Operator '" ~ operator ~ "' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "%":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return promoteTypes(leftType, rightType);
            }
            if (right.value == 0)
            {
                throw new Exception("Division by zero detected during type checking");
            }
            throw new Exception(
                "Operator '%' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "**":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return promoteTypes(leftType, rightType);
            }
            throw new Exception(
                "Operator '**' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "==":
        case "!=":
            if (areTypesCompatible(leftType, rightType))
            {
                return createTypeInfo("bool");
            }
            throw new Exception(
                "Operator '" ~ operator ~ "' cannot be applied to incompatible types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "<":
        case "<=":
        case ">":
        case ">=":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return createTypeInfo("bool");
            }
            if (leftType == "string" && rightType == "string")
            {
                return createTypeInfo("bool");
            }
            throw new Exception(
                "Operator '" ~ operator ~ "' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "&&":
        case "||":
            if (leftType == "bool" && rightType == "bool")
            {
                return createTypeInfo("bool");
            }
            throw new Exception(
                "Operator '" ~ operator ~ "' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        default:
            throw new Exception("Unknown operator: " ~ operator);
        }
    }

    public void registerCustomType(string sourceType, string targetType)
    {
        typeMap[sourceType] = targetType;
    }

    private Loc makeLoc(Loc start, Loc end)
    {
        Loc result = start;
        result.end = end.end;
        return result;
    }

    public string formatLiteralForType(NativeValue value, string targetType)
    {
        try
        {
            if (!targetType.canFind("i8"))
            {
                auto numValue = to!double(value);
                if (!isNaN(numValue))
                {
                    if (targetType == "float" || targetType == "double")
                    {
                        string strValue = to!string(value);
                        if (to!long(numValue) == numValue && !strValue.canFind("."))
                        {
                            return to!string(value) ~ ".0";
                        }
                        return to!string(value);
                    }
                    return to!string(cast(long) numValue);
                }
            }

            if (is(typeof(value) == string))
            {
                return to!string(value);
            }
        }
        catch (Exception e)
        {
            // Ignore conversion errors and fall through to default
        }
        return to!string(value);
    }

    public bool isPointerType(TypeInfo type)
    {
        return type.isPointer;
    }
}

// Singleton instance for global access
private __gshared TypeChecker typeCheckerInstance;

public TypeChecker getTypeChecker(DiagnosticReporter reporter = null,
    Semantic semanticAnalyzer = null)
{
    if (typeCheckerInstance is null)
    {
        typeCheckerInstance = new TypeChecker(reporter, semanticAnalyzer);
    }
    return typeCheckerInstance;
}
