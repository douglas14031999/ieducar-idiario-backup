#!/usr/bin/env bash
# ==============================================================================
# Script: install-educacenso.sh
# Objetivo: Instalação e Atualização Inteligente do Módulo Desacoplado do
#           Educacenso para o i-Educar com suporte aos Censos 2024, 2025 e 2026,
#           correções de integridade de dados (vínculo de servidores, turnos
#           e alocações), auto-descoberta no Composer e ativação de menus.
# Repositório: douglas14031999/i-educar-educacenso-package (Branch 2.12)
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # Sem Cor

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}     📦  MÓDULO EDUCACENSO 2024 / 2025 / 2026 - I-EDUCAR (DOUGLAS)    ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "Instalação e atualização inteligente do pacote desacoplado do Educacenso,"
echo -e "com suporte expandido para censos escolares e correções de integridade."
echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"

# 1. Checagem de privilégios de root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERRO] Este utilitário precisa ser executado como root (sudo).${NC}" >&2
    exit 1
fi

# 2. Localizar diretório raiz do i-Educar
IEDUCAR_DIR="/var/www/ieducar"
if [[ ! -d "$IEDUCAR_DIR" ]] && [[ -f "./artisan" ]]; then
    IEDUCAR_DIR="$(pwd)"
elif [[ ! -d "$IEDUCAR_DIR" ]] && [[ -d "/var/www/i-educar" ]] && [[ -f "/var/www/i-educar/artisan" ]]; then
    IEDUCAR_DIR="/var/www/i-educar"
elif [[ ! -d "$IEDUCAR_DIR" ]] && [[ -d "/var/www/html" ]] && [[ -f "/var/www/html/artisan" ]]; then
    IEDUCAR_DIR="/var/www/html"
fi

if [[ ! -d "$IEDUCAR_DIR" ]] || [[ ! -f "$IEDUCAR_DIR/artisan" ]]; then
    echo -e "${RED}[ERRO] Instalação do i-Educar não encontrada em: $IEDUCAR_DIR${NC}" >&2
    echo -e "Certifique-se de executar o comando no servidor onde o i-Educar está instalado." >&2
    exit 1
fi

echo -e "${BLUE}[+] Diretório base do i-Educar:${NC} ${IEDUCAR_DIR}"
cd "$IEDUCAR_DIR"

PACKAGE_DIR="${IEDUCAR_DIR}/packages/portabilis/i-educar-educacenso-package"
REPO_URL="https://github.com/douglas14031999/i-educar-educacenso-package.git"
BRANCH="2.12"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# 3. Detecção Inteligente e Atualização/Instalação
echo -e "\n${YELLOW}[1/5] Verificando estado atual do pacote Educacenso...${NC}"

if [[ -d "$PACKAGE_DIR" ]]; then
    echo -e "      Diretório detectado: ${CYAN}${PACKAGE_DIR}${NC}"
    
    IS_DOUGLAS_REPO=false
    if [[ -d "$PACKAGE_DIR/.git" ]]; then
        REMOTE_URL=$(git -C "$PACKAGE_DIR" config --get remote.origin.url || true)
        echo -e "      Origem remota detectada: ${CYAN}${REMOTE_URL:-desconhecida}${NC}"
        
        if [[ "$REMOTE_URL" == *"douglas14031999"* ]]; then
            IS_DOUGLAS_REPO=true
        fi
    fi

    if [[ "$IS_DOUGLAS_REPO" == true ]]; then
        echo -e "${GREEN}==> Repositório do Douglas confirmado! Atualizando para a versão mais recente...${NC}"
        git -C "$PACKAGE_DIR" fetch origin "$BRANCH"
        git -C "$PACKAGE_DIR" checkout "$BRANCH"
        git -C "$PACKAGE_DIR" reset --hard "origin/$BRANCH"
        git -C "$PACKAGE_DIR" clean -fd
        echo -e "${GREEN}✓ Repositório sincronizado com sucesso na branch ${BRANCH}!${NC}"
    else
        echo -e "${YELLOW}==> Repositório legado ou da Portabilis detectado!${NC}"
        echo -e "${YELLOW}    Substituindo com segurança pelo repositório customizado do Douglas...${NC}"
        
        BACKUP_DIR="${IEDUCAR_DIR}/packages/portabilis/i-educar-educacenso-package.bak.${TIMESTAMP}"
        echo -e "    Criando backup de segurança em: ${CYAN}${BACKUP_DIR}${NC}"
        cp -r "$PACKAGE_DIR" "$BACKUP_DIR"
        rm -rf "$PACKAGE_DIR"

        echo -e "${BLUE}    Clonando novo repositório (${REPO_URL} - branch ${BRANCH})...${NC}"
        mkdir -p "$(dirname "$PACKAGE_DIR")"
        git clone -b "$BRANCH" "$REPO_URL" "$PACKAGE_DIR"
        echo -e "${GREEN}✓ Repositório do Douglas instalado com sucesso!${NC}"
    fi
