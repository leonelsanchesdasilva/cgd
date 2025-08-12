module frontend.parser.ast_utils;

import frontend.parser.ftype_info;
import frontend.parser.ast : Stmt;
import frontend.values;

string strRepeat(string s, ulong times)
{
    string result;
    foreach (_; 0 .. times)
        result ~= s;
    return result;
}

string typeInfoToString(FTypeInfo type)
{
    auto result = type.baseType;

    if (type.isArray)
    {
        for (auto i = 0; i < type.dimensions; i++)
        {
            result ~= "[]";
        }
    }

    if (type.isPointer)
    {
        result ~= strRepeat("*", type.pointerLevel) ~ result;
    }

    return result;
}

FTypeInfo inferUnaryType(string operator, Stmt operand)
{
    switch (operator)
    {
    case "-":
        return operand.type;
    case "!":
        return createTypeInfo(TypesNative.BOOL);
    default:
        return createTypeInfo(TypesNative.NULL);
    }
}
