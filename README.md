<p align="center">
  <img src="docs/assets/logo.png" width="150" alt="cgd logo"/>
</p>

[![Versão](https://img.shields.io/badge/versão-v0.0.5-blue.svg)](https://github.com/fernandothedev/cgd)

# CGD - Compilador Geral Delégua

Compilador para a linguagem de programação [Delegua](https://github.com/DesignLiquido/delegua).

## Instalação

**Para instruções detalhadas de instalação, consulte o [INSTALL.md](INSTALL.md)**

### Instalação rápida

```bash
# Linux/macOS - Instalação automática
curl -fsSL https://github.com/FernandoTheDev/cgd/raw/refs/heads/master/install.sh | sh

# Verificar instalação
cgd --help
```

### Pré-requisitos

- LDC (LLVM D Compiler)
- DUB (D Package Manager)

> **Dica:** O guia [INSTALL.md](INSTALL.md) contém instruções específicas para Ubuntu, Debian, Fedora, CentOS, RHEL e macOS.

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

## Uso básico

```bash
# Compilar um arquivo Delegua
cgd compilar meu_programa.delegua

# Compilar com otimizações específicas
cgd --optimize meu_programa.delegua

# Ver ajuda completa
cgd --help
```

## Plataformas suportadas

- ✅ Linux (Ubuntu, Debian, Fedora, CentOS, RHEL)
- ✅ macOS (Intel e Apple Silicon)
- 🚧 Windows (em desenvolvimento)

## Status do projeto

**Em desenvolvimento ativo**

Iniciado: 11 de agosto de 2025

### Funcionalidades implementadas

- [X] Lexer básico
  - [X] Lexer completo
- [X] Parser básico
  - [X] Parser completo
- [X] Analisador semântico básico
  - [ ] Analisador semântico completo
- [ ] Otimizador
- [X] Gerador de código D
- [X] Geração do binário
- [X] Tratamento de erros eficiente
- [ ] Criação de bibliotecas
  - [X] io
  - [ ] math
  - [ ] http
  - [ ] json
  - [ ] cripto

### Próximos passos

- Suporte completo ao Windows
- Melhorias no parser e analisador semântico
- Sistema de módulos e bibliotecas
- Otimizações avançadas

## Contribuição

Este projeto está em fase inicial de desenvolvimento. Contribuições serão bem-vindas após a primeira versão estável.

Para contribuir:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## Links úteis

- [Site oficial do CGD](https://fernandothedev.github.io/cgd/)
- [Linguagem Delegua](https://github.com/DesignLiquido/delegua)
- [LDC Compiler](https://github.com/ldc-developers/ldc)
- [DUB Package Manager](https://dub.pm/)
- [Documentação do D](https://dlang.org/)
