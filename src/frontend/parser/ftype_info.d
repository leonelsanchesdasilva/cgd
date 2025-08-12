module frontend.parser.ftype_info;

import frontend.values;

struct FTypeInfo
{
    TypesNative baseType;
    bool isArray;
    ulong dimensions;
    bool isPointer;
    bool isStruct;
    ulong pointerLevel;
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

FTypeInfo createTypeInfo(string baseType, bool s = false)
{
    return FTypeInfo(
        cast(TypesNative) baseType,
        false,
        0,
        false,
        s,
        0
    );
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
