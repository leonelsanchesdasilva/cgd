module frontend.parser.parser;

import std.algorithm;
import std.stdio;
import std.conv;
import std.variant;
import frontend.lexer.token;
import frontend.values;
import frontend.parser.ftype_info;
import frontend.parser.ast;
import frontend.parser.parse_type;

enum Precedence
{
    LOWEST = 1,
    ASSIGN = 2, // =
    TERNARY = 3, // ? :
    OR = 4, // ||
    AND = 5, // &&
    EQUALS = 6, // == !=
    COMPARISON = 7, // < > <= >=
    SUM = 8, // + -
    PRODUCT = 9, // * / %
    EXPONENT = 10, // **
    PREFIX = 11, // -x !x
    CALL = 12, // myFunction(x)
}

class Parser
{
private:
    Token[] tokens;
    ulong pos = 0;

    Stmt parsePrefix()
    {
        Token token = this.advance();

        switch (token.kind)
        {
            // Literals
        case TokenType.INT:
            return new IntLiteral(to!int(token.value.get!string), token.loc);
        case TokenType.FLOAT:
            return new FloatLiteral(to!float(token.value.get!string), token.loc);
        case TokenType.STRING:
            return new StringLiteral(token.value.get!string, token.loc);
        case TokenType.TRUE:
            return new BoolLiteral(true, token.loc);
        case TokenType.FALSE:
            return new BoolLiteral(false, token.loc);
        case TokenType.NULL:
            return new NullLiteral(token.loc);

        case TokenType.LPAREN:
            return this.parseGroupedExpression();

        case TokenType.MINUS:
            Stmt operand = this.parseExpression(Precedence.LOWEST);
            return new UnaryExpr("-", operand, this.makeLoc(token.loc, operand.loc));

        case TokenType.PLUS:
            Stmt operand = this.parseExpression(Precedence.LOWEST);
            return new UnaryExpr("+", operand, this.makeLoc(token.loc, operand.loc));

            // Keywords
        case TokenType.VAR:
            return parseVarDeclaration();

            // Others
        case TokenType.IDENTIFIER:
            if (this.peek()
                .kind == TokenType.LPAREN)
                return this.parseCallExpression();
            return new Identifier(token.value.get!string, token.loc);

        default:
            token.print();
            throw new Exception("No prefix parse function for " ~ to!string(token));
        }
    }

    Stmt parseCallExpression()
    {
        Token calle = this.previous();
        this.advance(); // skip '('
        Stmt[] args = [];
        if (!this.check(TokenType.RPAREN))
        {
            do
            {
                args ~= this.parseExpression(Precedence.LOWEST);
            }
            while (this.match([TokenType.COMMA]));
        }
        this.consume(TokenType.RPAREN, "Experava-se '}' após os argumentos.");
        return new CallExpr(new Identifier(calle.value.get!string, calle.loc), args, calle.loc);
    }

    Stmt parseVarDeclaration()
    {
        Token id = this.consume(TokenType.IDENTIFIER, "Esperava-se um ID para o nome da variavel.");

        if (this.match([TokenType.COMMA]))
        {
            // TODO: Suporte a multiplas declarações
        }

        if (this.match([TokenType.COLON]))
        {
            // TODO: Suporte a tipagem
        }

        if (this.match([TokenType.SEMICOLON]))
        {
            // TODO: Suporte a variavel não inicializada
        }

        this.consume(TokenType.EQUALS, "Esperava-se '=' após a declaração da variavel.");
        Stmt value = this.parseExpression(Precedence.LOWEST);

        return new VariableDeclaration(new Identifier(id.value.get!string, id.loc), value, value.type, true, id
                .loc);
    }

