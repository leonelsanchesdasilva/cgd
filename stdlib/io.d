module stdlib.io;

import std.stdio : write, writeln, readln;
import std.string : strip;
import std.conv : to;
import std.traits : isNumeric, isSomeString;
import core.vararg;

pragma(mangle, "io_escreva")
extern (D) void escreva(...)
{
    auto argptr = _argptr;

    foreach (i; 0 .. _arguments.length)
    {
        TypeInfo ti = _arguments[i];

        if (ti == typeid(int))
        {
            int value = va_arg!(int)(argptr);
            write(value);
        }
        else if (ti == typeid(uint))
        {
            uint value = va_arg!(uint)(argptr);
            write(value);
        }
        else if (ti == typeid(long))
        {
            long value = va_arg!(long)(argptr);
            write(value);
        }
        else if (ti == typeid(ulong))
        {
            ulong value = va_arg!(ulong)(argptr);
            write(value);
        }
        else if (ti == typeid(short))
        {
            short value = va_arg!(short)(argptr);
            write(value);
        }
        else if (ti == typeid(ushort))
        {
            ushort value = va_arg!(ushort)(argptr);
            write(value);
        }
        else if (ti == typeid(byte))
        {
            byte value = va_arg!(byte)(argptr);
            write(value);
        }
        else if (ti == typeid(ubyte))
        {
            ubyte value = va_arg!(ubyte)(argptr);
            write(value);
        }
        else if (ti == typeid(double))
        {
            double value = va_arg!(double)(argptr);
            write(value);
        }
        else if (ti == typeid(float))
        {
            float value = va_arg!(float)(argptr);
            write(value);
        }
        else if (ti == typeid(real))
        {
            real value = va_arg!(real)(argptr);
            write(value);
        }
        else if (ti == typeid(bool))
        {
            bool value = va_arg!(bool)(argptr);
            write(value ? "true" : "false");
        }
        else if (ti == typeid(char))
        {
            char value = va_arg!(char)(argptr);
            write(value);
        }
        else if (ti == typeid(wchar))
        {
            wchar value = va_arg!(wchar)(argptr);
            write(value);
        }
        else if (ti == typeid(dchar))
        {
            dchar value = va_arg!(dchar)(argptr);
            write(value);
        }
        else if (ti == typeid(string))
        {
            string value = va_arg!(string)(argptr);
            write(value);
        }
        else if (ti == typeid(immutable(char)))
        {
            immutable(char) value = va_arg!(immutable(char))(argptr);
            write(value);
        }
        else if (ti == typeid(char[]))
        {
            char[] value = va_arg!(char[])(argptr);
            write(value);
        }
        else if (ti == typeid(long[]))
        {
            long[] value = va_arg!(long[])(argptr);
            write(value);
        }
        else if (ti == typeid(string[]))
        {
            string[] value = va_arg!(string[])(argptr);
            write(value);
        }
        else if (ti == typeid(double[]))
        {
            double[] value = va_arg!(double[])(argptr);
            write(value);
        }
        else if (ti == typeid(wstring))
        {
            wstring value = va_arg!(wstring)(argptr);
            write(value);
        }
        else if (ti == typeid(dstring))
        {
            dstring value = va_arg!(dstring)(argptr);
            write(value);
        }
        else
        {
            write("[tipo não suportado: ", ti.toString(), "]");
            // Avança o ponteiro mesmo para tipos não suportados
            va_arg!(void*)(argptr);
        }
    }
}

pragma(mangle, "io_escrevaln")
extern (D) void escrevaln(...)
{
    auto argptr = _argptr;

    foreach (i; 0 .. _arguments.length)
    {
        TypeInfo ti = _arguments[i];

        if (ti == typeid(int))
        {
            int value = va_arg!(int)(argptr);
            write(value);
        }
        else if (ti == typeid(uint))
        {
            uint value = va_arg!(uint)(argptr);
            write(value);
        }
        else if (ti == typeid(long))
        {
            long value = va_arg!(long)(argptr);
            write(value);
        }
        else if (ti == typeid(ulong))
        {
            ulong value = va_arg!(ulong)(argptr);
            write(value);
        }
        else if (ti == typeid(short))
        {
            short value = va_arg!(short)(argptr);
            write(value);
        }
        else if (ti == typeid(ushort))
        {
            ushort value = va_arg!(ushort)(argptr);
            write(value);
        }
        else if (ti == typeid(byte))
        {
            byte value = va_arg!(byte)(argptr);
            write(value);
        }
        else if (ti == typeid(ubyte))
        {
            ubyte value = va_arg!(ubyte)(argptr);
            write(value);
        }
        else if (ti == typeid(double))
        {
            double value = va_arg!(double)(argptr);
            write(value);
        }
        else if (ti == typeid(float))
        {
            float value = va_arg!(float)(argptr);
            write(value);
        }
        else if (ti == typeid(real))
        {
            real value = va_arg!(real)(argptr);
            write(value);
        }
        else if (ti == typeid(bool))
        {
            bool value = va_arg!(bool)(argptr);
            write(value ? "true" : "false");
        }
        else if (ti == typeid(char))
        {
            char value = va_arg!(char)(argptr);
            write(value);
        }
        else if (ti == typeid(wchar))
        {
            wchar value = va_arg!(wchar)(argptr);
            write(value);
        }
        else if (ti == typeid(dchar))
        {
            dchar value = va_arg!(dchar)(argptr);
            write(value);
        }
        else if (ti == typeid(string))
        {
            string value = va_arg!(string)(argptr);
            write(value);
        }
        else if (ti == typeid(immutable(char)))
        {
            immutable(char) value = va_arg!(immutable(char))(argptr);
            write(value);
        }
        else if (ti == typeid(char[]))
        {
            char[] value = va_arg!(char[])(argptr);
            write(value);
        }
        else if (ti == typeid(long[]))
        {
            long[] value = va_arg!(long[])(argptr);
            write(value);
        }
        else if (ti == typeid(string[]))
        {
            string[] value = va_arg!(string[])(argptr);
            write(value);
        }
        else if (ti == typeid(double[]))
        {
            double[] value = va_arg!(double[])(argptr);
            write(value);
        }
        else if (ti == typeid(wstring))
        {
            wstring value = va_arg!(wstring)(argptr);
            write(value);
        }
        else if (ti == typeid(dstring))
        {
            dstring value = va_arg!(dstring)(argptr);
            write(value);
        }
        else
        {
            write("[tipo não suportado: ", ti.toString(), "]");
            va_arg!(void*)(argptr);
        }
    }

    writeln();
}

pragma(mangle, "io_leia")
extern (D) string leia(string prompt = "") // opt = 1
{
    if (prompt.length > 0)
        write(prompt);
    return readln().strip();
}
