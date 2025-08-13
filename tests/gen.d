module tests.gen;

pragma(mangle, "io")
@safe extern (D) void delegua_lib_escreva(string param0, ...);

void main()
{
    delegua_lib_escreva("Oi");
}
