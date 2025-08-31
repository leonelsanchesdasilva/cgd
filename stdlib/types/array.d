module stdlib.types.array;

// pragma(mangle, "array_tamanho")
// extern (D) long array_tamanho(string[] arr)
// {
//     return arr.length;
// }

pragma(mangle, "array_tamanho")
extern (D) long array_tamanho(long[] arr)
{
    return arr.length;
}

pragma(mangle, "array_adicionar")
extern (D) void array_adicionar(ref string[] arr, string item)
{
    arr ~= item;
}
