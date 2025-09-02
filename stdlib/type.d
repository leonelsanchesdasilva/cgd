module stdlib.type;

pragma(mangle, "type_texto")
extern (D) string type_itexto(long n)
{
    if (n == 0)
        return "0";

    bool negative = n < 0;
    if (negative)
        n = -n;

    char[] result;
    while (n > 0)
    {
        result = cast(char)('0' + (n % 10)) ~ result;
        n /= 10;
    }

    if (negative)
        result = '-' ~ result;
    return cast(string) result;
}

pragma(mangle, "type_dtexto")
extern (D) string type_dtexto(double n)
{
    if (n < 0)
    {
        return "-" ~ type_dtexto(-n);
    }

    // Para zero
    if (n == 0.0)
    {
        return "0";
    }

    // Parte inteira
    long intPart = cast(long) n;
    double fracPart = n - intPart;

    string result = type_itexto(intPart);

    if (fracPart > 0.000001)
    {
        result ~= ".";
        for (int i = 0; i < 6 && fracPart > 0.000001; i++)
        {
            fracPart *= 10;
            int digit = cast(int) fracPart;
            result ~= cast(char)('0' + digit);
            fracPart -= digit;
        }
    }

    return result;
}

pragma(mangle, "type_sdecimal")
extern (D) double type_sdecimal(string s)
{
    if (s.length == 0)
        return 0.0;

    double result = 0.0;
    bool negative = false;
    size_t i = 0;

    // Verifica sinal
    if (s[0] == '-')
    {
        negative = true;
        i = 1;
    }
    else if (s[0] == '+')
    {
        i = 1;
    }

    // Parte inteira
    while (i < s.length && s[i] >= '0' && s[i] <= '9')
    {
        result = result * 10 + (s[i] - '0');
        i++;
    }

    // Parte decimal
    if (i < s.length && s[i] == '.')
    {
        i++;
        double decimal = 0.1;
        while (i < s.length && s[i] >= '0' && s[i] <= '9')
        {
            result += (s[i] - '0') * decimal;
            decimal /= 10;
            i++;
        }
    }

    return negative ? -result : result;
}
