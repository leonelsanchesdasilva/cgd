module frontend.lexer.token;

import std.variant;

// Token type
enum TokenType
{
    // Keywords
    VAR, // var
    FALSE, // false 
    TRUE, // true
    SUSTAR, // sustar
    DO, // faça/faca
    CASO, // caso
    SENAO, // senão/senao
    CONTINUE, // continue
    PARA, // para
    ESCOLHA, // escolha
    ENQUANTO, // enquanto
    PADRAO, // padrão/padrao
    SE, // se
    FALHAR, // falhar
    TENTE, // tente
    FINALMENTE, // finalmente
    INSTANCEOF, // instanceof
    TYPEOF, // typeof
    NOVO, // novo
    PEGUE, // pegue
    RETORNA, // retorna/retorne
    VAZIO, // vazio
    DEBUGGER, // debugger
    FUNCAO, // função/funcao
    ISTO, // isto
    COM, // com
    EXCLUIR, // excluir
    EM, // em
    COMO, // como
    DE, // de

    // Future Reserved Words
    CLASSE, // classe
    ENUM, // enum
    EXTENDE, // estende
    SUPER, // super
    CONST, // const
    EXPORTAR, // exportar
    IMPORTAR, // importar

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

    EOF, // EndOfFile
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
    keywords["falso"] = TokenType.FALSE;
    keywords["verdadeiro"] = TokenType.TRUE;
    keywords["true"] = TokenType.TRUE;
    keywords["bool"] = TokenType.BOOL;
    keywords["sustar"] = TokenType.SUSTAR;
    keywords["faca"] = TokenType.DO;
    keywords["faça"] = TokenType.DO;
    keywords["caso"] = TokenType.CASO;
    keywords["senao"] = TokenType.SENAO;
    keywords["senão"] = TokenType.SENAO;
    keywords["continue"] = TokenType.CONTINUE;
    keywords["para"] = TokenType.PARA;
    keywords["escolha"] = TokenType.ESCOLHA;
    keywords["enquanto"] = TokenType.ENQUANTO;
    keywords["padrao"] = TokenType.PADRAO;
    keywords["padrão"] = TokenType.PADRAO;
    keywords["se"] = TokenType.SE;
    keywords["falhar"] = TokenType.FALHAR;
    keywords["tente"] = TokenType.TENTE;
    keywords["finalmente"] = TokenType.FINALMENTE;
    keywords["instanceof"] = TokenType.INSTANCEOF;
    keywords["typeof"] = TokenType.TYPEOF;
    keywords["novo"] = TokenType.NOVO;
    keywords["pegue"] = TokenType.PEGUE;
    keywords["retorna"] = TokenType.RETORNA;
    keywords["retorne"] = TokenType.RETORNA;
    keywords["vazio"] = TokenType.VAZIO;
    keywords["debugger"] = TokenType.DEBUGGER;
    keywords["funcao"] = TokenType.FUNCAO;
    keywords["função"] = TokenType.FUNCAO;
    keywords["isto"] = TokenType.ISTO;
    keywords["com"] = TokenType.COM;
    keywords["excluir"] = TokenType.EXCLUIR;
    keywords["em"] = TokenType.EM;
    keywords["como"] = TokenType.COMO;
    keywords["de"] = TokenType.DE;

    // Future Reserved Words
    keywords["classe"] = TokenType.CLASSE;
    keywords["enum"] = TokenType.ENUM;
    keywords["estende"] = TokenType.EXTENDE;
    keywords["super"] = TokenType.SUPER;
    keywords["const"] = TokenType.CONST;
    keywords["exportar"] = TokenType.EXPORTAR;
    keywords["importar"] = TokenType.IMPORTAR;
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
        "vazio": true, // Added Portuguese equivalent for void
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
