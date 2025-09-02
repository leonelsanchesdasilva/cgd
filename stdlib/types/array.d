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

pragma(mangle, "array_string_adicionar")
extern (D) void array_string_adicionar(ref string[] arr, string item)
{
    arr ~= item;
}

pragma(mangle, "array_long_adicionar")
extern (D) void array_long_adicionar(ref long[] arr, long item)
{
    arr ~= item;
}

pragma(mangle, "array_double_adicionar")
extern (D) void array_double_adicionar(ref double[] arr, double item)
{
    arr ~= item;
}
