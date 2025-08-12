import std.stdio;
import std.file;
import frontend.lexer.lexer;
import frontend.lexer.token;
import frontend.parser.parser;
import frontend.parser.ast;
import middle.semantic;

void main(string[] args)
{
	if (args.length < 2)
	{
		writeln("Error: Missing file.");
		return;
	}

	if (!isFile(args[1]))
	{
		writeln("Error: It's not a file.");
		return;
	}

	string fileContent = readText(args[1]);

	Lexer lexer = new Lexer(args[1], fileContent, ".");
	Token[] tokens = lexer.tokenize();

	// foreach (Token token; tokens)
	// {
	// 	token.print();
	// }

	Parser parser = new Parser(tokens);
	Program program = parser.parse();
	writeln("Body: ", program.body);

	foreach (Stmt stmt; program.body)
	{
		writeln("Kind: ", stmt.kind);
		writeln("Value: ", stmt.value);
		writeln("Line: ", stmt.loc.line, "\n");
	}

	Program newProgram = new Semantic().semantic(program);

	foreach (Stmt stmt; newProgram.body)
	{
		writeln("S Kind: ", stmt.kind);
		writeln("S Value: ", stmt.value);
		writeln("S Line: ", stmt.loc.line, "\n");
	}
}
