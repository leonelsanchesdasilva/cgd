module middle.semantic_symbol_info;

import frontend.parser.ftype_info;
import frontend.lexer.token;

struct SymbolInfo
{
    string id;
    FTypeInfo type;
    bool mutable;
    bool initialized;
    Loc loc;

    this(string id, FTypeInfo type, bool mutable, bool initialized, Loc loc)
    {
        this.id = id;
        this.type = type;
        this.mutable = mutable;
        this.initialized = initialized;
        this.loc = loc;
    }
}
