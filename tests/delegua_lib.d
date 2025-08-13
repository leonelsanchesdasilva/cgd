module delegua_lib;
import std.stdio;

// Força um nome específico no símbolo
pragma(mangle, "delegua_lib_escreva_custom")
extern (D) void delegua_lib_escreva(string arg)
{
    writeln("Recebi: ", arg);
}
