module stdlib.io;

import std.stdio : write, writeln;
import std.conv : to;
import std.traits : isNumeric, isSomeString;
import core.vararg;

pragma(mangle, "io")
extern (D) void escreva(...)
{
    foreach (i; 0 .. _arguments.length)
    {
        TypeInfo ti = _arguments[i];

        if (ti == typeid(int))
        {
            int value = va_arg!(int)(_argptr);
            write(value);
        }
        else if (ti == typeid(string))
        {
            string value = va_arg!(string)(_argptr);
            write(value);
        }
        else if (ti == typeid(char[]))
        {
            char[] value = va_arg!(char[])(_argptr);
            write(value);
        }
        else if (ti == typeid(double))
        {
            double value = va_arg!(double)(_argptr);
            write(value);
        }
        else if (ti == typeid(float))
        {
            float value = va_arg!(float)(_argptr);
            write(value);
        }
        else if (ti == typeid(long))
        {
            long value = va_arg!(long)(_argptr);
            write(value);
        }
        else if (ti == typeid(bool))
        {
            bool value = va_arg!(bool)(_argptr);
            write(value);
        }
        else if (ti == typeid(char))
        {
            char value = va_arg!(char)(_argptr);
            write(value);
        }
        else
        {
            // Para outros tipos, tenta converter para string
            write("[tipo não suportado: ", ti.toString(), "]");
        }
    }
}

// Versão adicional com quebra de linha
pragma(mangle, "ioln")
extern (D) void escrevaln(...)
{
    foreach (i; 0 .. _arguments.length)
    {
        TypeInfo ti = _arguments[i];

        if (ti == typeid(int))
        {
            int value = va_arg!(int)(_argptr);
            write(value);
        }
        else if (ti == typeid(string))
        {
            string value = va_arg!(string)(_argptr);
            write(value);
        }
        else if (ti == typeid(char[]))
        {
            char[] value = va_arg!(char[])(_argptr);
            write(value);
        }
        else if (ti == typeid(double))
        {
            double value = va_arg!(double)(_argptr);
            write(value);
        }
        else if (ti == typeid(float))
        {
            float value = va_arg!(float)(_argptr);
            write(value);
        }
        else if (ti == typeid(long))
        {
            long value = va_arg!(long)(_argptr);
            write(value);
        }
        else if (ti == typeid(bool))
        {
            bool value = va_arg!(bool)(_argptr);
            write(value);
        }
        else if (ti == typeid(char))
        {
            char value = va_arg!(char)(_argptr);
            write(value);
        }
        else
        {
            write("[tipo não suportado: ", ti.toString(), "]");
        }
    }
    writeln(); // Adiciona quebra de linha no final
}

// Exemplo de uso
version (unittest)
{
    unittest
    {
        escreva("Hello", " ", "World", 42);
        escrevaln("Hello", " ", "World", 42); // Com quebra de linha
    }
}
