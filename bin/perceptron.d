module main;

pragma(mangle, "io")
extern(D) void escreva(...);
pragma(mangle, "io")
extern(D) void escrevaln(...);

void main() {
    double pesoInicial1 = 0.3;
    double pesoInicial2 = 0.4;
    int entrada1 = 1;
    int entrada2 = 1;
    int erro = 1;
    int resultadoEsperado;
    while ((erro != 0))
    {
        if ((entrada1 == 1))
        {
            if ((entrada2 == 1))
            {
                resultadoEsperado = 1;
            }

        }
        else         {
            resultadoEsperado = 0;
        }

        double somatoria = (pesoInicial1 * entrada1);
        somatoria = ((pesoInicial2 * entrada2) + somatoria);
        int resultado;
        if ((somatoria < 1))
        {
            resultado = 0;
        }
        else         {
            if ((somatoria >= 1))
            {
                resultado = 1;
            }

        }

        escreva("resultado: ", resultado, "\n");
        erro = (resultadoEsperado - resultado);
        escreva("p1: ", pesoInicial1, "\n");
        escreva("p2: ", pesoInicial2, "\n");
        pesoInicial1 = (((0.1 * entrada1) * erro) + pesoInicial1);
        pesoInicial2 = (((0.1 * entrada2) * erro) + pesoInicial2);
        escreva("erro: ", erro, "\n");
    }
}

