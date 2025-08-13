module main;

pragma(mangle, "io")
@safe extern(D) void delegua_lib_escreva(string param0, ...);

void main() {
    escreva("Hello World");
}

