module stdlib.types.string;

pragma(mangle, "string_tamanho")
extern (D) long string_tamanho(string str)
{
    return str.length;
}
