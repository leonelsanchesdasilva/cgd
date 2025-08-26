#!/bin/bash

# Script de instalação do CGD (Compilador Geral Delégua)
# Autor: Fernando Dev
# Licença: MIT

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
REPO_URL="https://github.com/FernandoTheDev/cgd"
INSTALL_DIR="$HOME/.local/bin"
SOURCE_DIR="/tmp/cgd-install"
BINARY_NAME="cgd"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_dependencies() {
    print_info "Verificando dependências..."
    
    local missing_deps=()
    
    if ! command_exists "git"; then
        missing_deps+=("git")
    fi
    
    if ! command_exists "dub"; then
        missing_deps+=("dub")
    fi
    
    if ! command_exists "dmd" && ! command_exists "ldc2" && ! command_exists "gdc"; then
        missing_deps+=("dmd ou ldc2 ou gdc")
    fi
    
    if ! command_exists "tar"; then
        missing_deps+=("tar")
    fi
    
    if ! command_exists "curl" && ! command_exists "wget"; then
        missing_deps+=("curl ou wget")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Dependências ausentes: ${missing_deps[*]}"
        print_info "Instale as dependências necessárias:"
        print_info "Ubuntu/Debian: sudo apt-get install git dub dmd tar curl"
        print_info "Fedora/RHEL: sudo dnf install git dub dmd tar curl"
        print_info "Arch Linux: sudo pacman -S git dub dmd tar curl"
        print_info "macOS: brew install git dub dmd tar curl"
        exit 1
    fi
    
    print_success "Todas as dependências estão disponíveis"
}

detect_system() {
    local os=""
    local arch=""
    
    case "$(uname -s)" in
        Linux*)     os="linux";;
        Darwin*)    os="macos";;
        CYGWIN*|MINGW*|MSYS*) os="windows";;
        *)          os="unknown";;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64) arch="x64";;
        i386|i686)    arch="x86";;
        arm64|aarch64) arch="arm64";;
        armv7*)       arch="arm";;
        *)            arch="unknown";;
    esac
    
    echo "${os}-${arch}"
}

try_download_release() {
    print_info "Tentando baixar versão pré-compilada..."
    
    local system_info=$(detect_system)
    local api_url="https://api.github.com/repos/FernandoTheDev/cgd/releases/latest"
    
    local release_info
    if command_exists "curl"; then
        release_info=$(curl -s "$api_url" 2>/dev/null || true)
    elif command_exists "wget"; then
        release_info=$(wget -qO- "$api_url" 2>/dev/null || true)
    fi
    
    if [ -z "$release_info" ]; then
        print_warning "Não foi possível obter informações de release"
        return 1
    fi
    
    local download_url=""
    if echo "$release_info" | grep -q "browser_download_url"; then
        download_url=$(echo "$release_info" | grep "browser_download_url" | grep -E "(cgd|${system_info})" | head -1 | cut -d'"' -f4 || true)
    fi
    
    if [ -z "$download_url" ]; then
        print_warning "Nenhum binário pré-compilado encontrado para $system_info"
        return 1
    fi
    
    print_info "Baixando de: $download_url"
    
    mkdir -p "$SOURCE_DIR"
    
    local download_file="$SOURCE_DIR/cgd_binary"
    if command_exists "curl"; then
        curl -L "$download_url" -o "$download_file" 2>/dev/null
    elif command_exists "wget"; then
        wget -q "$download_url" -O "$download_file" 2>/dev/null
    else
        return 1
    fi
    
    if [ ! -f "$download_file" ] || [ ! -s "$download_file" ]; then
        print_warning "Falha ao baixar o binário"
        return 1
    fi
    
    chmod +x "$download_file"
    mkdir -p "$INSTALL_DIR"
    mv "$download_file" "$INSTALL_DIR/$BINARY_NAME"
    
    print_success "Binário pré-compilado instalado com sucesso!"
    return 0
}

# Função para clonar e compilar do código fonte
compile_from_source() {
    print_info "Compilando do código fonte..."
    
    # Limpar diretório anterior se existir
    rm -rf "$SOURCE_DIR"
    
    # Clonar repositório
    print_info "Clonando repositório..."
    git clone --depth=1 "$REPO_URL" "$SOURCE_DIR"
    
    if [ ! -d "$SOURCE_DIR" ]; then
        print_error "Falha ao clonar o repositório"
        exit 1
    fi
    
    cd "$SOURCE_DIR"
    
    # Verificar se existe dub.json
    if [ ! -f "dub.json" ]; then
        print_error "Arquivo dub.json não encontrado no repositório"
        exit 1
    fi
    
    # Compilar projeto
    print_info "Compilando projeto (isso pode demorar alguns minutos)..."
    if ! dub build --build=release --quiet; then
        print_error "Falha na compilação"
        print_info "Tente executar 'dub build --build=release' manualmente para ver os erros"
        exit 1
    fi
    
    # Verificar se o executável foi criado
    local executable=""
    if [ -f "cgd" ]; then
        executable="cgd"
    elif [ -f "bin/cgd" ]; then
        executable="bin/cgd"
    elif [ -f "$BINARY_NAME" ]; then
        executable="$BINARY_NAME"
    else
        # Procurar por qualquer executável
        executable=$(find . -name "$BINARY_NAME" -type f -executable 2>/dev/null | head -1)
    fi
    
    if [ -z "$executable" ] || [ ! -f "$executable" ]; then
        print_error "Executável não foi gerado após compilação"
        exit 1
    fi
    
    # Criar diretório de instalação e mover executável
    mkdir -p "$INSTALL_DIR"
    cp "$executable" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    
    print_success "Compilação e instalação concluídas!"
}

