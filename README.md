<p align="center">
  <img src="assets/logo.png" width="150" alt="cgd logo"/>
</p>

# CGD - Compilador Geral Delégua

Compilador para a linguagem de programação [Delegua](https://github.com/DesignLiquido/delegua).

**Site oficial:** [fernandothedev.github.io/cgd/](https://fernandothedev.github.io/cgd/)

**Versão:** `0.0.3`

## Instalação

### Dependências necessárias

- [LDC (LLVM D Compiler)](https://github.com/ldc-developers/ldc/releases)
- [DUB (D Package Manager)](https://dub.pm/getting-started/install/)

### Passos de instalação

```bash
# Clone o repositório
git clone https://github.com/FernandoTheDev/cgd.git
cd cgd

# Compile o CGD com otimizações
dub build --build=release-fast

# O executável estará disponível em ./cgd
./cgd --help
```

## Performance

O CGD transpila código Delegua para D, que é compilado com LDC (LLVM D Compiler), resultando em performance comparável ao C.

### Benchmark: Contagem de Números Primos (1.000.000 iterações)

| Linguagem | Tempo | Diferença vs C |
|-----------|-------|----------------|
| C         | 53.1ms | - |
| C++       | 53.5ms | +0.8% |
| **Delegua** | **54.4ms** | **+2.4%** |
| Rust      | 60.5ms | +14.0% |
| Go        | 85.3ms | +60.7% |
| Node.js   | 140.2ms | +164% |
| Python    | 1213ms | +2185% |

Todas as linguagens foram compiladas com máximas otimizações. O código em todas as linguagens foi o mais simples possível, mostrando a performance nativa da linguagem.

## Arquitetura do compilador

O CGD utiliza transpilação para atingir alta performance:

```
arquivo.delegua → [Lexer] → [Parser] → [Semantic] → [CodeGen] → arquivo.d → [LDC2] → executável
                     ↓         ↓          ↓           ↓                        ↓
                   Tokens    AST    Type Check   D Source                 Native Binary
                            
                  <─────────── CGD (~2ms) ──────────>        <───── LLVM (~3000ms) ─────>
```

### Etapas detalhadas:

1. **Lexer**: Transforma código fonte em tokens
2. **Parser**: Constrói Abstract Syntax Tree (AST) 
3. **Semantic Analysis**: Verificação de tipos e análise semântica
4. **Code Generator**: Transpila AST para código D equivalente e otimizado
5. **LDC Compilation**: LLVM D Compiler gera código assembly otimizado
6. **Binary Output**: Executável nativo com performance comparável ao C

## Plataformas suportadas

- Linux
- macOS
- Windows (no futuro)

## Status do projeto

**Em desenvolvimento ativo**

Iniciado: 11 de agosto de 2025

### Funcionalidades implementadas

- [X] Lexer básico
  - [X] Lexer completo
- [X] Parser básico
  - [ ] Parser completo
- [X] Analisador semântico básico
  - [ ] Analisador semântico completo
- [ ] Otimizador
- [X] Gerador de código D
- [X] Geração do binário
- [ ] Tratamento de erros eficiente
- [ ] Criação de bibliotecas
  - [X] io
  - [ ] math
  - [ ] http
  - [ ] json
  - [ ] cripto

### Próximos passos

- Suporte completo ao Windows

## Contribuição

Este projeto está em fase inicial de desenvolvimento. Contribuições serão bem-vindas após a primeira versão estável.
