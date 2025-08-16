module stdlib.io;

import std.stdio : write, writeln, readln;
import std.string : strip;
import std.conv : to;
import std.traits : isNumeric, isSomeString;
import core.vararg;

pragma(mangle, "io_escreva")
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

pragma(mangle, "io_escrevaln")
extern (D) void escrevaln(...)
{
    foreach (i; 0 .. _arguments.length)
    {
        TypeInfo ti = _arguments[i];

        if (ti == typeid(int))
        {
            int value = va_arg!(int)(_argptr);
            writeln(value);
        }
        else if (ti == typeid(string))
        {
            string value = va_arg!(string)(_argptr);
            writeln(value);
        }
        else if (ti == typeid(char[]))
        {
            char[] value = va_arg!(char[])(_argptr);
            writeln(value);
        }
        else if (ti == typeid(double))
        {
            double value = va_arg!(double)(_argptr);
            writeln(value);
        }
        else if (ti == typeid(float))
        {
            float value = va_arg!(float)(_argptr);
            writeln(value);
        }
        else if (ti == typeid(long))
        {
            long value = va_arg!(long)(_argptr);
            writeln(value);
        }
        else if (ti == typeid(bool))
        {
            bool value = va_arg!(bool)(_argptr);
            writeln(value);
        }
        else if (ti == typeid(char))
        {
            char value = va_arg!(char)(_argptr);
            writeln(value);
        }
        else
        {
            writeln("[tipo não suportado: ", ti.toString(), "]");
        }
    }
}

pragma(mangle, "io_leia")
extern (D) string leia(string input = "")
{
    write(input);
    return readln().strip();
}
