import std.stdio;
import std.file;
import std.array : split;
import frontend.lexer.lexer;
import frontend.lexer.token;
import frontend.parser.parser;
import frontend.parser.ast;
import middle.semantic;
import backend.builder;
import backend.compiler;

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

	string file = args[1];
	string filename = file.split('.')[0];
	string fileContent = readText(file);

	Lexer lexer = new Lexer(filename, fileContent, ".");
	Token[] tokens = lexer.tokenize();

	// foreach (Token token; tokens)
	// {
	// 	token.print();
	// }

	Parser parser = new Parser(tokens);
	Program program = parser.parse();
	// writeln("Body: ", program.body);

	// foreach (Stmt stmt; program.body)
	// {
	// 	writeln("Kind: ", stmt.kind);
	// 	writeln("Value: ", stmt.value);
	// 	writeln("Line: ", stmt.loc.line, "\n");
	// }

	Semantic semantic = new Semantic();
	Program newProgram = semantic.semantic(program);

	// foreach (Stmt stmt; newProgram.body)
	// {
	// 	writeln("S Kind: ", stmt.kind);
	// 	writeln("S Value: ", stmt.value);
	// 	writeln("S Line: ", stmt.loc.line, "\n");
	// }

	Builder builder = new Builder(newProgram, semantic);
	builder.build();

	Compiler compiler = new Compiler(builder, filename ~ ".d");
	compiler.compile();
}
