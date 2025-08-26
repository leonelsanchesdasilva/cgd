module frontend.parser.ftype_info;

import frontend.values;
import std.string : toLower;

struct FTypeInfo
{
    TypesNative baseType;
    bool isArray;
    ulong dimensions;
    bool isPointer;
    bool isStruct;
    ulong pointerLevel;
    string className;
}

TypesNative stringToTypesNative(string typeStr)
{
    switch (typeStr.toLower())
    {
    case "double":
    case "float":
        return TypesNative.FLOAT;
    case "string":
    case "texto":
        return TypesNative.STRING;
    case "bool":
    case "logico":
        return TypesNative.BOOL;
    case "int":
    case "long":
    case "inteiro":
        return TypesNative.LONG;
    case "char":
    case "caracter":
        return TypesNative.CHAR;
    case "null":
    case "nulo":
        return TypesNative.NULL;
    case "void":
    case "id":
        return TypesNative.VOID;
    default:
        return TypesNative.CLASS;
        throw new Exception("Tipo não suportado para conversão: " ~ typeStr);
    }
}

FTypeInfo createTypeInfo(string baseType, bool s = false)
{
    return FTypeInfo(
        stringToTypesNative(baseType),
        false,
        0,
        false,
        s,
        0
    );
}

FTypeInfo createTypeInfo(TypesNative baseType, bool s = false)
{
    return FTypeInfo(
        baseType,
        false,
        0,
        false,
        s,
        0
    );
}

FTypeInfo createClassType(string className)
{
    FTypeInfo info;
    info.baseType = TypesNative.CLASS;
    info.className = className;
    return info;
}

FTypeInfo createArrayType(TypesNative baseType, ulong dimensions = 1, bool s = false)
{
    return FTypeInfo(
        baseType,
        true,
        dimensions,
        false,
        s,
        0
    );
}

FTypeInfo createPointerType(TypesNative baseType, ulong pointerLevel, bool s = false)
{
    return FTypeInfo(
        baseType,
        false,
        0,
        true,
        s,
        pointerLevel
    );
}
