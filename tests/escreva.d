// Usa o nome customizado definido no pragma(mangle)
pragma(mangle, "delegua_lib_escreva_custom")
extern (D) void delegua_lib_escreva(string arg);

void main()
{
    delegua_lib_escreva("Olá");
}
