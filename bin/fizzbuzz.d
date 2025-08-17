module main;

pragma(mangle, "io_escreva")
extern(D) void escreva(...);
pragma(mangle, "io_escrevaln")
extern(D) void escrevaln(...);
pragma(mangle, "io_leia")
extern(D) string leia(string param0);

void main() {
    int n = 15;
    for (int i = 1; i <= n; i = i + 1)
    {
        string resultado = "";
        if (i % 3 == 0)
        {
            resultado = resultado ~ "Fizz";
        }

        if (i % 5 == 0)
        {
            resultado = resultado ~ "Buzz";
        }

        if (resultado == "")
        {
            escrevaln(i);
        }
        else         {
            escrevaln(resultado);
        }

    }
}

