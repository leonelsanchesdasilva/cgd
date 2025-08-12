module middle.function_builder;

import std.string;
import std.array;
import std.conv;
import std.algorithm;
import middle.std_lib_module_builder;
import middle.type_checker;
import frontend.parser.ftype_info;

enum ExternStrategy
{
    WithLinkage, // extern(C++) int func(int param);
    WithAttributes, // @nogc @safe extern(C) int func(int param);
    WithPragma, // pragma(lib, "mylib"); extern(C) int func(int param);
    Complete // Documentação + pragma + atributos + extern
}

class FunctionBuilder
{
    private StdLibFunction func;
    private StdLibModuleBuilder moduleBuilder;
    private TypeChecker typeChecker;

    this(string name, StdLibModuleBuilder moduleBuilder)
    {
        this.func = StdLibFunction();
        this.func.name = name;
        this.func.isStdLib = true;
        this.func.isVariadic = false;
        this.func.params = [];

        this.moduleBuilder = moduleBuilder;
        this.typeChecker = getTypeChecker();
    }

    FunctionBuilder returns(FTypeInfo type)
    {
        this.func.returnType = type;
        this.func.targetType = this.typeChecker.mapToDType(type.baseType);
        return this;
    }

    FunctionBuilder withParams(string[] params...)
    {
        this.func.params = params.dup;
        return this;
    }

    FunctionBuilder variadic()
    {
        this.func.isVariadic = true;
        return this;
    }

    FunctionBuilder targetName(string name)
    {
        this.func.targetName = name;
        return this;
    }

    FunctionBuilder customTargetType(string targetType)
    {
        this.func.targetType = targetType;
        return this;
    }

    FunctionBuilder generateDExtern()
    {
        if (this.func.ir.length > 0)
            return this; // already exists

        string fnName = this.func.targetName.length > 0 ?
            this.func.targetName : this.func.name;

        string[] paramDecls;

        foreach (i, p; this.func.params)
        {
            string dType = this.typeChecker.mapToDType(p);
            paramDecls ~= dType ~ " param" ~ to!string(i);
        }

        string returnType = this.typeChecker.mapToDType(this.func.targetType);
        string paramList = paramDecls.join(", ");

        if (this.func.isVariadic)
        {
            paramList ~= paramList.length > 0 ? ", ..." : "...";
        }

        // Gerar declaração extern
        this.func.ir = "extern(" ~ this.func.linkage ~ ") " ~
            returnType ~ " " ~ fnName ~ "(" ~ paramList ~ ");";

        return this;
    }

    FunctionBuilder generateDExternWithLinkage(string linkage = "D")
    {
        if (this.func.ir.length > 0)
            return this; // already exists

        string fnName = this.func.targetName.length > 0 ?
            this.func.targetName : this.func.name;

        string[] paramDecls;

        foreach (i, p; this.func.params)
        {
            string dType = this.typeChecker.mapToDType(p);
            paramDecls ~= dType ~ " param" ~ to!string(i);
        }

        string returnType = this.typeChecker.mapToDType(this.func.targetType);
        string paramList = paramDecls.join(", ");

        if (this.func.isVariadic)
        {
            paramList ~= paramList.length > 0 ? ", ..." : "...";
        }

        // Gerar com linkage específica
        this.func.ir = "extern(" ~ linkage ~ ") " ~
            returnType ~ " " ~ fnName ~ "(" ~ paramList ~ ");";

        return this;
    }

    FunctionBuilder generateDExternWithAttributes()
    {
        if (this.func.ir.length > 0)
            return this; // already exists

        string fnName = this.func.targetName.length > 0 ?
            this.func.targetName : this.func.name;

        string[] paramDecls;

        foreach (i, p; this.func.params)
        {
            string dType = this.typeChecker.mapToDType(p);
            paramDecls ~= dType ~ " param" ~ to!string(i);
        }

        string returnType = this.typeChecker.mapToDType(this.func.targetType);
        string paramList = paramDecls.join(", ");

        if (this.func.isVariadic)
        {
            paramList ~= paramList.length > 0 ? ", ..." : "...";
        }

        // Adicionar atributos baseados no tipo de função
        string[] attributes;
        if (this.func.isNoGC)
            attributes ~= "@nogc";
        if (this.func.isSafe)
            attributes ~= "@safe";
        if (this.func.isNoThrow)
            attributes ~= "nothrow";
        if (this.func.isPure)
            attributes ~= "pure";

        string attributeStr = attributes.length > 0 ?
            attributes.join(" ") ~ " " : "";

        this.func.ir = attributeStr ~ "extern(" ~ this.func.linkage ~ ") " ~
            returnType ~ " " ~ fnName ~ "(" ~ paramList ~ ");";

        return this;
    }

