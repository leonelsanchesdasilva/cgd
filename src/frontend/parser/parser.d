module frontend.parser.parser;

import std.algorithm;
import std.format;
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
    ASSIGN = 2,
    TERNARY = 3,
    OR = 4,
    AND = 5,
    BIT_OR = 6,
    BIT_XOR = 7,
    BIT_AND = 8,
    EQUALS = 9,
    COMPARISON = 10,
    BIT_SHIFT = 11,
    SUM = 12,
    PRODUCT = 13,
    EXPONENT = 14,
    PREFIX = 15,
    POSTFIX = 16, // Nova precedência para operadores postfix
    CALL = 17, // Ajustado para ser maior que POSTFIX
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
            return new IntLiteral(token.value.get!long, token.loc);
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
        case TokenType.RETORNA:
            return this.parseReturnStatement();
        case TokenType.FUNCAO:
            return this.parseFnStatement();
        case TokenType.SE:
            return this.parseIfStatement();
        case TokenType.PARA:
            return this.parseForStatement();
        case TokenType.ENQUANTO:
            return this.parseWhileStatement();
        case TokenType.ESCOLHA:
            return this.parseSwitchStatement();
        case TokenType.QUEBRAR:
            return this.parseBreakStatement();

            // Others
        case TokenType.IDENTIFIER:
            if (this.peek()
                .kind == TokenType.LPAREN)
                return this.parseCallExpression();
            if (this.peek().kind == TokenType.EQUALS)
                return this.parseAssignmentDeclaration();

            auto identifier = new Identifier(token.value.get!string, token.loc);

            if (this.peek().kind == TokenType.DOT)
            {
                return this.parseMemberCallExpression(identifier);
            }

            return identifier;

        case TokenType.BIT_NOT:
            Stmt operand = this.parseExpression(Precedence.PREFIX);
            return new UnaryExpr("~", operand, this.makeLoc(token.loc, operand.loc));
        case TokenType.INCREMENT:
            if (this.peek().kind != TokenType.IDENTIFIER)
            {
                throw new Exception("Operador '++' prefix requer um identificador válido.");
            }
            Stmt operand = this.parseExpression(Precedence.POSTFIX);
            return new UnaryExpr("++", operand, this.makeLoc(token.loc, operand.loc), false);

        case TokenType.DECREMENT:
            if (this.peek().kind != TokenType.IDENTIFIER)
            {
                throw new Exception("Operador '--' prefix requer um identificador válido.");
            }
            Stmt operand = this.parseExpression(Precedence.POSTFIX);
            return new UnaryExpr("--", operand, this.makeLoc(token.loc, operand.loc), false);

        default:
            throw new Exception("Noo prefix parse function for " ~ to!string(token));
        }
    }

    Stmt parseSwitchStatement()
    {
        Loc start = this.previous().loc;

        // this.consume(TokenType.LPAREN, "Esperava-se '(' após 'escolha'.");
        Stmt condition = this.parseExpression(Precedence.LOWEST);
        // this.consume(TokenType.RPAREN, "Esperava-se ')' após a condição do 'escolha'.");
        this.consume(TokenType.LBRACE, "Esperava-se '{' após a condição do 'escolha'.");

        CaseStatement[] cases;
        DefaultStatement defaultCase = null;

        while (!this.check(TokenType.RBRACE) && !this.isAtEnd())
        {
            if (this.match([TokenType.CASO]))
            {
                cases ~= this.parseCaseStatement();
            }
            else if (this.match([TokenType.PADRAO]))
            {
                if (defaultCase !is null)
                {
                    throw new Exception("Apenas um caso 'padrão' é permitido por 'escolha'.");
                }
                defaultCase = this.parseDefaultStatement();
            }
            else
            {
                throw new Exception("Esperava-se 'caso' ou 'padrão' dentro de 'escolha'.");
            }
        }

        Loc end = this.consume(TokenType.RBRACE, "Esperava-se '}' após o corpo do 'escolha'.").loc;

        return new SwitchStatement(condition, cases, defaultCase, this.makeLoc(start, end));
    }

    CaseStatement parseCaseStatement()
    {
        Loc start = this.previous().loc;

        Stmt value = this.parseExpression(Precedence.LOWEST);
        this.consume(TokenType.COLON, "Esperava-se ':' após o valor do 'caso'.");

        Stmt[] body;
        while (!this.check(TokenType.CASO) && !this.check(TokenType.PADRAO) &&
            !this.check(TokenType.RBRACE) && !this.isAtEnd())
        {
            body ~= this.parseExpression(Precedence.LOWEST);
        }

        return new CaseStatement(value, body, start);
    }

    DefaultStatement parseDefaultStatement()
    {
        Loc start = this.previous().loc;

        this.consume(TokenType.COLON, "Esperava-se ':' após 'padrão'.");

        Stmt[] body;
        while (!this.check(TokenType.CASO) && !this.check(TokenType.PADRAO) &&
            !this.check(TokenType.RBRACE) && !this.isAtEnd())
        {
            body ~= this.parseExpression(Precedence.LOWEST);
        }

        return new DefaultStatement(body, start);
    }

    Stmt parseBreakStatement()
    {
        Loc start = this.previous().loc;
        return new BreakStatement(start);
    }

    Stmt parseMemberCallExpression(Stmt object)
    {
        while (this.check(TokenType.DOT))
        {
            this.advance();

            Token memberToken = this.consume(TokenType.IDENTIFIER,
                "Esperava-se um identificador após '.'.");
            Identifier member = new Identifier(memberToken.value.get!string, memberToken.loc);

            Stmt[] args = [];
            bool isMethodCall = false;

            // Verifica se é uma chamada de método (tem parênteses)
            if (this.check(TokenType.LPAREN))
            {
                this.advance();
                isMethodCall = true;

                if (!this.check(TokenType.RPAREN))
                {
                    do
                    {
                        args ~= this.parseExpression(Precedence.LOWEST);
                    }
                    while (this.match([TokenType.COMMA]));
                }

                this.consume(TokenType.RPAREN, "Esperava-se ')' após os argumentos do método.");
            }

            Loc loc = this.makeLoc(object.loc, this.previous().loc);
            object = new MemberCallExpr(object, member, args, isMethodCall, loc);
        }

        return object;
    }

    Stmt parseAssignmentDeclaration()
    {
        Token id = this.previous();
        this.consume(TokenType.EQUALS, "Esperava-se '=' após o identificador.");
        Stmt expr = this.parseExpression(Precedence.LOWEST);
        return new AssignmentDeclaration(new Identifier(id.value.get!string, id.loc), expr, expr.type, id
                .loc);
    }

    Stmt parseWhileStatement()
    {
        Loc start = this.previous().loc;
        Stmt cond = this.parseExpression(Precedence.LOWEST);

        this.consume(TokenType.LBRACE, "Esperava-se '{' após a condição do 'enquanto'.");
        Stmt[] body;

        while (!this.check(TokenType.RBRACE) && !this.isAtEnd())
        {
            body ~= this.parseExpression(Precedence.LOWEST);
        }

        Loc end = this.consume(
            TokenType.RBRACE,
            "Esperava-se '}' após o corpo do 'enquanto'.",
        ).loc;

        return new WhileStatement(cond, body, this.makeLoc(start, end));
    }

    Stmt parseForStatement()
    {
        Loc start = this.previous().loc;
        Stmt _init = this.parseExpression(Precedence.LOWEST);

        if (_init.kind != NodeType.VariableDeclaration && _init.kind != NodeType
            .AssignmentDeclaration)
            throw new Exception(
                "É esperado uma declaração ou redeclaração de variavel no inicio do 'para'.");

        this.consume(TokenType.SEMICOLON, "Esperava-se ';' antes da condição do 'para'.");
        Stmt cond = this.parseExpression(Precedence.LOWEST);

        this.consume(TokenType.SEMICOLON, "Esperava-se ';' após a condição do 'para'.");
        Stmt expr = this.parseExpression(Precedence.LOWEST);

        this.consume(TokenType.LBRACE, "Esperava-se '{' após a expressão do 'para'.");

        Stmt[] body;

        while (!this.check(TokenType.RBRACE) && !this.isAtEnd())
        {
            body ~= this.parseExpression(Precedence.LOWEST);
        }

        Loc end = this.consume(
            TokenType.RBRACE,
            "Esperava-se '}' após o bloco do 'para'.",
        ).loc;

        return new ForStatement(_init, cond, expr, body, this.makeLoc(start, end));
    }

    Stmt parseElseStatement()
    {
        Token start = this.previous();
        Stmt[] body = [];
        Stmt returnStmt = null;
        Loc end;
        bool unique = false;

        if (this.peek().kind != TokenType.LBRACE)
        {
            body ~= this.parseExpression(Precedence.LOWEST);
            end = body[0].loc;
            unique = true;
        }

        if (!unique)
        {
            this.consume(TokenType.LBRACE, "Esperava-se '{' após o 'senão'.");

            while (!this.check(TokenType.RBRACE) && !this.isAtEnd())
            {
                if (this.peek().kind == TokenType.RETORNA)
                {
                    returnStmt = this.parseExpression(Precedence.LOWEST);
                    body ~= returnStmt;
                    break;
                }
                body ~= this.parseExpression(Precedence.LOWEST);
            }
            end = this.consume(TokenType.RBRACE, "Esperava-se '}' após o corpo da condição.")
                .loc;
        }

        FTypeInfo type = returnStmt is null ? createTypeInfo(TypesNative.VOID) : returnStmt
            .type;
        Variant value = type.baseType == TypesNative.VOID ? Variant("void") : Variant(
            returnStmt.value);

        return new ElseStatement(body, type, value, this.makeLoc(start.loc, end));
    }

    Stmt parseIfStatement(bool miaKhalifa = true)
    {
        Token start = this.previous();
        Stmt condition = this.parseExpression(Precedence.LOWEST);
        Stmt[] body = [];
        Stmt returnStmt = null;
        NullStmt bodySecond = null;
        Loc end;
        bool unique = false;

        if (this.peek().kind != TokenType.LBRACE)
        {
            body ~= this.parseExpression(Precedence.LOWEST);
            end = body[0].loc;
            unique = true;
        }

        if (!unique)
        {
            this.consume(TokenType.LBRACE, "Esperava-se '{' após a condição.");

            while (!this.check(TokenType.RBRACE) && !this.isAtEnd())
            {
                if (this.peek().kind == TokenType.RETORNA)
                {
                    returnStmt = this.parseExpression(Precedence.LOWEST);
                    body ~= returnStmt;
                    break;
                }
                body ~= this.parseExpression(Precedence.LOWEST);
            }
            end = this.consume(TokenType.RBRACE, "Esperava-se '}' após o corpo da condição.")
                .loc;
        }

        if (this.match([TokenType.SENAO]))
        {
            if (this.match([TokenType.SE]))
            {
                bodySecond = this.parseIfStatement(false);
            }
            else
            {
                bodySecond = this.parseElseStatement();
            }
        }

        FTypeInfo type = returnStmt is null ? createTypeInfo(TypesNative.VOID) : returnStmt
            .type;
        Variant value = type.baseType == TypesNative.VOID ? Variant("void") : Variant(
            returnStmt.value);

        return new IfStatement(condition, body, type, value, this.makeLoc(start.loc, end), bodySecond);
    }

    Stmt parseFnStatement()
    {
        Token start = this.previous();
        Token id = this.consume(TokenType.IDENTIFIER, "Esperava-se um identificador para o nome da função.");
        FunctionArgs args = this.parseFnArguments();
        FTypeInfo returnType = createTypeInfo(TypesNative.VOID);

        if (this.match([TokenType.COLON]))
        {
            Token[] fnTokens;
            while (this.peek().kind != TokenType.LBRACE)
            {
                fnTokens ~= this.advance();
            }
            returnType = new ParseType(fnTokens).parse();
        }

        this.consume(TokenType.LBRACE, "Expect '{' before function body.");
        Stmt[] body;

        while (!this.check(TokenType.RBRACE) && !this.isAtEnd())
        {
            body ~= this.parseExpression(Precedence.LOWEST);
        }

        Token end = this.consume(
            TokenType.RBRACE,
            "Expect '}' after function body.",
        );

        return new FunctionDeclaration(new Identifier(id.value.get!string, id.loc), args, body, returnType, this
                .makeLoc(
                    start.loc, end.loc));
    }

    FunctionArgs parseFnArguments()
    {
        FunctionArgs args;
        this.consume(TokenType.LPAREN, "Esperava-se '(' após o nome da função.");
        while (this.peek().kind != TokenType.RPAREN)
        {
            Token argToken = this.consume(TokenType.IDENTIFIER,
                "Esperava-se um identificador para o nome do argumento.");
            Identifier argId = new Identifier(argToken.value.get!string, argToken.loc);
            FTypeInfo argType = createTypeInfo(TypesNative.ID);
            NullStmt def = null;

            this.consume(TokenType.COLON, "Esperava-se ':' após o nome do argumento para tipagem.");

            // Parse the type of argument
            Token[] argTokens;
            while (this.peek().kind != TokenType.EQUALS && this.peek()
                .kind != TokenType.COMMA && this.peek().kind != TokenType.RPAREN)
            {
                argTokens ~= this.advance();
            }

            argType = new ParseType(argTokens).parse();
            if (this.match([TokenType.EQUALS]))
            {
                def = this.parseExpression(Precedence.LOWEST);
            }

            args ~= new FunctionArg(argId, argType, def);

            if (this.peek().kind == TokenType.COMMA)
            {
                this.advance(); // skip ','
            }
            else if (this.peek().kind != TokenType.RPAREN)
            {
                throw new Exception("Esperava-se ',' ou ')' após o(s) argumento(s).");
            }
        }
        this.consume(TokenType.RPAREN, "Esperava-se ')' após o(s) argumento(s).");
        return args;
    }

    Stmt parseReturnStatement()
    {
        Stmt expr = this.parseExpression(Precedence.LOWEST);
        return new ReturnStatement(expr, this.previous().loc);
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
        this.consume(TokenType.RPAREN, "Esperava-se ')' após os argumentos.");
        return new CallExpr(new Identifier(calle.value.get!string, calle.loc), args, calle.loc);
    }

    Stmt parseVarDeclaration()
    {
        Token firstIdToken = this.consume(TokenType.IDENTIFIER, "Esperava-se um ID para o nome da variavel.");
        Identifier[] ids = [
            new Identifier(firstIdToken.value.get!string, firstIdToken.loc)
        ];
        bool isMultiple = false;

        if (this.match([TokenType.COMMA]))
        {
            isMultiple = true;

            while (this.peek().kind != TokenType.EQUALS &&
                this.peek()
                .kind != TokenType.COLON &&
                this.peek()
                .kind != TokenType.SEMICOLON &&
                !this.isAtEnd())
            {
                Token idToken = this.consume(TokenType.IDENTIFIER, "Esperava-se um identificador após a ','.");
                ids ~= new Identifier(idToken.value.get!string, idToken.loc);

                if (!this.match([TokenType.COMMA]))
                {
                    break;
                }
            }
        }

        FTypeInfo declaredType = createTypeInfo("null");
        if (this.match([TokenType.COLON]))
        {
            Token[] typeTokens;
            while (this.peek().kind != TokenType.EQUALS &&
                this.peek()
                .kind != TokenType.SEMICOLON &&
                !this.isAtEnd())
            {
                typeTokens ~= this.advance();
            }

            if (typeTokens.length > 0)
            {
                declaredType = new ParseType(typeTokens).parse();
            }
        }

        if (this.match([TokenType.SEMICOLON]))
        {
            if (declaredType.baseType == TypesNative.NULL)
            {
                throw new Exception(
                    "Tipo deve ser especificado para variáveis não inicializadas.");
            }

            if (isMultiple)
            {
                return VariableDeclarationFactory.createMultipleUninitialized(
                    ids,
                    declaredType,
                    true,
                    firstIdToken.loc
                );
            }
            else
            {
                return VariableDeclarationFactory.createUninitialized(
                    ids[0],
                    declaredType,
                    true,
                    firstIdToken.loc
                );
            }
        }

        this.consume(TokenType.EQUALS, "Esperava-se '=' após a declaração da variavel.");

        if (isMultiple)
        {
            Stmt[] values;

            do
            {
                values ~= this.parseExpression(Precedence.LOWEST);
            }
            while (this.match([TokenType.COMMA]));

            if (ids.length != values.length)
            {
                throw new Exception(format(
                        "Número de identificadores (%d) não corresponde ao número de valores (%d).",
                        ids.length,
                        values.length
                ));
            }

            return VariableDeclarationFactory.createMultipleInitialized(
                ids,
                values,
                declaredType,
                true,
                firstIdToken.loc
            );
        }
        else
        {
            Stmt value = this.parseExpression(Precedence.LOWEST);
            FTypeInfo finalType = declaredType.baseType != TypesNative.NULL ? declaredType
                : value.type;

            return VariableDeclarationFactory.createInitialized(
                ids[0],
                value,
                finalType,
                true,
                firstIdToken.loc
            );
        }
    }

    bool isVariableDeclaration(Stmt stmt)
    {
        return stmt.kind == NodeType.VariableDeclaration ||
            stmt.kind == NodeType.UninitializedVariableDeclaration ||
            stmt.kind == NodeType.MultipleVariableDeclaration;
    }

    Identifier[] extractIdentifiers(Stmt stmt)
    {
        switch (stmt.kind)
        {
        case NodeType.VariableDeclaration:
            auto varDecl = cast(VariableDeclaration) stmt;
            return [varDecl.id];

        case NodeType.UninitializedVariableDeclaration:
            auto uninitDecl = cast(UninitializedVariableDeclaration) stmt;
            return [uninitDecl.id];

        case NodeType.MultipleVariableDeclaration:
            auto multiDecl = cast(MultipleVariableDeclaration) stmt;
            return multiDecl.getIdentifiers();

        default:
            return [];
        }
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
        case TokenType.BIT_AND:
        case TokenType.BIT_OR:
        case TokenType.BIT_XOR:
        case TokenType.LEFT_SHIFT:
        case TokenType.RIGHT_SHIFT:
        case TokenType.BIT_AND_ASSIGN:
        case TokenType.BIT_OR_ASSIGN:
        case TokenType.BIT_XOR_ASSIGN:
        case TokenType.LEFT_SHIFT_ASSIGN:
        case TokenType.RIGHT_SHIFT_ASSIGN:
            leftOld = this.parseBinaryInfix(leftOld);
            return;
        case TokenType.INCREMENT:
        case TokenType.DECREMENT:
            Token operatorToken = this.advance();
            leftOld = new UnaryExpr(
                operatorToken.value.get!string,
                leftOld,
                this.makeLoc(leftOld.loc, operatorToken.loc),
                true
            );
            return;
        case TokenType.DOT: // suporte para member call
            leftOld = this.parseMemberCallExpression(leftOld);
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
            ulong oldPos = this.pos;
            this.infix(left);

            if (this.pos == oldPos)
            {
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

        throw new Exception(format(`Erro de parsing: %s`, message));
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
        case TokenType.DOT:
            return Precedence.CALL;

        case TokenType.BIT_OR:
            return Precedence.BIT_OR;
        case TokenType.BIT_XOR:
            return Precedence.BIT_XOR;
        case TokenType.BIT_AND:
            return Precedence.BIT_AND;
        case TokenType.LEFT_SHIFT:
        case TokenType.RIGHT_SHIFT:
            return Precedence.BIT_SHIFT;
        case TokenType.BIT_AND_ASSIGN:
        case TokenType.BIT_OR_ASSIGN:
        case TokenType.BIT_XOR_ASSIGN:
        case TokenType.LEFT_SHIFT_ASSIGN:
        case TokenType.RIGHT_SHIFT_ASSIGN:
            return Precedence.ASSIGN;
        case TokenType.INCREMENT:
        case TokenType.DECREMENT:
            return Precedence.POSTFIX;
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
        return createTypeInfo(TypesNative.LONG);
    }

    Loc makeLoc(ref Loc start, ref Loc end)
    {
        return Loc(start.file, start.line, start.start, end.end, start.dir);
    }
}
