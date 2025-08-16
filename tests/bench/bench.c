#include <stdio.h>
#include <math.h>
#include <stdbool.h>

bool eh_primo(int n)
{
    if (n < 2)
        return false;
    if (n == 2)
        return true;
    if (n % 2 == 0)
        return false;

    int limite = (int)sqrt(n);
    for (int i = 3; i <= limite; i += 2)
    {
        if (n % i == 0)
            return false;
    }
    return true;
}

int contar_primos(int limite)
{
    int contador = 0;
    for (int numero = 2; numero <= limite; numero++)
    {
        if (eh_primo(numero))
            contador++;
    }
    return contador;
}

int main()
{
    int limite = 1000000;

    int resultado = contar_primos(limite);
    printf("RESULT:%d\n", resultado);

    return 0;
}
