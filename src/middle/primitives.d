module middle.primitives;

import std.format;
import frontend.values;
import frontend.parser.ftype_info;

// "String".tamanho -> string_tamanho("String")

// Primitive
// string
// métodos|propriedades

struct PrimitiveProperty
{
    string name; // tamanho, substr, ...
    FTypeInfo type; // string
    string mangle; // string_tamanho, ...
    FTypeInfo[] args; // types -> [int, string, ...]
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
            if (args[i].isArray)
                args_ ~= cast(string) args[i].baseType ~ "[]";
            else
                args_ ~= cast(string) args[i].baseType;
            if (i + 1 < args.length)
                args_ ~= ", ";
        }
        code ~= format("extern(D) %s %s(%s);", type.isArray ? cast(string) type.baseType ~ "[]" : cast(
                string) type.baseType, mangle, args_);
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
        str_properties["tamanho"] = PrimitiveProperty("tamanho", createTypeInfo("long"), "string_tamanho", [
                createTypeInfo("string")
            ], 1);
        str_properties["substituir"] = PrimitiveProperty("substituir", createTypeInfo("string"), "string_substituir", [
                createTypeInfo("string"), createTypeInfo("string"),
                createTypeInfo("string")
            ], 1);
        str_properties["dividir"] = PrimitiveProperty("dividir", createArrayType(TypesNative.STRING), "string_dividir",
            [
                createTypeInfo("string"), createTypeInfo("string")
            ], 1);

        Primitive str = Primitive("string", str_properties);
        primitives["string"] = str;

        // Long
        PrimitiveProperty[string] long_properties;
        long_properties["tamanho"] = PrimitiveProperty("tamanho", createTypeInfo("long"), "long_tamanho", [
                createTypeInfo("long")
            ], 1);
        Primitive lng = Primitive("long", long_properties);
        primitives["long"] = lng;

        // Vetores
        PrimitiveProperty[string] arr_properties;
        arr_properties["tamanho"] = PrimitiveProperty("tamanho", createTypeInfo("long"), "array_tamanho", [
                createArrayType(TypesNative.ID)
            ], 1);
        Primitive arr = Primitive("array", arr_properties);
        primitives["array"] = arr;
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
