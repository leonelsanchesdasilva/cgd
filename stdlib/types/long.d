module stdlib.types._long;

import std.conv;

pragma(mangle, "long_tamanho")
extern (D) long long_tamanho(long _long)
{
    return to!string(_long).length;
}
