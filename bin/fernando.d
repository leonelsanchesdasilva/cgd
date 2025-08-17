module main;

pragma(mangle, "io")
extern(D) void escreva(...);
pragma(mangle, "io")
extern(D) void escrevaln(...);

void main() {
    string name = "Fernando";
    escrevaln("Criado por: ", name);
}

