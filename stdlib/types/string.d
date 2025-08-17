module stdlib.types.string;

pragma(mangle, "string_tamanho")
extern (D) int tamanho(string str)
{
    return str.length;
}