    Stmt parseCastExpression()
    {
        Loc startLoc = this.previous().loc;
        ulong savedPos = this.pos - 1;

        Token[] typeTokens;
        ulong nestingLevel = 0;
        bool foundClosingParen = false;
        bool hasOperators = false;

        while (!this.isAtEnd())
        {
            if (this.check(TokenType.LPAREN))
            {
                nestingLevel++;
            }
            else if (this.check(TokenType.RPAREN))
            {
                if (nestingLevel == 0)
                {
                    foundClosingParen = true;
                    break;
                }
                nestingLevel--;
            }
            else if (
                this.check(TokenType.PLUS) ||
                this.check(TokenType.MINUS) ||
                this.check(TokenType.SLASH) ||
                this.check(TokenType.MODULO) ||
                this.check(TokenType.REMAINDER) ||
                this.check(TokenType.EXPONENTIATION) ||
                this.check(TokenType.EQUALS_EQUALS) ||
                this.check(TokenType.NOT_EQUALS) ||
                this.check(TokenType.GREATER_THAN) ||
                this.check(TokenType.LESS_THAN)
                )
            {
                hasOperators = true;
                break;
            }

            typeTokens ~= this.advance();
        }

        if (!foundClosingParen || hasOperators)
        {
            this.pos = savedPos;
            this.advance(); // Consome o LPAREN
            Stmt expr = this.parseExpression(Precedence.LOWEST);
            this.consume(TokenType.RPAREN, "Expect ')' after expression.");
            return expr;
        }

        this.consume(TokenType.RPAREN, "Expect ')' after type cast.");

        bool nextTokenIsValidCastTarget =
            this.peek().kind == TokenType.IDENTIFIER ||
            this.peek()
            .kind == TokenType.INT ||
            this.peek().kind == TokenType.FLOAT ||
            this.peek().kind == TokenType.STRING ||
            this.peek()
            .kind == TokenType.AMPERSAND ||
            this.peek()
            .kind == TokenType.ASTERISK ||
            this.peek().kind == TokenType.LPAREN;

        if (!nextTokenIsValidCastTarget)
        {
            this.pos = savedPos;
            this.advance(); // Consome o LPAREN
            Stmt expr = this.parseExpression(Precedence.LOWEST);
            this.consume(TokenType.RPAREN, "Expect ')' after expression.");
            return expr;
        }

        if (!this.isValidTypeSequence(typeTokens))
        {
            this.pos = savedPos;
            this.advance(); // Consome o LPAREN
            Stmt expr = this.parseExpression(Precedence.LOWEST);
            this.consume(TokenType.RPAREN, "Expect ')' after expression.");
            return expr;
        }

        try
        {
            FTypeInfo castType = new ParseType(typeTokens).parse();
            Stmt expr = this.parseExpression(Precedence.PREFIX);
            return new CastExpr(castType, expr, this.makeLoc(startLoc, expr.loc));
        }
        catch (Exception e)
        {
            this.pos = savedPos;
            this.advance(); // Consome o LPAREN
            Stmt expr = this.parseExpression(Precedence.LOWEST);
            this.consume(TokenType.RPAREN, "Expect ')' after expression.");
            return expr;
        }
    }

    bool isValidTypeSequence(ref Token[] tokens)
    {
        if (tokens.length == 0)
            return false;

        if (tokens.length == 1)
        {
            return tokens[0].kind == TokenType.IDENTIFIER ||
                tokens[0].kind == TokenType.INT ||
                tokens[0].kind == TokenType.FLOAT ||
                tokens[0].kind == TokenType.STRING;
        }

        ulong position = 0;
        return parseTypeHelper(tokens, position) && position == tokens.length;
    }

    bool parseTypeHelper(ref Token[] tokens, ref ulong pos)
    {
        if (pos >= tokens.length)
            return false;

        if (tokens[pos].kind != TokenType.IDENTIFIER)
            return false;

        pos++;

        while (pos < tokens.length && tokens[pos].kind == TokenType.ASTERISK)
        {
            pos++;
        }

        while (pos + 1 < tokens.length &&
            tokens[pos].kind == TokenType.LBRACKET &&
            tokens[pos + 1].kind == TokenType.RBRACKET)
        {
            pos += 2;
        }

        return true;
    }

    Stmt parseGroupedExpression()
    {
        Stmt expr = this.parseExpression(Precedence.LOWEST);
        this.consume(TokenType.RPAREN, "Expect ')' after expression.");
        return expr;
    }

    Stmt parseBinaryInfix(Stmt left)
    {
        this.advance();
        Token operatorToken = this.previous();

        Precedence precedence = this.getPrecedence(operatorToken.kind);
        Stmt right = this.parseExpression(precedence);
        FTypeInfo type = this.inferType(left, right);

        BinaryExpr node = new BinaryExpr(left, right, operatorToken.value.get!string, this.makeLoc(left.loc, right
                .loc));
        node.type = type;
        return node;
    }

    void infix(ref Stmt leftOld)
    {
        switch (this.peek().kind)
        {
        case TokenType.PLUS:
        case TokenType.MINUS:
        case TokenType.SLASH:
        case TokenType.ASTERISK:
        case TokenType.EXPONENTIATION:
        case TokenType.MODULO:
        case TokenType.REMAINDER:
        case TokenType.EQUALS_EQUALS:
        case TokenType.NOT_EQUALS:
        case TokenType.GREATER_THAN:
        case TokenType.LESS_THAN:
        case TokenType.GREATER_THAN_OR_EQUALS:
        case TokenType.LESS_THAN_OR_EQUALS:
        case TokenType.AND:
        case TokenType.OR:
            leftOld = this.parseBinaryInfix(leftOld);
            return;
        default:
            return;
        }
    }