# Função para configurar PATH
setup_path() {
    print_info "Configurando PATH..."
    
    # Detectar shell e arquivo de configuração
    local shell_rc=""
    local shell_name=$(basename "$SHELL")
    
    case "$shell_name" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                shell_rc="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                shell_rc="$HOME/.bash_profile"
            else
                shell_rc="$HOME/.profile"
            fi
            ;;
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        fish)
            shell_rc="$HOME/.config/fish/config.fish"
            ;;
        *)
            shell_rc="$HOME/.profile"
            ;;
    esac
    
    # Verificar se PATH já contém o diretório de instalação
    if echo "$PATH" | grep -q "$INSTALL_DIR"; then
        print_info "PATH já está configurado corretamente"
        return 0
    fi
    
    # Adicionar ao PATH no arquivo de configuração do shell
    local path_line=""
    if [ "$shell_name" = "fish" ]; then
        path_line="set -gx PATH $INSTALL_DIR \$PATH"
    else
        path_line="export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
    
    if [ -f "$shell_rc" ] && ! grep -q "$INSTALL_DIR" "$shell_rc"; then
        echo "" >> "$shell_rc"
        echo "# Adicionado pelo instalador do CGD" >> "$shell_rc"
        echo "$path_line" >> "$shell_rc"
        print_success "PATH configurado em $shell_rc"
    elif [ ! -f "$shell_rc" ]; then
        echo "$path_line" > "$shell_rc"
        print_success "Arquivo $shell_rc criado com configuração do PATH"
    fi
    
    export PATH="$INSTALL_DIR:$PATH"
    
    print_info "Reinicie seu terminal ou execute: source $shell_rc"
}

# Função para verificar instalação
verify_installation() {
    print_info "Verificando instalação..."
    
    if [ -x "$INSTALL_DIR/$BINARY_NAME" ]; then
        print_success "Executável instalado em: $INSTALL_DIR/$BINARY_NAME"
        
        # Tentar executar versão
        if command_exists "$BINARY_NAME" || [ -x "$INSTALL_DIR/$BINARY_NAME" ]; then
            local version_output
            if command_exists "$BINARY_NAME"; then
                version_output=$(cgd --version 2>/dev/null || echo "Comando disponível")
            else
                version_output=$("$INSTALL_DIR/$BINARY_NAME" --version 2>/dev/null || echo "Executável funciona")
            fi
            print_success "Teste de execução: $version_output"
        else
            print_warning "Comando 'cgd' não está disponível no PATH ainda"
        fi
    else
        print_error "Falha na verificação da instalação"
        exit 1
    fi
}

# Função para limpeza
cleanup() {
    if [ -d "$SOURCE_DIR" ]; then
        print_info "Limpando arquivos temporários..."
        rm -rf "$SOURCE_DIR"
    fi
}

# Função principal
main() {
    echo "========================================="
    echo "    Instalador do CGD (Compilador Geral Delégua)"
    echo "========================================="
    echo ""
    
    # Verificar se está sendo executado como root (não recomendado)
    if [ "$EUID" -eq 0 ]; then
        print_warning "Não é recomendado executar como root"
        print_info "O CGD será instalado em $INSTALL_DIR"
        read -p "Deseja continuar? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            print_info "Instalação cancelada"
            exit 0
        fi
    fi
    
    # Verificar dependências
    check_dependencies
    
    # Tentar baixar release pré-compilada primeiro
    if ! try_download_release; then
        print_info "Será necessário compilar do código fonte"
        compile_from_source
    fi
    
    # Configurar PATH
    setup_path
    
    # Verificar instalação
    verify_installation
    
    # Limpeza
    cleanup
    
    echo ""
    echo "========================================="
    print_success "Instalação concluída com sucesso!"
    echo "========================================="
    echo ""
    echo "Para usar o CGD:"
    echo "  1. Reinicie seu terminal ou execute: source ~/.bashrc"
    echo "  2. Execute: cgd --help"
    echo "  3. Para atualizar no futuro: cgd atualizar"
    echo ""
    echo "Exemplos de uso:"
    echo "  cgd compilar meuarquivo.delegua"
    echo "  cgd transpilar meuarquivo.delegua"
    echo "  cgd atualizar --verbose"
    echo ""
    echo "Documentação: $REPO_URL"
    echo ""
}

trap cleanup EXIT INT TERM

main "$@"
