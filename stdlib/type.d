module stdlib.type;

import std.to;

pragma(mangle, "type_texto")
extern (D) string type_texto(long n)
{
    return to!string(n);
}

pragma(mangle, "type_texto")
extern (D) string type_texto(string n)
{
    return to!string(n);
}

pragma(mangle, "type_texto")
extern (D) string type_texto(double n)
{
    return to!string(n);
}
