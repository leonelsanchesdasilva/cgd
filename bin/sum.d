module main;

pragma(mangle, "io")
extern(D) void escreva(...);
pragma(mangle, "io")
extern(D) void escrevaln(...);

void main() {
    int resultado = sum(60, 9);
    escreva("Resultado: ", resultado, "\n");
}

int ret1(int x) {
    return x;
}

int ret2(int y) {
    return y;
}

int sum(int x, int y) {
    return (ret1(x) + ret2(y));
}