    Stmt parseExpression(Precedence precedence)
    {
        Stmt left = this.parsePrefix();

        while (!this.isAtEnd() && precedence < this.peekPrecedence())
        {
            // writeln("Token: ", this.peek(), " Precedence: ", precedence, " Precedence peek: ", this.peekPrecedence(),
            //     " Left: ", left, " Left value: ", left.value);

            ulong oldPos = this.pos;
            this.infix(left);

            if (this.pos == oldPos)
            {
                // writeln("AVISO: Token não processado pela infix(): ", this.peek());
                break;
            }
        }

        return left;
    }

    Stmt parseStmt()
    {
        Stmt stmt = this.parseExpression(Precedence.LOWEST);
        this.match([TokenType.SEMICOLON]);
        return stmt;
    }

public:
    this(Token[] tokens = [])
    {
        this.tokens = tokens;
    }

    Program parse()
    {
        Program program = new Program([]);
        program.type = createTypeInfo(TypesNative.NULL);
        program.value = null;

        try
        {
            while (!this.isAtEnd())
            {
                program.body ~= this.parseStmt();
            }

            if (this.tokens.length == 0)
            {
                return program;
            }

            program.loc = this.makeLoc(this.tokens[0].loc, this
                    .tokens[$ - 1].loc);
        }
        catch (Exception e)
        {

            writeln("Erro:", e.msg);
            throw e;
        }

        return program;
    }

    // Helpers
private:
    bool isAtEnd()
    {
        return this.peek().kind == TokenType.EOF;
    }

    Variant next()
    {
        if (this.isAtEnd())
            return Variant(false);
        return Variant(this.tokens[this.pos + 1]);
    }

    Token peek()
    {
        return this.tokens[this.pos];
    }

    Token previous(ulong i = 1)
    {
        return this.tokens[this.pos - i];
    }

    Token advance()
    {
        if (!this.isAtEnd())
            this.pos++;
        return this.previous();
    }

    bool match(TokenType[] kinds)
    {
        foreach (kind; kinds)
        {
            if (this.check(kind))
            {
                this.advance();
                return true;
            }
        }
        return false;
    }

    bool check(TokenType kind)
    {
        if (this.isAtEnd())
            return false;
        return this.peek().kind == kind;
    }

    Token consume(TokenType expected, string message)
    {
        if (this.check(expected))
            return this.advance();
        const token = this.peek();
        throw new Error(`Erro de parsing: ${message}`);
    }

    Precedence getPrecedence(TokenType kind)
    {
        switch (kind)
        {
        case TokenType.EQUALS:
            return Precedence.ASSIGN;
        case TokenType.QUESTION:
            return Precedence.TERNARY;
        case TokenType.OR:
            return Precedence.OR;
        case TokenType.AND:
            return Precedence.AND;
        case TokenType.EQUALS_EQUALS:
        case TokenType.NOT_EQUALS:
            return Precedence.EQUALS;
        case TokenType.LESS_THAN:
        case TokenType.GREATER_THAN:
        case TokenType.LESS_THAN_OR_EQUALS:
        case TokenType.GREATER_THAN_OR_EQUALS:
            return Precedence.COMPARISON;
        case TokenType.PLUS:
        case TokenType.MINUS:
            return Precedence.SUM;
        case TokenType.SLASH:
        case TokenType.ASTERISK:
        case TokenType.MODULO:
        case TokenType.REMAINDER:
            return Precedence.PRODUCT;
        case TokenType.EXPONENTIATION:
            return Precedence.EXPONENT;
        case TokenType.LPAREN:
            return Precedence.CALL;
        default:
            return Precedence.LOWEST;
        }
    }

    Precedence peekPrecedence()
    {
        return this.getPrecedence(this.peek().kind);
    }

    FTypeInfo inferType(Stmt left, Stmt right)
    {
        if (left.type.baseType == "string" || right.type.baseType == "string")
        {
            return createTypeInfo(TypesNative.STRING);
        }

        if (left.type.baseType == "float" || right.type.baseType == "float")
        {
            return createTypeInfo(TypesNative.FLOAT);
        }
        return createTypeInfo(TypesNative.INT);
    }

    Loc makeLoc(ref Loc start, ref Loc end)
    {
        return Loc(start.file, start.line, start.start, end.end, start.dir);
    }
}
