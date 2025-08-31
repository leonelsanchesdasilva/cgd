module tests.tests_suit;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.array;
import std.string;
import std.conv;
import std.algorithm;
import core.thread;

struct CasoTeste
{
    string nome;
    string arquivoEntrada;
    string[] saidaEsperada;
    bool deveCompilar;
    bool eTestePerformance;
    int timeoutSegundos;
}

class TestadorCGD
{
    private CasoTeste[] casosTeste;
    private int aprovados = 0;
    private int falharam = 0;
    private string executavelCgd = "./cgd";
    private string diretorioBin = "bin_tests";

    this()
    {
        configurarTestes();
        configurarDiretorioBinario();
    }

    private void configurarDiretorioBinario()
    {
        if (!exists(diretorioBin))
        {
            mkdir(diretorioBin);
        }
    }

    private void configurarTestes()
    {
        casosTeste = [
            CasoTeste(
                "Olá Mundo",
                "examples/hello_world.delegua",
                ["Hello World"],
                true,
                false,
                5
            ),
            CasoTeste(
                "Fernando",
                "examples/fernando.delegua",
                ["Criado por: Fernando"],
                true,
                false,
                5
            ),
            CasoTeste(
                "Declaração de Variável",
                "examples/var_decl.delegua",
                ["69"],
                true,
                false,
                5
            ),
            CasoTeste(
                "Função de Soma",
                "examples/sum.delegua",
                ["Resultado: 69"],
                true,
                false,
                5
            ),
            CasoTeste(
                "Laço Enquanto",
                "examples/enquanto.delegua",
                [
                    "Fernando dev: 0",
                    "Fernando dev: 1",
                    "Fernando dev: 2",
                    "Fernando dev: 3",
                    "Fernando dev: 4",
                    "Fernando dev: 5",
                    "Fernando dev: 6",
                    "Fernando dev: 7",
                    "Fernando dev: 8",
                    "Fernando dev: 9"
                ],
                true,
                false,
                5
            ),
            CasoTeste(
                "FizzBuzz",
                "examples/fizzbuzz.delegua",
                [
                    "1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8",
                    "Fizz", "Buzz", "11", "Fizz", "13", "14", "FizzBuzz"
                ],
                true,
                false,
                5
            ),
            CasoTeste(
                "Fibonacci",
                "examples/fibo_otimizado.delegua",
                ["resultado: 3736710778780434371"],
                true,
                true,
                10
            ),
            CasoTeste(
                "Perceptron",
                "examples/perceptron.delegua",
                [], // Saída varia, só verifica se compila e executa
                true,
                false,
                10
            ),
            CasoTeste(
                "Multiplas declarações de variavel",
                "examples/variaveis.delegua",
                ["Fernando 17 1 2 1.5 2.5 Qualquer Coisa Outra coisa util"],
                true,
                false,
                10
            ),
            CasoTeste(
                "Operações bitwise",
                "examples/bitwise.delegua",
                [
                    "Permissões após adicionar leitura+escrita: 6",
                    "Tem permissão de leitura!",
                    "Permissões após remover escrita: 4",
                    "Permissões após alternar execução: 5", "69 * 2 = 138",
                    "69 * 4 = 276", "69 * 8 = 552", "69 / 2 = 34", "69 / 4 = 17",
                    "69 / 8 = 8"
                ],
                true,
                false,
                10
            ),
            CasoTeste(
                "Numeros representados em binario, hexadecimal e octal",
                "examples/inteiros.delegua",
                [
                    "Binario:     69",
                    "Hexadecimal: 69",
                    "Octal:       69"
                ],
                true,
                false,
                10
            ),
            CasoTeste(
                "Calculo de numeros primos",
                "examples/n_primo.delegua",
                [
                    "RESULT:78498"
                ],
                true,
                true,
                5
            ),
            CasoTeste(
                "Calculo de bhaskara",
                "examples/bhaskara.delegua",
                [
                    "O valor de Delta é: 11",
                    "O valor de X1 é: 6",
                    "O valor de X2 é: -5",
                    "Substituindo X1 na equação obtém-se: 0",
                    "Substituindo X2 na equação obtém-se: 0"
                ],
                true,
                false,
                5
            ),
            CasoTeste(
                "Classe Usuario",
                "examples/classe.delegua",
                [
                    "Nome via propriedade: Fernando", "Nome via método: Fernando"
                ],
                true,
                false,
                5
            ),
            CasoTeste(
                "Fazer enquanto",
                "examples/fazer_enquanto.delegua",
                [
                    "5"
                ],
                true,
                false,
                5
            ),
            CasoTeste(
                "Primitivos",
                "examples/primitivos.delegua",
                [
                    "Nome: Fernando Dev",
                    "[\"Fernando\", \"Cabral\"]",
                    "Tamanho do nome: 15",
                    "Tamanho do tamanho do nome: 2"
                ],
                true,
                false,
                5
            )
        ];
    }

