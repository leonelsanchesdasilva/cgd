module frontend.values;

enum TypesNative : string
{
    STRING = "string",
    INT = "long",
    LONG = "long",
    FLOAT = "double",
    BOOL = "bool",
    VOID = "void",
    CHAR = "char",
    NULL = "null",
    ID = "auto",
    CLASS = "class",
    T = "T"
}

unittest
{
    import std.stdio;
    writeln("Testando TypesNative...");

    assert(TypesNative.STRING == "string");
    assert(TypesNative.INT == "long");
    assert(TypesNative.LONG == "long");
    assert(TypesNative.FLOAT == "double");
    assert(TypesNative.BOOL == "bool");
    assert(TypesNative.VOID == "void");
    assert(TypesNative.CHAR == "char");
    assert(TypesNative.NULL == "null");
    assert(TypesNative.ID == "auto");
    assert(TypesNative.CLASS == "class");
    assert(TypesNative.T == "T");

    writeln("✓ Testes de TypesNative passaram!");
}
