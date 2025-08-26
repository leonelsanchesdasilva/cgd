import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.array : split;
import std.string : format;
import frontend.lexer.lexer;
import frontend.lexer.token;
import frontend.parser.parser;
import frontend.parser.ast;
import middle.semantic;
import backend.builder;
import backend.compiler;
import updater;

alias fileWrite = std.file.write;

enum string VERSAO = "v0.0.4";
enum string NOME_PROGRAMA = "cgd";
enum string NOME_COMPLETO = "Compilador Geral Delégua";

void main(string[] args)
{
	string arquivoSaida = "";
	bool mostrarVersao = false;
	bool mostrarAjuda = false;
	bool verboso = false;

	try
	{
		getopt(args,
			"o|output", "Especifica o arquivo de saída", &arquivoSaida,
			"v|version", "Mostra a versão do compilador", &mostrarVersao,
			"h|help", "Mostra esta mensagem de ajuda", &mostrarAjuda,
			"verbose", "Modo verboso - mostra informações detalhadas", &verboso
		);

		if (mostrarVersao)
		{
			mostrarVersaoPrograma();
			return;
		}

		if (mostrarAjuda || args.length < 2)
		{
			mostrarMensagemAjuda();
			return;
		}

		string comando = args[1];

		if (comando == "atualizar" || comando == "upgrade")
		{
			executarAtualizacao(verboso);
			return;
		}

		if (args.length < 3)
		{
			writeln("cgd: erro: arquivo não especificado");
			writeln("Digite 'cgd --help' para mais informações.");
			return;
		}

		string arquivo = args[2];

		if (comando != "compilar" && comando != "transpilar")
		{
			writefln("cgd: erro: comando desconhecido '%s'", comando);
			writeln("Comandos disponíveis: compilar, transpilar, atualizar");
			writeln("Digite 'cgd --help' para mais informações.");
			return;
		}

		if (!exists(arquivo))
		{
			writefln("cgd: erro: arquivo '%s' não encontrado", arquivo);
			return;
		}

		if (!isFile(arquivo))
		{
			writefln("cgd: erro: '%s' não é um arquivo válido", arquivo);
			return;
		}

		string nomeBase = baseName(stripExtension(arquivo));
		if (arquivoSaida.length == 0)
		{
			arquivoSaida = nomeBase;
			if (comando == "transpilar")
			{
				arquivoSaida = nomeBase ~ ".d";
			}
		}

		if (verboso)
		{
			writefln("Processando arquivo: %s", arquivo);
			writefln("Comando: %s", comando);
			writefln("Arquivo de saída: %s", arquivoSaida);
		}

		processarArquivo(arquivo, arquivoSaida, comando, verboso);

	}
	catch (GetOptException e)
	{
		writefln("cgd: erro: %s", e.msg);
		writeln("Digite 'cgd --help' para mais informações.");
	}
	catch (Exception e)
	{
		writefln("cgd: erro interno: %s", e.msg);
		if (verboso)
		{
			writeln("Informações de debug:");
			writeln(e.toString());
		}
	}
}

void executarAtualizacao(bool verboso)
{
	try
	{
		UpdaterConfig config = UpdaterConfig(verboso, false, true, "");
		Updater updater = new Updater("FernandoTheDev", "cgd", VERSAO, config);
		updater.performUpdate();
	}
	catch (Exception e)
	{
		writefln("cgd: erro na atualização: %s", e.msg);
		if (verboso)
		{
			writeln("Detalhes do erro:");
			writeln(e.toString());
		}
	}
}

void mostrarMensagemAjuda()
{
	writeln("Uso: cgd [OPÇÕES] COMANDO [ARQUIVO]");
	writeln("");
	writeln("Comandos:");
	writeln("  compilar    Compila o arquivo Delegua para código executável");
	writeln("  transpilar  Transpila o arquivo Delegua para código D");
	writeln("  atualizar   Verifica e instala atualizações do compilador");
	writeln("");
	writeln("Opções:");
	writeln("  -o, --output ARQUIVO  Especifica o arquivo de saída");
	writeln("  -v, --version         Mostra a versão do compilador");
	writeln("  -h, --help            Mostra esta mensagem de ajuda");
	writeln("  --verbose             Modo verboso - mostra informações detalhadas");
	writeln("");
	writeln("Exemplos:");
	writeln("  cgd compilar arquivo.delegua");
	writeln("  cgd transpilar arquivo.delegua -o saida.d");
	writeln("  cgd compilar arquivo.delegua --output meuapp");
	writeln("  cgd atualizar --verbose");
	writeln("");
	mostrarCopyright();
}

void mostrarVersaoPrograma()
{
	writefln("%s (%s) %s", NOME_COMPLETO, NOME_PROGRAMA, VERSAO);
}

void mostrarCopyright()
{
	writeln("MIT License");
	writeln("Copyright (C) 2025 Fernando");
	writeln("GitHub: https://github.com/fernandothedev");
	writeln("");
	writeln("Este é um software livre; veja o código-fonte para condições de cópia.");
	writeln("NÃO há garantia; nem mesmo para COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM");
	writeln("PROPÓSITO PARTICULAR.");
}

void processarArquivo(string arquivo, string arquivoSaida, string comando, bool verboso)
{
	try
	{
		if (verboso)
		{
			writeln("Iniciando análise léxica...");
		}

		string nomeArquivo = baseName(stripExtension(arquivo));
		string conteudoArquivo = readText(arquivo);

		Lexer lexer = new Lexer(nomeArquivo, conteudoArquivo, ".");
		Token[] tokens = lexer.tokenize();

		if (verboso)
		{
			writefln("Análise léxica concluída. %d tokens gerados.", tokens.length);
			writeln("Iniciando análise sintática...");
		}

		Parser parser = new Parser(tokens);
		Program program = parser.parse();

		if (verboso)
		{
			writeln("Análise sintática concluída.");
			writeln("Iniciando análise semântica...");
		}

		Semantic semantic = new Semantic();
		Program newProgram = semantic.semantic(program);

		if (verboso)
		{
			writeln("Análise semântica concluída.");
			if (comando == "compilar")
			{
				writeln("Iniciando geração de código...");
			}
			else
			{
				writeln("Iniciando Transpilação...");
			}
		}

		Builder builder = new Builder(newProgram, semantic);
		builder.build();

		if (comando == "compilar")
		{
			Compiler compiler = new Compiler(builder, nomeArquivo ~ ".d", arquivoSaida);
			compiler.compile();

			if (verboso)
			{
				writefln("Compilação concluída com sucesso. Executável gerado: %s", arquivoSaida);
			}
			else
			{
				writefln("Compilação de '%s' concluída.", arquivo);
			}
		}
		else // transpilar
		{
			string codigoGerado = builder.codegen.generate();

			fileWrite(arquivoSaida, codigoGerado);

			if (verboso)
			{
				writefln("Transpilação concluída com sucesso. Arquivo D gerado: %s", arquivoSaida);
			}
			else
			{
				writefln("Transpilação de '%s' concluída.", arquivo);
			}
		}

	}
	catch (FileException e)
	{
		writefln("cgd: erro: não foi possível ler o arquivo '%s': %s", arquivo, e.msg);
	}
	catch (Exception e)
	{
		writefln("cgd: erro durante o processamento: %s", e.msg);
		if (verboso)
		{
			writeln("Detalhes do erro:");
			writeln(e.toString());
		}
	}
}
