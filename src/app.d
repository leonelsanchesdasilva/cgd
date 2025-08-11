import std.stdio;
import std.file;
import frontend.lexer.lexer;
import frontend.lexer.token;

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

	foreach (Token token; tokens)
	{
		token.print();
	}
}
