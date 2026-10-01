#!/usr/bin/env bash
# ==============================================================================
# Script: install.sh
# Objetivo: Instalador 'One-Liner' para automação de backups do i-Educar e i-Diário
#           com armazenamento no MinIO (RELEASE.2021-04-22T15-44-28Z) e Crontab.
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

echo -e "${CYAN}"
echo "======================================================================"
echo "    INSTALADOR DE BACKUP AUTOMATIZADO - I-EDUCAR & I-DIÁRIO -> MINIO  "
echo "======================================================================"
echo -e "${NC}"

# 1. Checagem de privilégios de root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERRO] Este instalador precisa ser executado como root (sudo).${NC}" >&2
   exit 1
fi

INSTALL_DIR="/opt/ieducar-backup"
CONFIG_DIR="/etc/ieducar-backup"
ENV_FILE="${CONFIG_DIR}/.env"

# 2. Instalação de pacotes essenciais
echo -e "${BLUE}[1/6] Atualizando repositórios e instalando dependências do sistema...${NC}"
export DEBIAN_FRONTEND=noninteractive

if command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        curl wget git cron tar gzip postgresql-client ca-certificates
    systemctl enable cron >/dev/null 2>&1 || true
    systemctl start cron >/dev/null 2>&1 || true
elif command -v yum &>/dev/null; then
    yum install -y curl wget git cronie tar gzip postgresql ca-certificates
    systemctl enable crond >/dev/null 2>&1 || true
    systemctl start crond >/dev/null 2>&1 || true
fi

# 2.1 Configuração Inteligente de SWAP (Otimização para Postgres & Rails)
echo -e "${BLUE}Verificando configuração de memória SWAP...${NC}"
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
if [[ -z "$SWAP_TOTAL" || "$SWAP_TOTAL" -eq 0 ]]; then
    echo -e "${YELLOW}Nenhum swap ativo detectado. Criando 4GB de SWAP para estabilidade...${NC}"
    if [ ! -f /swapfile ]; then
        fallocate -l 4G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096 status=none
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null 2>&1
    fi
    swapon /swapfile 2>/dev/null || true
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
    fi
    echo -e "${GREEN}SWAP de 4GB criado e ativado com sucesso!${NC}"
else
    echo -e "${GREEN}SWAP já existente no sistema (${SWAP_TOTAL}MB). Nenhuma alteração necessária.${NC}"
fi

# 3. Preparar diretórios da aplicação
echo -e "${BLUE}[2/6] Configurando diretório de instalação em ${INSTALL_DIR}...${NC}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "/var/backups/ieducar-idiario"

