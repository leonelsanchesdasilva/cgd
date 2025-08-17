module main;

pragma(mangle, "io")
extern(D) void escreva(...);
pragma(mangle, "io")
extern(D) void escrevaln(...);

void main() {
    string nome = "Fernando";
    int idade = 17;
    int a = 1;
    int b = 2;
    double c = 1.5;
    double d = 2.5;
    string e;
    string f;
    e = "Qualquer Coisa";
    f = "Outra coisa util";
    escreva(nome, " ", idade, " ", a, " ", b, " ", c, " ", d, " ", e, " ", f, "\n");
}

