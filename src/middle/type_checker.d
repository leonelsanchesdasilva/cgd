module middle.type_checker;

import std.string;
import std.conv;
import std.math : isNaN;
import std.exception;
import std.algorithm;
import frontend.lexer.token;
import frontend.parser.ast;
import frontend.values;
import middle.semantic;
import frontend.parser.ftype_info;
import std.variant;

class TypeChecker
{
    private string[string] typeMap;
    private int[string] typeHierarchy;
    private Semantic semanticAnalyzer;
    private ClassDeclaration[string] availableClasses;

    this(Semantic semanticAnalyzer = null)
    {
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
        typeMap["int"] = "long";
        typeMap["long"] = "long";
        typeMap["float"] = "double";
        typeMap["double"] = "double";
        typeMap["string"] = "string";
        typeMap["bool"] = "bool";
        typeMap["null"] = "null";
        typeMap["id"] = "auto";
        typeMap["void"] = "void";
        typeMap["void*"] = "void*";
        typeMap["class"] = "void*";
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
        throw new Exception("Unsupported type mapping for " ~ sourceType);
    }

    public string getTypeStringFromNative(TypesNative nativeType)
    {
        final switch (nativeType)
        {
        case TypesNative.NULL:
            return "typeof(null)";
        case TypesNative.BOOL:
            return "bool";
        case TypesNative.FLOAT:
            return "double";
        case TypesNative.STRING:
            return "string";
        case TypesNative.LONG:
            return "long";
        case TypesNative.CHAR:
            return "char";
        case TypesNative.VOID:
            return "void";
        case TypesNative.ID:
            return "void*";
        case TypesNative.CLASS:
            return "class";
        }
    }

    public void registerClass(string className, ClassDeclaration classDecl)
    {
        availableClasses[className] = classDecl;
    }

    public bool isValidClass(string className)
    {
        return (className in availableClasses) !is null;
    }

    public bool isNumericType(string type)
    {
        string[] numericTypes = [
            "int", "i32", "i64", "long", "float", "double", "binary", "id", "auto"
        ];
        return numericTypes.canFind(type);
    }

    public bool isFloat(string left, string right)
    {
        return left == "float" || right == "float" ||
            left == "double" || right == "double";
    }

    // Gets the promoted type between two numeric types
    private FTypeInfo promoteTypes(string leftType, string rightType)
    {
        int leftRank = typeHierarchy.get(leftType, 0);
        int rightRank = typeHierarchy.get(rightType, 0);

        if (leftRank >= rightRank)
        {
            return createTypeInfo(leftType);
        }
        return createTypeInfo(stringToTypesNative(rightType));
    }

    public bool areTypesCompatible(string sourceType, string targetType)
    {
        if (sourceType == targetType)
            return true;

        if (isNumericType(sourceType) && isNumericType(targetType))
            return true;

        string[][string] compatibilityMap = [
            "int": ["float", "double", "i64", "long", "bool", "i128", "string"],
            "i32": ["float", "double", "i64", "long", "bool"],
            "float": ["double", "int", "i32", "i64", "long", "bool", "string"],
            "double": ["int", "i32", "float", "i64", "long", "bool", "string"],
            "binary": ["int", "i32", "i64", "long"],
            "i64": ["float", "double", "bool"],
            "long": ["float", "double", "bool"],
            "string": ["const char", "char", "binary"],
            "bool": ["int", "i32", "long", "float", "double", "string", "i64"]
        ];

        if (sourceType in compatibilityMap &&
            compatibilityMap[sourceType].canFind(targetType))
            return true;

        if (sourceType == "id" || targetType == "id")
            return true;

        if (sourceType.startsWith("class") && targetType.startsWith("class"))
            return false;

        return false;
    }

    public FTypeInfo checkBinaryExprTypes(Stmt left, Stmt right, string operator)
    {
        // import std.stdio;

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
        case "~":
            if (leftType == "string" || rightType == "string")
            {
                return createTypeInfo("string");
            }
            throw new Exception(
                "Operator '" ~ operator ~ "' cannot be applied to types '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );
        case "&":
        case "|":
        case "^":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return promoteTypes(leftType, rightType);
            }
            throw new Exception(
                "Operator '" ~ operator ~ "' can only be applied to integer types, got '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "<<":
        case ">>":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return createTypeInfo(leftType);
            }
            throw new Exception(
                "Shift operators can only be applied to integer types, got '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );

        case "&=":
        case "|=":
        case "^=":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return createTypeInfo(leftType);
            }
            throw new Exception(
                "Operator '" ~ operator ~ "' can only be applied to integer types, got '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );
        case "<<=":
        case ">>=":
            if (isNumericType(leftType) && isNumericType(rightType))
            {
                return createTypeInfo(leftType);
            }
            throw new Exception(
                "Shift assignment operators can only be applied to integer types, got '" ~
                    leftType ~ "' and '" ~ rightType ~ "'"
            );
        default:
            throw new Exception("Unknown operator: " ~ operator);
        }
    }

    public FTypeInfo checkUnaryExprType(Stmt operand, string operator, bool isPostfix = false)
    {
        string operandType = this.getTypeStringFromNative(operand.type.baseType);

        switch (operator)
        {
        case "++":
        case "--":
            if (!isNumericType(operandType))
            {
                throw new Exception(
                    "Operator '" ~ operator ~ "' can only be applied to numeric types, got '" ~
                        operandType ~ "'"
                );
            }
            return operand.type;

        case "+":
        case "-":
            if (!isNumericType(operandType))
            {
                throw new Exception(
                    "Unary operator '" ~ operator ~ "' can only be applied to numeric types, got '" ~
                        operandType ~ "'"
                );
            }
            return operand.type;

        case "!":
            return createTypeInfo(TypesNative.BOOL);

        case "~":
            if (!isNumericType(operandType) || operandType == "float" || operandType == "double")
            {
                throw new Exception(
                    "Bitwise NOT operator '~' can only be applied to integer types, got '" ~
                        operandType ~ "'"
                );
            }
            return operand.type;

        default:
            throw new Exception("Unknown unary operator: " ~ operator);
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

    public string formatLiteralForType(Variant value, string targetType)
    {
        try
        {
            if (!targetType.canFind("string"))
            {
                auto numValue = value.get!double();
                if (!isNaN(numValue))
                {
                    if (targetType == "float" || targetType == "double")
                    {
                        string strValue = to!string(value);
                        if (to!long(numValue) == numValue && !strValue.canFind("."))
                        {
                            return value.get!string ~ ".0";
                        }
                        return value.get!string;
                    }
                    return to!string(cast(long) numValue);
                }
            }

            if (is(typeof(value) == string))
            {
                return value.get!string;
            }
        }
        catch (Exception e)
        {
            // Ignore conversion errors and fall through to default
        }
        return value.get!string;
    }

    public bool isPointerType(FTypeInfo type)
    {
        return type.isPointer;
    }
}

// Singleton instance for global access
private __gshared TypeChecker typeCheckerInstance;

public TypeChecker getTypeChecker(
    Semantic semanticAnalyzer = null)
{
    if (typeCheckerInstance is null)
    {
        typeCheckerInstance = new TypeChecker(semanticAnalyzer);
    }
    return typeCheckerInstance;
}
