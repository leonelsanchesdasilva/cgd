module main;

pragma(mangle, "io")
extern(D) void escreva(...);
pragma(mangle, "io")
extern(D) void escrevaln(...);

void main() {
    int resultado = fibonacci(40);
    escrevaln("resultado: ", resultado);
    if ((resultado != 102334155))
    {
        escrevaln("o resultado está errado!");
    }

}

int fibonacci(int n) {
    if ((n == 0))
    {
        return 0;
    }

    if ((n == 1))
    {
        return 1;
    }

    return (fibonacci((n - 1)) + fibonacci((n - 2)));
}

