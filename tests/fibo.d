module main;

pragma(mangle, "io")
extern(D) void escreva(...);

void main() {
    int resultado = fibonacci(10);
    if ((resultado != 55))
    {
        escreva("o resultado está errado!");
    }

}

int fibonacci(int n) {
    if ((n <= 1))
    {
        return 1;
    }

    return (fibonacci((n - 1)) + fibonacci((n - 2)));
}

