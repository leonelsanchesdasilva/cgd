module main;

pragma(mangle, "io")
extern(D) void escreva(...);
pragma(mangle, "io")
extern(D) void escrevaln(...);

void main() {
    int i = 0;
    while ((i < 10))
    {
        escreva("Fernando dev: ", i, "\n");
        i = (i + 1);
    }
}