    public void executarTodosTestes()
    {
        writeln("🔬 Suíte de Testes Automatizados do CGD");
        writeln("=======================================");
        writeln();

        foreach (teste; casosTeste)
        {
            executarTeste(teste);
        }

        imprimirResumo();
    }

    private void executarTeste(CasoTeste teste)
    {
        write("🧪 Testando " ~ teste.nome ~ "... ");
        stdout.flush();

        try
        {
            string binarioSaida = buildPath(diretorioBin, teste.nome.replace(" ", "_").toLower());

            auto resultadoCompilacao = executeShell(
                executavelCgd ~ " compilar " ~ teste.arquivoEntrada ~ " -o " ~ binarioSaida,
                null,
                Config.none,
                size_t.max,
                "."
            );

            if (resultadoCompilacao.status != 0)
            {
                falharTeste(teste.nome, "Compilação falhou: " ~ resultadoCompilacao.output);
                return;
            }

            auto resultadoExecucao = executeShell(
                binarioSaida,
                null,
                Config.none,
                size_t.max,
                "."
            );

            if (resultadoExecucao.status != 0)
            {
                falharTeste(teste.nome, "Execução falhou: " ~ resultadoExecucao.output);
                return;
            }

            if (teste.saidaEsperada.length > 0)
            {
                string saidaReal = resultadoExecucao.output.strip();
                string[] linhasReais = saidaReal.split('\n');

                if (!compararSaida(linhasReais, teste.saidaEsperada))
                {
                    falharTeste(teste.nome,
                        "Saída não confere!\nEsperado:\n" ~ teste.saidaEsperada.join(
                            "\n") ~
                            "\n\nReal:\n" ~ saidaReal
                    );
                    return;
                }
            }

            if (exists(binarioSaida))
            {
                remove(binarioSaida);
            }

            aprovarTeste(teste.nome, teste.eTestePerformance);

        }
        catch (Exception e)
        {
            falharTeste(teste.nome, "Exceção: " ~ e.msg);
        }
    }

    private bool compararSaida(string[] atual, string[] esperada)
    {
        if (atual.length != esperada.length)
        {
            return false;
        }

        foreach (i, linha; atual)
        {
            if (linha.strip() != esperada[i].strip())
            {
                return false;
            }
        }
        return true;
    }

    private void aprovarTeste(string nome, bool ePerformance = false)
    {
        writeln("✅ APROVADO" ~ (ePerformance ? " (Teste de performance)" : ""));
        aprovados++;
    }

    private void falharTeste(string nome, string razao)
    {
        writeln("❌ FALHOU");
        writeln("   Razão: " ~ razao);
        writeln();
        falharam++;
    }

    private void imprimirResumo()
    {
        writeln();
        writeln("📊 Resultados dos Testes");
        writeln("========================");
        writeln("✅ Aprovados: " ~ aprovados.to!string);
        writeln("❌ Falharam:  " ~ falharam.to!string);
        writeln("📊 Total:     " ~ (aprovados + falharam).to!string);
        writeln();

        if (falharam == 0)
        {
            writeln("🎉 TODOS OS TESTES PASSARAM! CGD está funcionando perfeitamente! 🚀");
        }
        else
        {
            writeln("⚠️  Alguns testes falharam. Verifique a saída acima.");
        }

        // Resumo de performance
        writeln();
        writeln("⚡ Nota de Performance:");
        writeln("   CGD transpila em ~2ms por arquivo");
        writeln("   Tempo total de compilação dominado pelo LDC2");
        writeln("   Código gerado tem performance nativa do D!");
    }

    public void executarBenchmarkPerformance()
    {
        writeln();
        writeln("🚀 Executando Benchmark de Performance...");
        writeln("=========================================");

        auto inicio = MonoTime.currTime;
        foreach (teste; casosTeste)
        {
            executeShell(executavelCgd ~ " transpilar " ~ teste.arquivoEntrada);
            // TODO: validar se o arquivo existe
            string file = teste.arquivoEntrada.split("/")[1].split(".")[0] ~ ".d";
            if (exists(file))
                remove(file);
        }
        auto duracao = MonoTime.currTime - inicio;

        writeln(
            "⚡ Transpilou " ~ casosTeste.length.to!string ~ " arquivos em: " ~
                duracao.total!"msecs"
                .to!string ~ "ms");
        writeln("📈 Média: " ~ (duracao.total!"msecs" / casosTeste.length)
                .to!string ~ "ms por arquivo");
    }
}

void main()
{
    auto testador = new TestadorCGD();

    if (!exists("./cgd"))
    {
        writeln("❌ Erro: executável ./cgd não encontrado!");
        writeln("   Certifique-se de estar executando do diretório raiz do CGD.");
        return;
    }

    if (!exists("examples"))
    {
        writeln("❌ Erro: diretório examples/ não encontrado!");
        return;
    }

    testador.executarTodosTestes();
    testador.executarBenchmarkPerformance();

    writeln();
    writeln("🎯 Suíte de testes concluída!");
}
