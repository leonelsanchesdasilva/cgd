module stdlib.math;

// TODO: criar uma classe Math

// Constantes

pragma(mangle, "math_pi")
extern (D) double pi()
{
    return 3.141592653589793;
}

pragma(mangle, "math_e")
extern (D) double e()
{
    return 2.718281828459045;
}

// Logaritmos e exponenciais

// Trigonométricos
