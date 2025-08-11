module frontend.lexer.lexer;

import std.variant;
import std.stdio;
import std.conv;
import std.string;
import std.ascii : toLower;

import frontend.lexer.token;

class Lexer
{
private:
    string source;
    string file;
    string dir;

    ulong line = 1;
    ulong offset = 0;
    ulong lineOffset = 0;
    ulong start = 1;
    Token[] tokens = [];

    // Estaticos e imutaveis
    static immutable TokenType[string] SINGLE_CHAR_TOKENS = initSingleCharTokens();
    static immutable TokenType[string] MULTI_CHAR_TOKENS = initMultiCharTokens();
    static immutable bool[char] ALPHA_CHARS = initCharSet(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_áÁãÃâÂàÀéÉêÊíÍóÓõÕôÔúÚçÇ");
    static immutable bool[char] DIGIT_CHARS = initCharSet("0123456789");
    static immutable bool[char] HEX_CHARS = initCharSet("0123456789abcdefABCDEF");
    static immutable bool[char] OCTAL_CHARS = initCharSet("01234567");
    static immutable bool[char] BINARY_CHARS = initCharSet("01");
    static immutable bool[char] WHITESPACE_CHARS = initCharSet(" \t\r");

    static TokenType[string] initSingleCharTokens()
    {
        TokenType[string] m;
        m["+"] = TokenType.PLUS;
        m["-"] = TokenType.MINUS;
        m["*"] = TokenType.ASTERISK;
        m["/"] = TokenType.SLASH;
        m[">"] = TokenType.GREATER_THAN;
        m["<"] = TokenType.LESS_THAN;
        m[","] = TokenType.COMMA;
        m[";"] = TokenType.SEMICOLON;
        m[":"] = TokenType.COLON;
        m["("] = TokenType.LPAREN;
        m[")"] = TokenType.RPAREN;
        m["{"] = TokenType.LBRACE;
        m["}"] = TokenType.RBRACE;
        m["."] = TokenType.DOT;
        m["%"] = TokenType.MODULO;
        m["|"] = TokenType.PIPE;
        m["="] = TokenType.EQUALS;
        m["["] = TokenType.LBRACKET;
        m["]"] = TokenType.RBRACKET;
        m["!"] = TokenType.BANG;
        m["&"] = TokenType.AMPERSAND;
        m["?"] = TokenType.QUESTION;
        return m;
    }

    static TokenType[string] initMultiCharTokens()
    {
        TokenType[string] m;
        m["++"] = TokenType.INCREMENT;
        m["--"] = TokenType.DECREMENT;
        m["**"] = TokenType.EXPONENTIATION;
        m["%%"] = TokenType.REMAINDER;
        m["=="] = TokenType.EQUALS_EQUALS;
        m[">="] = TokenType.GREATER_THAN_OR_EQUALS;
        m["<="] = TokenType.LESS_THAN_OR_EQUALS;
        m["&&"] = TokenType.AND;
        m["||"] = TokenType.OR;
        m["!="] = TokenType.NOT_EQUALS;
        m[".."] = TokenType.RANGE;
        return m;
    }

    static bool[char] initCharSet(string chars)
    {
        bool[char] set;
        foreach (c; chars)
        {
            set[c] = true;
        }
        return set;
    }

    Loc getLocation(ulong start, ulong end, ulong line = 0)
    {
        ulong currentLine = line == 0 ? this.line : line;
        return Loc(
            this.file,
            currentLine,
            start,
            end,
            this.dir
        );
    }

    Token createToken(TokenType kind, Variant value, ulong skipChars = 1)
    {
        auto valueLength = to!string(value).length;
        Token token = Token(kind, value, this.getLocation(this.start, cast(ulong) this.start + valueLength));
        this.tokens ~= token;
        this.offset += skipChars;
        return token;
    }

    void createTokenWithLocation(TokenType kind, Variant value, ulong start, ulong length)
    {
        this.tokens ~= Token(
            kind,
            value,
            this.getLocation(start, start + length)
        );
    }

    void lexHexadecimal(ulong startPos)
    {
        this.offset += 2; // Skip "0x" or "0X"
        const hexDigits = this.consumeHexDigits();

        if (hexDigits.length == 0)
        {
            // this.reportError(
            //     this.getLocation(startPos, this.offset),
            //     "Invalid hexadecimal number: missing digits after '0x'",
            //     "Add hexadecimal digits (0-9, a-f, A-F) after '0x'.",
            // );
            throw new Exception("Invalid hexadecimal number: missing digits after '0x'");
        }

        auto fullHex = "0x" ~ hexDigits;
        int value = to!int(hexDigits);

        this.createTokenWithLocation(
            TokenType.INT,
            Variant(value),
            startPos,
            fullHex.length,
        );
    }

    void lexOctal(ulong startPos)
    {
        this.offset += 2; // Skip "0o" or "0O"
        const octalDigits = this.consumeOctalDigits();

        if (octalDigits.length == 0)
        {
            // this.reportError(
            //     this.getLocation(startPos, this.offset),
            //     "Invalid octal number: missing digits after '0o'",
            //     "Add octal digits (0-7) after '0o'.",
            // );
            throw new Exception("Invalid octal number: missing digits after '0o'");
        }

        auto fullOctal = "0o" ~ octalDigits;
        int value = to!int(octalDigits);

        this.createTokenWithLocation(
            TokenType.INT,
            Variant(value),
            startPos,
            fullOctal.length,
        );
    }

    void lexBinaryWithPrefix(ulong startPos)
    {
        this.offset += 2; // Skip "0b" or "0B"
        const binaryDigits = this.consumeBinaryDigits();

        if (binaryDigits.length == 0)
        {
            // this.reportError(
            //     this.getLocation(startPos, this.offset),
            //     "Invalid binary number: missing digits after '0b'",
            //     "Add binary digits (0-1) after '0b'.",
            // );
            throw new Exception("Invalid binary number: missing digits after '0b'");
        }

        auto fullBinary = "0b" ~ binaryDigits;
        int value = to!int(binaryDigits);

        this.createTokenWithLocation(
            TokenType.INT,
            Variant(value),
            startPos,
            fullBinary.length,
        );
    }

    bool lexString()
    {
        string value = ""; // Buffer
        this.offset++; // Skip opening quote

        while (
            this.offset < this.source.length && this.source[this.offset] != '"' && this.source[this.offset] != '\''
            )
        {
            char ch = this.source[this.offset];

            // Handle escape sequences
            if (ch == '\\')
            {
                this.offset++;
                if (this.offset >= this.source.length)
                    break;

                value ~= this.getEscapedChar(this.source[this.offset]);
            }
            else
            {
                value ~= ch;
            }

            this.offset++;
        }

        // Check for unclosed string
        if (this.offset >= this.source.length || this.source[this.offset] != '"' && this.source[this.offset] != '\'')
        {
            // this.reportError(
            //     this.getLocation(startPos, this.start + value.length + 1),
            //     "String not closed",
            //     "Add '\"' at the end of the desired string.",
            // );
            throw new Error("String not closed");
        }

        this.createToken(
            TokenType.STRING,
            Variant(value),
        );

        return true;
    }

    char getEscapedChar(char ch)
    {
        switch (ch)
        {
        case 'n':
            return '\n';
        case 't':
            return '\t';
        case 'r':
            return '\r';
        case '\\':
            return '\\';
        case '\'':
            return '\'';
        case '0':
            return '\0';
        default:
            return ch;
        }
    }

    bool lexComment()
    {
        this.offset++; // Skip the first '/'

        if (this.source[this.offset] == '/')
        {
            this.offset++;
            while (this.offset < this.source.length && this.source[this.offset] != '\n')
            {
                this.offset++;
            }
            return true;
        }

        if (this.source[this.offset] == '*')
        {
            // Multiple-line block comment
            this.offset++;

            while (this.offset + 1 < this.source.length)
            {
                if (this.source[this.offset] == '*' &&
                    this.source[this.offset + 1] == '/')
                {
                    this.offset += 2;
                    return true;
                }

                if (this.source[this.offset] == '\n')
                {
                    this.line++;
                    this.lineOffset = this.offset + 1;
                }
                this.offset++;
            }
            // Error
            throw new Exception("Unclosed block comment");
        }

        this.offset--;
        return false;
    }

    void lexIdentifier()
    {
        const ulong startOffset = this.offset;

        while (this.offset < this.source.length)
        {
            char c = this.source[this.offset];
            if (!(c in this.ALPHA_CHARS) && !(c in this.DIGIT_CHARS))
            {
                break;
            }
            this.offset++;
        }

        string identifier = this.source[startOffset .. this.offset];
        TokenType tokenType = TokenType.IDENTIFIER;
        if (auto keywordType = identifier in keywords) // Verificação segura
        {
            tokenType = *keywordType;
        }

        this.createTokenWithLocation(tokenType, Variant(identifier), startOffset - this.lineOffset, identifier
                .length);
    }

    bool lexSingleCharToken()
    {
        string currentChar = this.source[this.offset .. this.offset + 1];

        if (auto tokenType = currentChar in SINGLE_CHAR_TOKENS)
        {
            this.createToken(*tokenType, Variant(currentChar));
            return true;
        }
        return false;
    }

    bool lexMultiCharToken()
    {
        if (this.offset + 1 >= this.source.length)
            return false;

        string twoChars = this.source[this.offset .. this.offset + 2];

        if (auto tokenType = twoChars in MULTI_CHAR_TOKENS)
        {
            this.createToken(*tokenType, Variant(twoChars), 2);
            return true;
        }
        return false;
    }

    string consumeDigits()
    {
        ulong _start = this.offset;
        while (this.offset < this.source.length && this.source[this.offset] in this.DIGIT_CHARS)
        {
            this.offset++;
        }
        return this.source[_start .. this.offset];
    }

    string consumeHexDigits()
    {
        ulong _start = this.offset;
        while (this.offset < this.source.length && this.source[this.offset] in this.HEX_CHARS)
        {
            this.offset++;
        }
        return this.source[_start .. this.offset];
    }

    string consumeOctalDigits()
    {
        ulong _start = this.offset;
        while (this.offset < this.source.length && this.source[this.offset] in this.OCTAL_CHARS)
        {
            this.offset++;
        }
        return this.source[_start .. this.offset];
    }

    string consumeBinaryDigits()
    {
        ulong _start = this.offset;
        while (this.offset < this.source.length && this.source[this.offset] in this.BINARY_CHARS)
        {
            this.offset++;
        }
        return this.source[_start .. this.offset];
    }

    void lexNumber()
    {
        ulong startPos = this.offset;

        if (
            this.source[this.offset] == '0' && this.offset + 1 < this.source.length
            )
        {
            const prefix = toLower(this.source[this.offset + 1]);

            // Hexadecimal (0x or 0X)
            if (prefix == 'x')
            {
                this.lexHexadecimal(startPos);
                return;
            }

            // Octal (0o or 0O)
            if (prefix == 'o')
            {
                this.lexOctal(startPos);
                return;
            }

            // Binary (0b or 0B)
            if (prefix == 'b')
            {
                this.lexBinaryWithPrefix(startPos);
                return;
            }
        }

        string number = this.consumeDigits();

        // Handle range operator (e.g., 123..456)
        if (this.source[2 .. this.offset] == "..")
        {
            this.createTokenWithLocation(
                TokenType.INT,
                Variant(number),
                startPos,
                number.length,
            );
            this.createToken(TokenType.RANGE, Variant(".."), 2);
            return;
        }

        // Handle floating point numbers
        if (this.offset < this.source.length && this.source[this.offset] == '.')
        {
            const nextChar = this.source[this.offset + 1];
            if (nextChar in this.DIGIT_CHARS)
            {
                number ~= ".";
                this.offset++;
                number ~= this.consumeDigits();

                this.createTokenWithLocation(
                    TokenType.FLOAT,
                    Variant(number),
                    startPos,
                    number.length,
                );
                return;
            }
        }

        // Handle binary literals with suffix (e.g., 101b)
        if (
            this.offset < this.source.length &&
            toLower(this.source[this.offset]) == 'b'
            )
        {
            this.offset++;
            string binaryValue = number ~ "b";

            this.createTokenWithLocation(
                TokenType.INT,
                Variant(binaryValue),
                startPos,
                binaryValue.length,
            );
            return;
        }

        this.createTokenWithLocation(
            TokenType.INT,
            Variant(number),
            startPos,
            number.length,
        );
    }

public:
    this(string file, string source, string dir)
    {
        this.file = file;
        this.source = source;
        this.dir = dir;
    }

    Token[] tokenize(bool ignoreNewLine = false)
    {
        try
        {
            ulong sourceLength = cast(ulong) this.source.length;

            while (this.offset < sourceLength)
            {
                this.start = this.offset - this.lineOffset;
                char c = this.source[this.offset];

                if (c == '\n')
                {
                    if (ignoreNewLine)
                    {
                        this.offset++;
                        continue;
                    }
                    this.line++;
                    this.offset++;
                    this.lineOffset = this.offset;
                    continue;
                }

                if (c in this.WHITESPACE_CHARS)
                {
                    this.offset++;
                    continue;
                }

                if (c == '/' && this.offset + 1 < sourceLength)
                {
                    char nextChar = this.source[this.offset + 1];
                    if (nextChar == '/' || nextChar == '*')
                    {
                        if (!this.lexComment())
                        {
                            if (!this.lexSingleCharToken())
                            {
                                throw new Exception("Unexpected character: " ~ c);
                            }
                        }
                        continue;
                    }
                }

                // Handle string literals
                if (c == '"' || c == '\'')
                {
                    if (!this.lexString())
                        return null; // Error
                    continue;
                }

                if (c in this.ALPHA_CHARS)
                {
                    this.lexIdentifier();
                    continue;
                }

                if (c in this.DIGIT_CHARS)
                {
                    this.lexNumber();
                    continue;
                }

                if (this.lexMultiCharToken())
                {
                    continue;
                }

                if (this.lexSingleCharToken())
                {
                    continue;
                }

                throw new Exception(
                    "Unexpected character: '" ~ c ~ "' at line " ~ to!string(this.line));
            }

            this.createToken(TokenType.EOF, Variant("\0"), 0);
            return this.tokens;
        }
        catch (Exception e)
        {
            writeln("Lexer error: ", e.msg);
            throw e;
        }
    }
}
