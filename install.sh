#!/usr/bin/env bash
# ==============================================================================
# Script: install.sh
# Objetivo: Central Interativa de Automação e Ferramentas para i-Educar e i-Diário:
#           - Backups Automáticos no MinIO com Cron diário (23:59)
#           - Povoamento Inicial do Banco de Dados (24 Seeders Educacenso)
#           - Painel de Atalhos Rápidos Moderno no i-Educar
#           - Assistente de Restauração (Disaster Recovery)
# Uso via curl:
#   curl -fsSL https://raw.githubusercontent.com/douglas14031999/ieducar-idiario-backup/main/install.sh | bash
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 1. Checagem de privilégios de root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERRO] Este utilitário precisa ser executado como root (sudo).${NC}" >&2
   exit 1
fi

INSTALL_DIR="/opt/ieducar-backup"
CONFIG_DIR="/etc/ieducar-backup"
ENV_FILE="${CONFIG_DIR}/.env"

# Função auxiliar para leitura com suporte a curl | bash
read_input() {
    local prompt_text="$1"
    local default_val="$2"
    local var_name="$3"
    local user_val=""

    if [ -e /dev/tty ]; then
        read -r -p "$prompt_text" user_val < /dev/tty || true
    else
        read -r -p "$prompt_text" user_val || true
    fi
    eval "$var_name=\"\${user_val:-$default_val}\""
}

# Função para desenhar a barra de progresso elegante no terminal
render_progress_bar() {
    local percent=$1
    local text="$2"
    local width=28
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""

    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    printf "\r ${CYAN}[${GREEN}%s${CYAN}] ${YELLOW}%3d%%${NC} - %-36s" "$bar" "$percent" "$text"
}