    FunctionBuilder generateDExternWithPragma()
    {
        if (this.func.ir.length > 0)
            return this; // already exists

        string fnName = this.func.targetName.length > 0 ?
            this.func.targetName : this.func.name;

        string[] paramDecls;

        foreach (i, p; this.func.params)
        {
            string dType = this.typeChecker.mapToDType(p);
            paramDecls ~= dType ~ " param" ~ to!string(i);
        }

        string returnType = this.typeChecker.mapToDType(this.func.targetType);
        string paramList = paramDecls.join(", ");

        if (this.func.isVariadic)
        {
            paramList ~= paramList.length > 0 ? ", ..." : "...";
        }

        // Adicionar pragma lib se especificado
        string pragmaStr = "";
        if (this.func.libraryName.length > 0)
        {
            pragmaStr = "pragma(lib, \"" ~ this.func.libraryName ~ "\");\n";
        }

        this.func.ir = pragmaStr ~ "extern(" ~ this.func.linkage ~ ") " ~
            returnType ~ " " ~ fnName ~ "(" ~ paramList ~ ");";

        return this;
    }

    FunctionBuilder generateDExternComplete()
    {
        if (this.func.ir.length > 0)
            return this; // already exists

        string fnName = this.func.targetName.length > 0 ?
            this.func.targetName : this.func.name;

        string[] paramDecls;

        foreach (i, p; this.func.params)
        {
            string dType = this.typeChecker.mapToDType(p);
            paramDecls ~= dType ~ " param" ~ to!string(i);
        }

        string returnType = this.typeChecker.mapToDType(this.func.targetType);
        string paramList = paramDecls.join(", ");

        if (this.func.isVariadic)
        {
            paramList ~= paramList.length > 0 ? ", ..." : "...";
        }

        // Pragma lib
        string pragmaStr = "";
        if (this.func.libraryName.length > 0)
        {
            pragmaStr = "pragma(lib, \"" ~ this.func.libraryName ~ "\");\n";
        }

        // Atributos
        string[] attributes;
        if (this.func.isNoGC)
            attributes ~= "@nogc";
        if (this.func.isSafe)
            attributes ~= "@safe";
        if (this.func.isNoThrow)
            attributes ~= "nothrow";
        if (this.func.isPure)
            attributes ~= "pure";

        string attributeStr = attributes.length > 0 ?
            attributes.join(" ") ~ " " : "";

        // Documentação
        string docStr = "";
        if (this.func.documentation.length > 0)
        {
            docStr = "/**\n * " ~ this.func.documentation ~ "\n */\n";
        }

        this.func.ir = docStr ~ pragmaStr ~ attributeStr ~
            "extern(" ~ this.func.linkage ~ ") " ~
            returnType ~ " " ~ fnName ~ "(" ~ paramList ~ ");";

        return this;
    }

    // Funções auxiliares
    private bool isGenericType(string type)
    {
        return type.startsWith("T") || type == "auto" || type == "generic";
    }

    private bool isNumericType(string type)
    {
        return ["int", "float", "double", "long", "real"].canFind(type);
    }

    private bool needsSerializationMixin(string type)
    {
        return ["struct", "class", "object"].canFind(type);
    }

    private string generateBaseTemplate(string fnName)
    {
        return "T " ~ fnName ~ "(T)(T param) {\n    // Base implementation\n}";
    }

    private string[] generateSpecializations(string fnName)
    {
        return [
            "int " ~ fnName ~ "(int param) {\n    // Specialized for int\n}",
            "string " ~ fnName ~ "(string param) {\n    // Specialized for string\n}"
        ];
    }

    FunctionBuilder generate(ExternStrategy strategy = ExternStrategy.WithLinkage)
    {
        switch (strategy)
        {
        case ExternStrategy.WithLinkage:
            return generateDExternWithLinkage(this.func.linkage);
        case ExternStrategy.WithAttributes:
            return generateDExternWithAttributes();
        case ExternStrategy.WithPragma:
            return generateDExternWithPragma();
        case ExternStrategy.Complete:
            return generateDExternComplete();
        default:
            return generateDExternWithLinkage(this.func.linkage);
        }
    }

    StdLibModuleBuilder done()
    {
        if (this.func.returnType.baseType is null)
        {
            throw new Exception("Function " ~ this.func.name ~
                    " must have a return type");
        }

        if (this.func.targetName.length == 0)
        {
            this.func.targetName = this.func.name;
        }

        // Auto-generate if not provided
        this.generate();

        this.moduleBuilder.addCompleteFunction(this.func);
        return this.moduleBuilder;
    }
}
