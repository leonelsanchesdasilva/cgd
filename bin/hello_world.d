module main;

pragma(mangle, "io")
extern(D) void escreva(...);
pragma(mangle, "io")
extern(D) void escrevaln(...);

void main() {
    escreva("Hello World");
}

