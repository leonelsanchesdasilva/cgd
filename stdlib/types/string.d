module stdlib.types.string;

import std.array;

pragma(mangle, "string_tamanho")
extern (D) long string_tamanho(string str)
{
    return str.length;
}

pragma(mangle, "string_dividir")
extern (D) string[] string_dividir(string str, string by)
{
    string[] split;
    string buffer;

    if (by.length == 0)
    {
        return [str];
    }

    for (long i = 0; i <= str.length - by.length; i++)
    {
        if (str[i .. i + by.length] == by)
        {
            split ~= buffer;
            buffer = "";
            i += cast(long) by.length - 1;
            continue;
        }
        buffer ~= str[i];
    }

    for (long i = str.length - by.length + 1; i < str.length; i++)
    {
        buffer ~= str[i];
    }

    split ~= buffer;

    return split;
}

pragma(mangle, "string_substituir")
extern (D) string string_substituir(string str, string before, string after)
{
    return str.replace(before, after);
}
