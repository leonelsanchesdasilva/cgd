/**
 * Farpy - A programming language
 *
 * Copyright (c) 2025 Fernando (FernandoTheDev)
 *
 * This software is licensed under the MIT License.
 * See the LICENSE file in the project root for full license information.
 */
module middle.std_lib_module_builder;

import std.string;
import std.array;
import middle.function_builder;

struct StdLibFunction
{
    string name;
    TypeInfo returnType;
    string targetType;
    string[] params;
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
    TypeInfo type;
    string targetType;
}

struct Function
{
    string name;
    TypeInfo returnType;
    FunctionParam[] params;
    bool isVariadic;
    string targetType;
}

struct StdLibModule
{
    string name;
    StdLibFunction[string] functions;
    string[] flags;
}

class StdLibModuleBuilder
{
    private StdLibModule moduleData;
    private DiagnosticReporter reporter;

    this(string name, DiagnosticReporter reporter = null)
    {
        this.moduleData.name = name;
        this.moduleData.functions = null;
        this.reporter = reporter;
    }

    FunctionBuilder defineFunction(string name)
    {
        return new FunctionBuilder(name, this, this.reporter);
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
