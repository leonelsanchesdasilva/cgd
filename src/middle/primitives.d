module middle.primitives;

import std.format;

// "String".tamanho -> string_tamanho("String")

// Primitive
// string
// métodos|propriedades

struct PrimitiveProperty
{
    string name; // tamanho, substr, ...
    string type; // string
    string mangle; // string_tamanho, ...
    string[] args; // types -> [int, string, ...]
    long ignore; // numero de argumentos a serem ignorados. 1 by default

    string generateD()
    {
        /*
        string pragmaStr = "";
        if (this.func.libraryName.length > 0)
        {
            pragmaStr = "pragma(mangle, \"" ~ this.func.libraryName ~ "\")\n";
        }

        this.func.ir = pragmaStr ~ "extern(" ~ this.func.linkage ~ ") " ~
            returnType ~ " " ~ fnName ~ "(" ~ paramList ~ ");";

        pragma(mangle, "io_escrevaln")
        extern(D) void escrevaln(...);
        */
        string code = format("pragma(mangle, \"%s\")\n", mangle);
        string args_;
        for (long i; i < args.length; i++)
        {
            args_ ~= args[i];
            if (i + 1 < args.length)
                args_ ~= ", ";
        }
        code ~= format("extern(D) %s %s(%s);", type, mangle, args_);
        return code;
    }
}

struct Primitive
{
    string name; // string, ...
    PrimitiveProperty[string] properties; // PrimitiveProperty[...]
}

class StdPrimitive
{
private:
    Primitive[string] primitives; // baseado no tipo atual
public:
    this()
    {
        // String
        PrimitiveProperty[string] str_properties;
        str_properties["tamanho"] = PrimitiveProperty("tamanho", "long", "string_tamanho", [
                "string"
            ], 1);
        Primitive str = Primitive("string", str_properties);
        primitives["string"] = str;

        // Long
        PrimitiveProperty[string] long_properties;
        long_properties["tamanho"] = PrimitiveProperty("tamanho", "long", "long_tamanho", [
                "long"
            ], 1);
        Primitive lng = Primitive("long", long_properties);
        primitives["long"] = lng;
    }

    bool exists(string type)
    {
        return type in primitives ? true : false;
    }

    Primitive get(string type)
    {
        return primitives[type];
    }

    Primitive[string] get()
    {
        return primitives;
    }
}
