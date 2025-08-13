module backend.compiler;

import std.stdio;
import std.format;
import backend.codegen.core;
import backend.builder;
import middle.semantic;
import middle.std_lib_module_builder;

class Compiler
{
private:
    Builder builder;
    Semantic semantic;
public:
    this(Builder builder)
    {
        this.builder = builder;
        this.semantic = builder.semantic;
    }

    void compile()
    {
        CodeGenerator codegen = this.builder.codegen;

        if (this.semantic.availableStdFunctions.length > 0)
        {
            // vamos adicionar as funções em nosso escopo global
            foreach (string name, StdLibFunction fn; this.semantic.availableStdFunctions)
            {
                codegen.currentModule.addStdFunction(fn.ir);
            }
        }

        write(codegen.generate());
        codegen.saveToFile("hello_world.d");
        writeln("Salvo em: 'hello_world.d'.");
    }
}
