module middle.std_lib_module_builder;

import std.string;
import std.array;
import middle.function_builder;
import frontend.parser.ftype_info;

struct StdLibFunction
{
    string name;
    FTypeInfo returnType;
    FTypeInfo targetType;
    FTypeInfo[] params;
    bool isVariadic;
    string targetName;
    string ir;
    bool isStdLib;

    // D Generator
    string linkage = "D"; // C, C++, D, Windows, System
    string libraryName; // Para pragma(lib, ...)
    string documentation; // Documentação da função
    bool isNoGC; // @nogc
    bool isSafe; // @safe
    bool isNoThrow; // nothrow
    bool isPure; // pure
}

struct FunctionParam
{
    string name;
    FTypeInfo type;
    FTypeInfo targetType;
}

struct Function
{
    string name;
    FTypeInfo returnType;
    FunctionParam[] params;
    bool isVariadic;
    FTypeInfo targetType;
}

struct StdLibModule
{
    string name;
    StdLibFunction[string] functions;
    string[] flags;
}

class StdLibModuleBuilder
{
    StdLibModule moduleData;

    this(string name)
    {
        this.moduleData.name = name;
        this.moduleData.functions = null;
    }

    FunctionBuilder defineFunction(string name)
    {
        return new FunctionBuilder(name, this);
    }

    StdLibModuleBuilder defineFlags(string[] flags...)
    {
        this.moduleData.flags = flags.dup;
        return this;
    }

    void addCompleteFunction(StdLibFunction func)
    {
        this.moduleData.functions[func.name] = func;
    }

    StdLibModule build()
    {
        return this.moduleData;
    }

    // Getter methods for accessing module data
    @property string name() const
    {
        return this.moduleData.name;
    }

    @property const(StdLibFunction[string]) functions() const
    {
        return this.moduleData.functions;
    }

    @property const(string[]) flags() const
    {
        return this.moduleData.flags;
    }

    // Helper methods
    bool hasFunction(string name) const
    {
        return (name in this.moduleData.functions) !is null;
    }

    StdLibFunction getFunction(string name)
    {
        if (auto func = name in this.moduleData.functions)
        {
            return *func;
        }
        throw new Exception(
            "Function '" ~ name ~ "' not found in module '" ~
                this.moduleData.name ~ "'");
    }

    string[] getFunctionNames() const
    {
        return this.moduleData.functions.keys;
    }

    size_t getFunctionCount() const
    {
        return this.moduleData.functions.length;
    }
}
