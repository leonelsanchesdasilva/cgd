# Instalação do CGD

Guia completo para instalar o CGD (Compilador Geral Delégua) em diferentes sistemas operacionais.

## Pré-requisitos

Para usar o CGD, você precisa ter instalado:

- [LDC (LLVM D Compiler)](https://github.com/ldc-developers/ldc/releases) - Compilador D baseado em LLVM
- [DUB (D Package Manager)](https://dub.pm/getting-started/install/) - Gerenciador de pacotes do D

## Instalação das dependências

### Ubuntu/Debian

```bash
# Atualizar repositórios
sudo apt update -y

# Instalar LDC e DUB
sudo apt install -y ldc dub llvm-dev llvm

# Verificar instalação
ldc2 --version
dub --version
```

### Fedora/CentOS/RHEL

**Fedora:**
```bash
# Instalar LDC e DUB
sudo dnf install -y ldc dub

# Verificar instalação
ldc2 --version
dub --version
```

**CentOS/RHEL (com EPEL):**
```bash
# Habilitar repositório EPEL
sudo yum install -y epel-release

# Instalar LDC e DUB
sudo yum install -y ldc dub

# Verificar instalação
ldc2 --version
dub --version
```

**CentOS/RHEL 8+ (DNF):**
```bash
# Habilitar repositório EPEL
sudo dnf install -y epel-release

# Instalar LDC e DUB
sudo dnf install -y ldc dub

# Verificar instalação
ldc2 --version
dub --version
```

### macOS

**Usando Homebrew (recomendado):**

```bash
# Instalar Homebrew (se não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar LDC e DUB
brew install ldc dub

# Verificar instalação
ldc2 --version
dub --version
```

**Usando MacPorts:**

```bash
# Instalar LDC e DUB
sudo port install ldc dub

# Verificar instalação
ldc2 --version
dub --version
```

## Instalação do CGD

### Opção 1: Instalação Automática (Recomendada)

**Linux/macOS:**

```bash
# Instalar CGD automaticamente
curl -fsSL https://raw.githubusercontent.com/FernandoTheDev/cgd/refs/heads/master/install.sh | sh

# Verificar instalação
cgd --ajuda
```

> **Nota:** O script automático irá:
> 1. Baixar o código fonte do CGD
> 2. Compilar com otimizações máximas
> 3. Instalar o binário em `~/.local/bin/` (sem necessidade de sudo)

### Opção 2: Instalação Manual

```bash
# 1. Clonar o repositório
git clone https://github.com/fernandothedev/cgd.git
cd cgd

# 2. Compilar o CGD com otimizações
dub build --build=release-fast

# 3. Testar o executável
./cgd --ajuda

# 4. (Opcional) Instalar no diretório local
mkdir -p ~/.local/bin
cp cgd ~/.local/bin/cgd

# 5. Adicionar ~/.local/bin ao PATH (se necessário)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Para zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 6. Verificar instalação
cgd --version
```

## Verificação da instalação

Após a instalação, teste se tudo está funcionando:

```bash
# Verificar se o CGD está instalado
cgd --version

# Verificar se as dependências estão funcionando
ldc2 --version
dub --version

# Testar compilação básica (se tiver um arquivo .delegua)
cgd compilar meu_arquivo.delegua
```

## Solução de problemas

### Erro: "comando não encontrado"

Se você receber erros de "comando não encontrado":

```bash
# Verificar se o PATH inclui ~/.local/bin
echo $PATH

# Se necessário, adicionar ao PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Para zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Problemas com permissões

```bash
# Se houver problemas de permissão (instalação local - recomendada)
mkdir -p ~/.local/bin
cp cgd ~/.local/bin/cgd
chmod +x ~/.local/bin/cgd

# Alternativa: instalação global (requer sudo)
sudo mkdir -p /usr/local/bin
sudo cp cgd /usr/local/bin/cgd
sudo chmod +x /usr/local/bin/cgd
```

### LDC não encontrado

```bash
# Ubuntu/Debian: instalar de repositórios alternativos
wget https://github.com/ldc-developers/ldc/releases/download/v1.35.0/ldc2-1.35.0-linux-x86_64.tar.xz
tar -xf ldc2-1.35.0-linux-x86_64.tar.xz
sudo cp -r ldc2-1.35.0-linux-x86_64/* /usr/local/

# macOS: forçar reinstalação
brew uninstall ldc dub
brew install ldc dub
```

### Problemas específicos por sistema

#### Ubuntu 18.04/20.04 (versões antigas)

```bash
# Se a versão do LDC nos repositórios for muito antiga
sudo add-apt-repository ppa:dlang/ldc
sudo apt update
sudo apt install ldc dub llvm-dev llvm
```

#### macOS com Apple Silicon (M1/M2)

```bash
# Se houver problemas com arquitetura
arch -arm64 brew install ldc dub

# Ou forçar instalação x86_64
arch -x86_64 brew install ldc dub
```

#### Fedora com SELinux ativo

```bash
# Se SELinux bloquear execução
sudo setsebool -P allow_execheap 1
sudo restorecon -R ~/.local/bin/cgd
```

## Desinstalação

Para remover o CGD:

```bash
# Remover binário
rm ~/.local/bin/cgd

# Ou se instalou globalmente
sudo rm /usr/local/bin/cgd

# Remover código fonte (se instalou manualmente)
rm -rf ~/cgd
```

Para remover as dependências:

**Ubuntu/Debian:**
```bash
sudo apt remove ldc dub
```

**Fedora/CentOS/RHEL:**
```bash
sudo dnf remove ldc dub
# ou
sudo yum remove ldc dub
```

**macOS:**
```bash
brew uninstall ldc dub
```

## Próximos passos

Após a instalação, consulte:

- [README.md](README.md) - Visão geral do projeto
- `cgd --ajuda` - Ajuda do comando
- [Documentação da linguagem Delégua](https://github.com/DesignLiquido/delegua/wiki)