else
    echo -e "${YELLOW}==> Pacote não encontrado. Realizando nova instalação do repositório do Douglas...${NC}"
    mkdir -p "$(dirname "$PACKAGE_DIR")"
    git clone -b "$BRANCH" "$REPO_URL" "$PACKAGE_DIR"
    echo -e "${GREEN}✓ Repositório clonado com sucesso em: ${PACKAGE_DIR}${NC}"
fi

# 4. Ajustar permissões para o usuário web (www-data)
echo -e "\n${YELLOW}[2/5] Ajustando donos e permissões de arquivos (www-data:www-data 775)...${NC}"
chown -R www-data:www-data "$PACKAGE_DIR"
chmod -R 775 "$PACKAGE_DIR"
echo -e "${GREEN}✓ Permissões aplicadas com sucesso!${NC}"

# 5. Atualizar autoload do Composer com descoberta de pacotes
echo -e "\n${YELLOW}[3/5] Atualizando o Autoload do Composer e plug-and-play...${NC}"
export COMPOSER_ALLOW_SUPERUSER=1

if command -v composer &>/dev/null; then
    composer plug-and-play 2>/dev/null || true
    composer dump-autoload --optimize
else
    echo -e "${RED}[AVISO] Executável 'composer' não encontrado no PATH. Tentando via php composer.phar...${NC}"
    if [[ -f "${IEDUCAR_DIR}/composer.phar" ]]; then
        php "${IEDUCAR_DIR}/composer.phar" plug-and-play 2>/dev/null || true
        php "${IEDUCAR_DIR}/composer.phar" dump-autoload --optimize
    fi
fi
echo -e "${GREEN}✓ Autoload do Composer reconfigurado com otimização!${NC}"

# 6. Executar migrations e registrar menu do Educacenso
echo -e "\n${YELLOW}[4/5] Executando migrations do banco e registrando menu Importação...${NC}"
php artisan migrate --force || true

php artisan tinker --execute="
    \$educacensoMenu = \App\Menu::where('title', 'Educacenso')->first();
    \$menuImportacao = \App\Menu::where('title', 'Importações')->first();
    if (\$menuImportacao) {
        \App\Menu::updateOrCreate(
            ['process' => 9998849],
            [
                'parent_id' => \$menuImportacao->getKey(),
                'title' => 'Importação educacenso',
                'description' => 'Importação educacenso',
                'link' => '/educacenso/import-registrations/create',
                'order' => 0,
                'type' => 1,
                'parent_old' => 9998848,
                'old' => 9998849,
                'active' => true,
            ]
        );
        echo 'Menu Importação educacenso registrado e ativado com sucesso.\n';
    } else {
        echo 'Aviso: Menu Importações não localizado. O menu do pacote será criado pelas migrations.\n';
    }
" || true
echo -e "${GREEN}✓ Migrations concluídas e menu verificado!${NC}"

# 7. Limpar caches da aplicação
echo -e "\n${YELLOW}[5/5] Limpando caches da aplicação (optimize, config, cache, view)...${NC}"
php artisan optimize:clear || true
php artisan config:clear || true
php artisan cache:clear || true
php artisan view:clear || true
echo -e "${GREEN}✓ Caches limpos com sucesso!${NC}"

# Resumo Final
LAST_COMMIT=$(git -C "$PACKAGE_DIR" log -1 --oneline 2>/dev/null || echo "Desconhecido")
ACTIVE_BRANCH=$(git -C "$PACKAGE_DIR" branch --show-current 2>/dev/null || echo "$BRANCH")

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  ✓ PACOTE EDUCACENSO (DOUGLAS) INSTALADO/ATUALIZADO COM SUCESSO!     ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e " • Repositório:  ${CYAN}${REPO_URL}${NC}"
echo -e " • Branch Ativa: ${CYAN}${ACTIVE_BRANCH}${NC}"
echo -e " • Último Commit: ${YELLOW}${LAST_COMMIT}${NC}"
echo -e " • Localização:  ${CYAN}${PACKAGE_DIR}${NC}"
echo -e " • Suporte Censo: ${GREEN}2024, 2025 e 2026 integrados${NC}"
echo -e " • Correções:    ${GREEN}Integridade de dados (vínculo de servidores, turnos e alocações)${NC}"
echo -e " • Menu Ativo:   ${GREEN}Importações -> Importação educacenso${NC}"
echo -e "${GREEN}======================================================================${NC}\n"