# 2. Inicialização e sincronização dos arquivos do repositório
bootstrap_environment() {
    echo ""
    render_progress_bar 10 "Verificando privilégios e ambiente..."
    export DEBIAN_FRONTEND=noninteractive

    # Instalação rápida de ferramentas essenciais se não existirem
    local pkgs_needed=()
    for cmd in curl wget git tar gzip ca-certificates; do
        if ! command -v "$cmd" &>/dev/null; then
            pkgs_needed+=("$cmd")
        fi
    done

    render_progress_bar 35 "Verificando dependências básicas..."
    if [[ ${#pkgs_needed[@]} -gt 0 ]]; then
        if command -v apt-get &>/dev/null; then
            apt-get update -y >/dev/null 2>&1 || true
            apt-get install -y "${pkgs_needed[@]}" >/dev/null 2>&1 || true
        elif command -v yum &>/dev/null; then
            yum install -y "${pkgs_needed[@]}" >/dev/null 2>&1 || true
        fi
    fi

    render_progress_bar 60 "Preparando diretórios do sistema..."
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "/var/backups/ieducar-idiario"

    render_progress_bar 80 "Sincronizando scripts e módulos..."
    # Se já estiver rodando dentro da pasta clonada, copia; senão faz download/atualização
    if [[ -f "$(pwd)/scripts/backup.sh" ]]; then
        mkdir -p "${INSTALL_DIR}"
        cp -rf "$(pwd)"/* "${INSTALL_DIR}/" 2>/dev/null || true
    else
        REPO_URL="${GITHUB_REPO_URL:-https://github.com/douglas14031999/ieducar-idiario-backup.git}"
        if [[ -d "${INSTALL_DIR}/.git" ]]; then
            git -C "${INSTALL_DIR}" fetch origin main >/dev/null 2>&1 || true
            git -C "${INSTALL_DIR}" reset --hard origin/main >/dev/null 2>&1 || true
        else
            rm -rf "${INSTALL_DIR}"
            if ! git clone "${REPO_URL}" "${INSTALL_DIR}" >/dev/null 2>&1; then
                mkdir -p "${INSTALL_DIR}"
                curl -fsSL "https://github.com/douglas14031999/ieducar-idiario-backup/archive/refs/heads/main.tar.gz" | tar -xz --strip-components=1 -C "${INSTALL_DIR}" >/dev/null 2>&1 || true
            fi
        fi
    fi

    render_progress_bar 95 "Registrando comandos globais..."
    # Permissões executáveis
    chmod +x "${INSTALL_DIR}/scripts/"*.sh "${INSTALL_DIR}/install.sh" 2>/dev/null || true

    # Criação de atalhos globais
    ln -sf "${INSTALL_DIR}/install.sh" /usr/local/bin/ieducar-menu
    ln -sf "${INSTALL_DIR}/scripts/backup.sh" /usr/local/bin/ieducar-backup
    ln -sf "${INSTALL_DIR}/scripts/restore.sh" /usr/local/bin/ieducar-restore
    ln -sf "${INSTALL_DIR}/scripts/setup-dashboard.sh" /usr/local/bin/ieducar-dashboard
    ln -sf "${INSTALL_DIR}/scripts/seed-database.sh" /usr/local/bin/ieducar-seed
    ln -sf "${INSTALL_DIR}/scripts/setup-swap.sh" /usr/local/bin/ieducar-swap
    ln -sf "${INSTALL_DIR}/scripts/setup-pmd-leaflet.sh" /usr/local/bin/ieducar-pmd
    ln -sf "${INSTALL_DIR}/scripts/setup-idiario-profile.sh" /usr/local/bin/idiario-perfil
    ln -sf "${INSTALL_DIR}/scripts/install-ieducar.sh" /usr/local/bin/ieducar-install
    ln -sf "${INSTALL_DIR}/scripts/install-idiario.sh" /usr/local/bin/idiario-install
    ln -sf "${INSTALL_DIR}/scripts/setup-idiario-class-diary.sh" /usr/local/bin/idiario-diario-unificado
    ln -sf "${INSTALL_DIR}/scripts/install-omr.sh" /usr/local/bin/omr-install
    ln -sf "${INSTALL_DIR}/scripts/setup-domain-ssl.sh" /usr/local/bin/ieducar-ssl
    ln -sf "${INSTALL_DIR}/scripts/fix-ieducar-https.sh" /usr/local/bin/ieducar-fix-https
    ln -sf "${INSTALL_DIR}/scripts/install-educacenso.sh" /usr/local/bin/ieducar-educacenso
    ln -sf "${INSTALL_DIR}/scripts/setup-login-theme.sh" /usr/local/bin/ieducar-login-theme

    render_progress_bar 100 "Carregamento concluído com êxito!"
    echo ""
    sleep 0.5

    # Limpar a tela para abrir o menu limpo no início do terminal
    clear 2>/dev/null || printf "\033c" || true
}

# ==============================================================================
# AÇÕES DO MENU
# ==============================================================================

# Ação 1: Configurar rotinas de Backup Automático no MinIO
action_configure_backups() {
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}    CONFIGURAR BACKUPS AUTOMÁTICOS (I-EDUCAR & I-DIÁRIO -> MINIO)     ${NC}"
    echo -e "${CYAN}======================================================================${NC}"

    # Fuso Horário de Brasília
    echo -e "${BLUE}[1/5] Configurando fuso horário para America/Sao_Paulo (Brasília)...${NC}"
    timedatectl set-timezone America/Sao_Paulo >/dev/null 2>&1 || ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
    systemctl restart cron >/dev/null 2>&1 || systemctl restart crond >/dev/null 2>&1 || true

    # Pacotes necessários para o backup
    echo -e "${BLUE}[2/5] Garantindo pacotes do sistema (cron, postgresql-client)...${NC}"
    if command -v apt-get &>/dev/null; then
        apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
            cron postgresql-client >/dev/null 2>&1 || true
        systemctl enable cron >/dev/null 2>&1 || true
        systemctl start cron >/dev/null 2>&1 || true
    elif command -v yum &>/dev/null; then
        yum install -y cronie postgresql >/dev/null 2>&1 || true
        systemctl enable crond >/dev/null 2>&1 || true
        systemctl start crond >/dev/null 2>&1 || true
    fi

    # Instalação do MinIO Server e Client
    echo -e "${BLUE}[3/5] Verificando e instalando MinIO Server & Client...${NC}"
    "${INSTALL_DIR}/scripts/install-minio.sh"

    # Configuração do arquivo .env
    echo -e "${BLUE}[4/5] Configurando credenciais em ${ENV_FILE}...${NC}"
    if [[ ! -f "${ENV_FILE}" ]]; then
        if [[ -f "${INSTALL_DIR}/config/backup.env.example" ]]; then
            cp "${INSTALL_DIR}/config/backup.env.example" "${ENV_FILE}"
        fi

        echo ""
        echo -e "${YELLOW}--- CONFIGURAÇÃO DE CREDENCIAIS ---${NC}"
        echo "Pressione ENTER para aceitar os valores sugeridos entre colchetes."
        echo ""

        read_input "Usuário MinIO [admin]: " "admin" IN_MINIO_USER
        read_input "Senha MinIO [Douglas140399.]: " "Douglas140399." IN_MINIO_PASS
        read_input "Bucket MinIO [ieducar-backups]: " "ieducar-backups" IN_MINIO_BUCKET
        read_input "Dias de retenção automática [20]: " "20" IN_RETENTION
        read_input "Senha do banco PostgreSQL do i-Educar (ou enter para pular): " "" IN_IEDUCAR_PASS
        read_input "Senha do banco PostgreSQL do i-Diário (ou enter para pular): " "" IN_IDIARIO_PASS

        sed -i "s|MINIO_ACCESS_KEY=.*|MINIO_ACCESS_KEY=\"${IN_MINIO_USER}\"|g" "${ENV_FILE}"
        sed -i "s|MINIO_SECRET_KEY=.*|MINIO_SECRET_KEY=\"${IN_MINIO_PASS}\"|g" "${ENV_FILE}"
        sed -i "s|MINIO_BUCKET=.*|MINIO_BUCKET=\"${IN_MINIO_BUCKET}\"|g" "${ENV_FILE}"
        sed -i "s|RETENTION_DAYS=.*|RETENTION_DAYS=${IN_RETENTION}|g" "${ENV_FILE}"

        if [[ -n "${IN_IEDUCAR_PASS}" ]]; then
            sed -i "s|IEDUCAR_DB_PASSWORD=.*|IEDUCAR_DB_PASSWORD=\"${IN_IEDUCAR_PASS}\"|g" "${ENV_FILE}"
        fi
        if [[ -n "${IN_IDIARIO_PASS}" ]]; then
            sed -i "s|IDIARIO_DB_PASSWORD=.*|IDIARIO_DB_PASSWORD=\"${IN_IDIARIO_PASS}\"|g" "${ENV_FILE}"
        fi

        chmod 600 "${ENV_FILE}"
        chown root:root "${ENV_FILE}"
        echo -e "${GREEN}Arquivo de configuração criado com permissão restrita 600!${NC}"
    else
        echo -e "${GREEN}Arquivo de configuração existente em ${ENV_FILE}. Mantido.${NC}"
    fi

    # Configuração do Cron diário (23:59)
    echo -e "${BLUE}[5/5] Configurando agendamento diário no Cron (23:59)...${NC}"
    CRON_FILE="/etc/cron.d/ieducar-backup"
    cat <<EOF > "${CRON_FILE}"
# Cron job de backup automático para i-Educar e i-Diário
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Todos os dias às 23:59
59 23 * * * root ${INSTALL_DIR}/scripts/backup.sh >/dev/null 2>&1
EOF
    chmod 644 "${CRON_FILE}"
    echo -e "${GREEN}Agendamento configurado com sucesso em ${CRON_FILE}!${NC}"

    # Verificação de SWAP
    SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
    if [[ -z "$SWAP_TOTAL" || "$SWAP_TOTAL" -eq 0 ]]; then
        echo ""
        "${INSTALL_DIR}/scripts/setup-swap.sh" || true
    fi

    # Resumo
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e " ${GREEN}✓ Rotinas de Backup Automático configuradas com êxito!${NC}"
    echo -e " • MinIO API:          ${YELLOW}http://$(curl -s https://api.ipify.org || echo "IP_VPS"):9000${NC}"
    echo -e " • MinIO Web Console:  ${YELLOW}http://$(curl -s https://api.ipify.org || echo "IP_VPS"):9001${NC}"
    echo -e " • Configuração (.env): ${YELLOW}${ENV_FILE}${NC}"
    echo -e " • Agendamento Cron:   ${YELLOW}Diariamente às 23:59${NC}"
    echo -e " • Retenção no MinIO:  ${YELLOW}20 dias de histórico mantidos${NC}"
    echo -e "${CYAN}======================================================================${NC}"

    RUN_TEST="n"
    read_input "Deseja executar um backup de teste agora? (s/N): " "n" RUN_TEST
    if [[ "$RUN_TEST" =~ ^[sS]$ ]]; then
        echo -e "${BLUE}Iniciando backup de teste...${NC}"
        "${INSTALL_DIR}/scripts/backup.sh" || true
    fi
}

# Ação 2: Popular banco de dados do i-Educar (Seeders)
action_seed_database() {
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}    POVOAMENTO INICIAL DO BANCO DE DADOS (24 SEEDERS EDUCACENSO)      ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    if "${INSTALL_DIR}/scripts/seed-database.sh"; then
        echo -e "\n${GREEN}✓ Povoamento inicial concluído com sucesso!${NC}"
    else
        echo -e "\n${YELLOW}O processo de seed finalizou com avisos. Verifique as mensagens acima.${NC}"
    fi
}

# Ação 3: Configurar tela de Atalhos Rápidos (Dashboard)
action_setup_dashboard() {
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}       CONFIGURAR PAINEL DE ATALHOS RÁPIDOS NO I-EDUCAR               ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    if "${INSTALL_DIR}/scripts/setup-dashboard.sh"; then
        echo -e "\n${GREEN}✓ Tela de Atalhos Rápidos configurada com sucesso!${NC}"
    else
        echo -e "\n${YELLOW}Não foi possível configurar os atalhos automáticos. Verifique se o i-Educar está instalado.${NC}"
    fi
}

# Ação 4: Configurar / Otimizar Memória SWAP
action_configure_swap() {
    echo ""
    "${INSTALL_DIR}/scripts/setup-swap.sh" || true
}

# Ação 5: Migrar Pré-Matrícula Digital (PMD) para Leaflet / OpenStreetMap
action_setup_pmd() {
    echo ""
    "${INSTALL_DIR}/scripts/setup-pmd-leaflet.sh" || true
}

# Ação 6: Corrigir Foto de Perfil & Menu no i-Diário
action_setup_idiario_profile() {
    echo ""
    "${INSTALL_DIR}/scripts/setup-idiario-profile.sh" || true
}

# Ação 7: Restaurar um Backup existente
action_restore() {
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}         ASSISTENTE DE RESTAURAÇÃO DE BACKUP (DISASTER RECOVERY)      ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    "${INSTALL_DIR}/scripts/restore.sh" || true
}

# Ação 8: Executar Backup Manual Imediato
action_test_backup() {
    echo ""
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}             EXECUTAR BACKUP MANUAL COMPLETO AGORA                    ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    "${INSTALL_DIR}/scripts/backup.sh" || true
}

# Ação: Instalar i-Educar Completo com Todos os Módulos
action_install_ieducar() {
    echo ""
    "${INSTALL_DIR}/scripts/install-ieducar.sh" || true
}

# Ação: Instalar i-Diário Completo
action_install_idiario() {
    echo ""
    "${INSTALL_DIR}/scripts/install-idiario.sh" || true
}

# Ação: Instalar Diário de Classe Unificado no i-Diário
action_setup_class_diary() {
    echo ""
    "${INSTALL_DIR}/scripts/setup-idiario-class-diary.sh" || true
}

# Ação: Instalar Gabarito OMR & Elaborador de Provas
action_install_omr() {
    echo ""
    "${INSTALL_DIR}/scripts/install-omr.sh" || true
}

# Ação: Configurar Domínios & SSL HTTPS (i-Educar & i-Diário)
action_setup_domain_ssl() {
    echo ""
    "${INSTALL_DIR}/scripts/setup-domain-ssl.sh" || true
}

# Ação: Instalar / Atualizar Pacote Educacenso 2024-2026 (Douglas)
action_install_educacenso() {
    echo ""
    "${INSTALL_DIR}/scripts/install-educacenso.sh" || true
}

# Ação: Corrigir Ativos HTTPS / Mixed Content (i-Educar)
action_fix_https() {
    echo ""
    "${INSTALL_DIR}/scripts/fix-ieducar-https.sh" || true
}

# Ação: Aplicar Tema Moderno de Login no i-Educar (Sistema Canoa 2026)
action_setup_login_theme() {
    echo ""
    "${INSTALL_DIR}/scripts/setup-login-theme.sh" || true
}

# ==============================================================================
# MENU PRINCIPAL INTERATIVO
# ==============================================================================

# Inicializa o repositório e atalhos na primeira execução
bootstrap_environment

# Se foi passado algum argumento direto via linha de comando
case "${1:-}" in
    --install-ieducar|--install|-install)
        action_install_ieducar
        exit 0
        ;;
    --install-idiario|-idiario)
        action_install_idiario
        exit 0
        ;;
    --class-diary|--diario-unificado|-du)
        action_setup_class_diary
        exit 0
        ;;
    --omr|--gabarito-omr|-omr)
        action_install_omr
        exit 0
        ;;
    --ssl|--domain|-ssl)
        action_setup_domain_ssl
        exit 0
        ;;
    --educacenso|--censo|-c)
        action_install_educacenso
        exit 0
        ;;
    --fix-https|--fix-css|-fix)
        action_fix_https
        exit 0
        ;;
    --login-theme|--login|-l)
        action_setup_login_theme
        exit 0
        ;;
    --backup|-b)
        action_configure_backups
        exit 0
        ;;
    --seed|-s)
        action_seed_database
        exit 0
        ;;
    --dashboard|-d)
        action_setup_dashboard
        exit 0
        ;;
    --swap|-w)
        action_configure_swap
        exit 0
        ;;
    --pmd|-p)
        action_setup_pmd
        exit 0
        ;;
    --idiario-profile|-i)
        action_setup_idiario_profile
        exit 0
        ;;
    --restore|-r)
        action_restore
        exit 0
        ;;
esac

# Loop do Menu Principal
while true; do
    clear 2>/dev/null || printf "\033c" || true
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}        i-Educar & i-Diário - Central de Ferramentas e Automação      ${NC}"
    echo -e " Escolha a operação desejada:\n"
    echo -e "   ${GREEN}[1]${NC}  🚀  Instalar i-Educar (Gestão Escolar)"
    echo -e "   ${GREEN}[2]${NC}  📓  Instalar i-Diário (Diário do Professor)"
    echo -e "   ${GREEN}[3]${NC}  🛡️  Configurar Backups Automáticos (MinIO S3 & Cron)"
    echo -e "   ${GREEN}[4]${NC}  🧬  Popular Banco de Dados (24 Seeders Educacenso)"
    echo -e "   ${GREEN}[5]${NC}  🎨  Configurar Atalhos Rápidos (Dashboard do i-Educar)"
    echo -e "   ${GREEN}[6]${NC}  ⚡  Configurar Memória SWAP (Desempenho da VPS)"
    echo -e "   ${GREEN}[7]${NC}  🗺️  Migrar Mapas PMD (Pré-Matrícula OpenStreetMap)"
    echo -e "   ${GREEN}[8]${NC}  👤  Corrigir Foto de Perfil & Menu (i-Diário)"
    echo -e "   ${GREEN}[9]${NC}  📑  Instalar Diário de Classe Unificado (i-Diário)"
    echo -e "   ${GREEN}[10]${NC} 🎯  Instalar Gabarito OMR de Provas (Leitura Automática)"
    echo -e "   ${GREEN}[11]${NC} 🔒  Configurar Domínios & Certificados SSL HTTPS"
    echo -e "   ${GREEN}[12]${NC} 📦  Instalar / Atualizar Pacote Educacenso (2024 a 2026)"
    echo -e "   ${GREEN}[13]${NC} 🛠️  Corrigir Ativos HTTPS & Estilos CSS (i-Educar)"
    echo -e "   ${GREEN}[14]${NC} 🖼️  Aplicar Tema Moderno de Login (i-Educar)"
    echo -e "   ${GREEN}[15]${NC} 🔄  Restaurar Backup do MinIO (Assistente)"
    echo -e "   ${GREEN}[16]${NC} 💾  Executar Backup Manual Completo Agora"
    echo -e "   ${YELLOW}[0]${NC}  🚪  Sair"
    echo -e "${CYAN}======================================================================${NC}"

    CHOICE=""
    read_input " Digite a opção desejada [0-16]: " "" CHOICE

    # Prevenção contra loop infinito em terminais não-interativos
    if [[ -z "$CHOICE" ]] && [ ! -e /dev/tty ]; then
        echo "Execução concluída em modo não-interativo."
        break
    fi

    case "$CHOICE" in
        1)
            action_install_ieducar
            ;;
        2)
            action_install_idiario
            ;;
        3)
            action_configure_backups
            ;;
        4)
            action_seed_database
            ;;
        5)
            action_setup_dashboard
            ;;
        6)
            action_configure_swap
            ;;
        7)
            action_setup_pmd
            ;;
        8)
            action_setup_idiario_profile
            ;;
        9)
            action_setup_class_diary
            ;;
        10)
            action_install_omr
            ;;
        11)
            action_setup_domain_ssl
            ;;
        12)
            action_install_educacenso
            ;;
        13)
            action_fix_https
            ;;
        14)
            action_setup_login_theme
            ;;
        15)
            action_restore
            ;;
        16)
            action_test_backup
            ;;
        0|sair|exit|q)
            echo ""
            echo -e "${GREEN}Encerrando a Central de Ferramentas. Até logo!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "\n${RED}Opção inválida! Escolha um número entre 0 e 16.${NC}"
            ;;
    esac

    # Pausa e retorno à tela inicial
    echo ""
    echo -e "${BLUE}----------------------------------------------------------------------${NC}"
    if [ -e /dev/tty ]; then
        read -r -p "Pressione ENTER para voltar ao menu principal..." _ < /dev/tty || true
    else
        read -r -p "Pressione ENTER para voltar ao menu principal..." _ || true
    fi
done
