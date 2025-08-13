module backend.compiler;

import std.stdio;
import std.format;
import std.file;
import std.path;
import std.process;
import std.string;
import std.array;
import backend.codegen.core;
import backend.builder;
import middle.semantic;
import middle.std_lib_module_builder;

class Compiler
{
private:
    Builder builder;
    Semantic semantic;
    string filename;
    string arquivoSaida;
    // Futuramente irá alterar para usar um caminho fixo
    // Ficaria em $HOME/.cgd/stdlib
    string stdlibPath = "stdlib"; // Diretório das bibliotecas padrão

public:
    this(Builder builder, string filename, string arquivoSaida)
    {
        this.builder = builder;
        this.semantic = builder.semantic;
        this.filename = filename;
        this.arquivoSaida = arquivoSaida;
    }

    void compile()
    {
        writeln("🔨 Iniciando compilação...");

        CodeGenerator codegen = this.builder.codegen;

        if (this.semantic.availableStdFunctions.length > 0)
        {
            writeln("📚 Adicionando funções da biblioteca padrão...");
            foreach (string name, StdLibFunction fn; this.semantic.availableStdFunctions)
            {
                codegen.currentModule.addStdFunction(fn.ir);
                writefln("   ✓ Função '%s' adicionada", name);
            }
        }

        writeln("⚙️  Gerando código...");

        codegen.saveToFile(filename);
        writefln("💾 Código salvo em: '%s'", filename);

        compileWithLDC();
    }

private:
    void removeTempFiles()
    {
        if (exists(this.filename))
        {
            writefln("🗑️  Removendo código salvo em: '%s'", this.filename);
            remove(this.filename);
        }

        import std.array : split;

        string oFile = this.filename.split(".")[0] ~ ".o";
        if (exists(oFile))
        {
            writefln("🗑️  Removendo arquivo temporário: '%s'", oFile);
            remove(oFile);
        }
    }

    void compileWithLDC()
    {
        writeln("🔧 Compilando com LDC...");

        string[] stdlibFiles = collectStdlibFiles();

        if (stdlibFiles.length > 0)
        {
            writeln("🔗 Bibliotecas a serem linkadas:");
            foreach (file; stdlibFiles)
            {
                writefln("   📦 %s", file);
            }
        }

        string[] ldcCommand = buildLDCCommand(stdlibFiles);

        writefln("🚀 Executando: %s", ldcCommand.join(" "));

        auto result = execute(ldcCommand);

        if (result.status == 0)
        {
            writeln("✅ Compilação concluída com sucesso!");
            if (result.output.length > 0)
            {
                writeln("📝 Saída do compilador:");
                writeln(result.output);
            }
        }
        else
        {
            writeln("❌ Erro na compilação:");
            writeln(result.output);
        }

        this.removeTempFiles();
    }

    string[] collectStdlibFiles()
    {
        string[] files;

        if (!exists(stdlibPath) || !isDir(stdlibPath))
        {
            writefln("⚠️  Diretório '%s' não encontrado", stdlibPath);
            return files;
        }

        foreach (string moduleName, bool imported; this.semantic.importedModules)
        {
            if (imported)
            {
                string stdlibFile = buildPath(stdlibPath, moduleName ~ ".d");

                if (exists(stdlibFile) && isFile(stdlibFile))
                {
                    files ~= stdlibFile;
                }
                else
                {
                    writefln("⚠️  Biblioteca '%s.d' não encontrada em '%s'", moduleName, stdlibPath);
                }
            }
        }

        return files;
    }

    string[] buildLDCCommand(string[] stdlibFiles)
    {
        string[] command;

        // Comando base do LDC
        command ~= "ldc2";

        // Arquivo principal
        command ~= filename;

        // Arquivos da stdlib
        command ~= stdlibFiles;

        // Opções de otimização (opcional)
        command ~= "-O2";

        command ~= "-of=" ~ this.arquivoSaida;

        return command;
    }

    void compileWithVerboseOutput()
    {
        writeln("🔧 Compilando com LDC (modo verbose)...");

        string[] stdlibFiles = collectStdlibFiles();
        string[] command = buildLDCCommand(stdlibFiles);

        // Adicionar flags de debug/verbose
        command ~= "-v"; // Verbose
        command ~= "-g"; // Debug info

        writefln("🚀 Comando completo: %s", command.join(" "));

        auto pipes = pipeProcess(command, Redirect.all);
        scope (exit)
            wait(pipes.pid);

        // Mostrar saída em tempo real
        foreach (line; pipes.stdout.byLine)
        {
            writefln("   %s", line);
        }

        foreach (line; pipes.stderr.byLine)
        {
            writefln("⚠️  %s", line);
        }

        int exitCode = wait(pipes.pid);

        if (exitCode == 0)
        {
            writeln("✅ Compilação concluída com sucesso!");
        }
        else
        {
            writefln("❌ Compilação falhou com código: %d", exitCode);
        }

        this.removeTempFiles();
    }

    void precompileStdlib()
    {
        writeln("🔨 Pré-compilando bibliotecas padrão...");

        string[] stdlibFiles = collectStdlibFiles();

        foreach (file; stdlibFiles)
        {
            string objFile = file.stripExtension() ~ ".o";
            string[] command = ["ldc2", "-c", file, "-of=" ~ objFile];

            writefln("🔧 Compilando: %s → %s", file, objFile);

            auto result = execute(command);
            if (result.status == 0)
            {
                writefln("   ✅ %s compilado", file.baseName);
            }
            else
            {
                writefln("   ❌ Erro compilando %s:", file.baseName);
                writeln(result.output);
            }
        }
    }
}