# Se o script está sendo rodado diretamente da pasta clonada, copia; senão faz download dos scripts
if [[ -f "$(pwd)/scripts/backup.sh" ]]; then
    echo -e "${GREEN}Copiando arquivos locais para ${INSTALL_DIR}...${NC}"
    mkdir -p "${INSTALL_DIR}"
    cp -r "$(pwd)"/* "${INSTALL_DIR}/"
else
    echo -e "${BLUE}Baixando os scripts mais recentes do repositório...${NC}"
    REPO_URL="${GITHUB_REPO_URL:-https://github.com/douglas14031999/ieducar-idiario-backup.git}"
    if [[ -d "${INSTALL_DIR}/.git" ]]; then
        echo -e "${GREEN}Sincronizando arquivos com a versão mais recente...${NC}"
        git -C "${INSTALL_DIR}" fetch origin main >/dev/null 2>&1 || true
        git -C "${INSTALL_DIR}" reset --hard origin/main >/dev/null 2>&1 || true
    else
        rm -rf "${INSTALL_DIR}"
        if ! git clone "${REPO_URL}" "${INSTALL_DIR}" 2>/dev/null; then
            echo -e "${YELLOW}Tentando download direto via tarball...${NC}"
            mkdir -p "${INSTALL_DIR}"
            curl -fsSL "https://github.com/douglas14031999/ieducar-idiario-backup/archive/refs/heads/main.tar.gz" | tar -xz --strip-components=1 -C "${INSTALL_DIR}"
        fi
    fi
fi

# Garantir permissões executáveis nos scripts
chmod +x "${INSTALL_DIR}/scripts/"*.sh || true

# 4. Instalar o MinIO Server (RELEASE.2021-04-22T15-44-28Z) e MinIO Client (mc)
echo -e "${BLUE}[3/6] Instalando e configurando o MinIO na versão RELEASE.2021-04-22T15-44-28Z...${NC}"
"${INSTALL_DIR}/scripts/install-minio.sh"

# 5. Configurar arquivo de variáveis .env
echo -e "${BLUE}[4/6] Configurando credenciais e parâmetros em ${ENV_FILE}...${NC}"
if [[ ! -f "${ENV_FILE}" ]]; then
    if [[ -f "${INSTALL_DIR}/config/backup.env.example" ]]; then
        cp "${INSTALL_DIR}/config/backup.env.example" "${ENV_FILE}"
    fi

    echo ""
    echo -e "${YELLOW}--- CONFIGURAÇÃO DE CREDENCIAIS ---${NC}"
    echo "Pressione ENTER para manter os valores padrão sugeridos."
    echo ""

    # Leitura interativa via /dev/tty para funcionar com curl | bash
    read_interactive() {
        local prompt_text="$1"
        local default_val="$2"
        local var_name="$3"
        local user_val=""

        if [ -e /dev/tty ]; then
            read -r -p "$prompt_text" user_val < /dev/tty || true
        fi
        eval "$var_name=\"\${user_val:-$default_val}\""
    }

    read_interactive "Usuário MinIO [admin]: " "admin" IN_MINIO_USER
    read_interactive "Senha MinIO [Douglas140399.]: " "Douglas140399." IN_MINIO_PASS
    read_interactive "Bucket MinIO [ieducar-backups]: " "ieducar-backups" IN_MINIO_BUCKET
    read_interactive "Dias de retenção automática [20]: " "20" IN_RETENTION
    read_interactive "Senha do banco PostgreSQL do i-Educar (ou enter para pular): " "" IN_IEDUCAR_PASS
    read_interactive "Senha do banco PostgreSQL do i-Diário (ou enter para pular): " "" IN_IDIARIO_PASS

    # Atualizar o .env com os dados informados
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

    # Blindar permissões do arquivo .env
    chmod 600 "${ENV_FILE}"
    chown root:root "${ENV_FILE}"
    echo -e "${GREEN}Arquivo de configuração criado com permissão restrita 600!${NC}"
else
    echo -e "${GREEN}Arquivo de configuração já existente em ${ENV_FILE}. Mantido.${NC}"
fi

# 6. Configurar Agendamento Automático no Cron (/etc/cron.d/ieducar-backup)
echo -e "${BLUE}[5/6] Configurando agendamento diário no Cron (23:59)...${NC}"
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

# Criar links simbólicos globais no sistema para facilitar comandos manuais
ln -sf "${INSTALL_DIR}/scripts/backup.sh" /usr/local/bin/ieducar-backup
ln -sf "${INSTALL_DIR}/scripts/restore.sh" /usr/local/bin/ieducar-restore

# 7. Resumo e Teste Opcional
echo -e "${BLUE}[6/6] Instalação concluída com êxito!${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e " ${GREEN}Tudo pronto para os backups automáticos!${NC}"
echo -e " • MinIO Web Console: ${YELLOW}http://$(curl -s https://api.ipify.org || echo "IP_VPS"):9000${NC}"
echo -e " • Configuração (.env): ${YELLOW}${ENV_FILE}${NC}"
echo -e " • Logs de execução:   ${YELLOW}/var/log/ieducar-backup.log${NC}"
echo -e " • Horário de Backup:  ${YELLOW}Todos os dias às 23:59${NC}"
echo -e " • Retenção no MinIO:  ${YELLOW}20 dias de histórico mantidos${NC}"
echo ""
echo -e " Comandos úteis disponíveis em qualquer lugar do terminal:"
echo -e "   - Para rodar o backup agora:  ${GREEN}ieducar-backup${NC}"
echo -e "   - Para restaurar um backup:   ${GREEN}ieducar-restore${NC}"
echo -e "${CYAN}======================================================================${NC}"

# Perguntar se deseja testar agora
RUN_TEST="n"
if [ -e /dev/tty ]; then
    read -r -p "Deseja rodar o primeiro teste de backup agora? (s/N): " RUN_TEST < /dev/tty || true
fi

if [[ "$RUN_TEST" =~ ^[sS]$ ]]; then
    echo -e "${BLUE}Iniciando backup de teste...${NC}"
    /usr/local/bin/ieducar-backup
fi
