module frontend.lexer.token;

import std.variant;

// Token type
enum TokenType
{
    // Keywords
    VAR, // var
    FALSE, // false 
    TRUE, // true

    IDENTIFIER, // x

    // Types
    STRING, // "omg"
    INT, // 10
    FLOAT, // 10.1
    NULL, // null
    BOOL, // true | false

    // Symbols
    EQUALS, // =
    PLUS, // +
    INCREMENT, // ++
    MINUS, // -
    DECREMENT, // --
    SLASH, // /
    ASTERISK, // *
    EXPONENTIATION, // **
    MODULO, // %
    REMAINDER, // %%
    EQUALS_EQUALS, // ==
    NOT_EQUALS, // !=
    GREATER_THAN, // >
    LESS_THAN, // <
    GREATER_THAN_OR_EQUALS, // >= 
    LESS_THAN_OR_EQUALS, // <= 
    AND, // &&
    OR, // ||
    PIPE, // | // var x: <T> | <T> = <EXPR>
    COMMA, // ,
    COLON, // :
    SEMICOLON, // ;
    DOT, // .
    LPAREN, // (
    RPAREN, // )
    LBRACE, // {
    RBRACE, // }
    LBRACKET, // [ 
    RBRACKET, // ] 
    NOT, // ] 
    RANGE, // ..
    AMPERSAND, // &
    BANG, // ! 
    QUESTION, // ? 

    EOF, // EndOfFile 47
}

// Loc from Token
struct Loc
{
    string file;
    ulong line;
    ulong start;
    ulong end;
    string dir;
}

// Token
struct Token
{
    TokenType kind;
    Variant value;
    Loc loc;

    this(TokenType kind, Variant value, Loc loc)
    {
        this.kind = kind;
        this.value = value;
        this.loc = loc;
    }

    void print()
    {
        import std.stdio : writeln;
        import std.format : format;

        writeln(format("Token Kind: %s", this.kind));
        writeln(format("Token value: %s", this.value.get!string));
        writeln(format("Token loc: %s", this.loc.line));
        writeln("---------------------------------------------\n");
    }
}

TokenType[string] keywords;

shared static this()
{
    keywords["var"] = TokenType.VAR;
    keywords["false"] = TokenType.FALSE;
    keywords["true"] = TokenType.TRUE;
    keywords["bool"] = TokenType.BOOL;
}

bool isTypeToken(Token token)
{
    import std.conv : to;

    if (token.kind != TokenType.IDENTIFIER)
        return false;

    static immutable bool[string] typeKeywords = [
        "int": true,
        "float": true,
        "string": true,
        "bool": true,
        "void": true,
        "null": true,
    ];

    try
    {
        string tokenValue = token.value.get!string;
        return (tokenValue in typeKeywords) !is null;
    }
    catch (Exception e)
    {
        return false;
    }
}

bool isComplexTypeToken(Token token)
{
    switch (token.kind)
    {
    case TokenType.ASTERISK:
    case TokenType.LBRACKET:
    case TokenType.RBRACKET:
    case TokenType.AMPERSAND:
        return true;
    default:
        return false;
    }
}
