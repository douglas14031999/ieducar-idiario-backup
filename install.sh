#!/usr/bin/env bash
# ==============================================================================
# Script: install.sh
# Objetivo: Instalador 'One-Liner' para automação de backups do i-Educar e i-Diário
#           com armazenamento no MinIO (RELEASE.2021-04-22T15-44-28Z) e Crontab.
# Uso via curl:
#   curl -fsSL https://raw.githubusercontent.com/douglas14031999/ieducar-idiario-backup/main/install.sh | bash
# ==============================================================================

set -euo pipefail

# Recuperar entrada do terminal se executado via pipe (curl | bash)
if [ ! -t 0 ]; then
    exec < /dev/tty || true
fi

# Cores
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
echo -e "${BLUE}[1/6] Instalando dependências básicas do sistema...${NC}"
if command -v apt-get &>/dev/null; then
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y -qq curl wget git cron tar gzip postgresql-client ca-certificates >/dev/null 2>&1 || true
    systemctl enable cron >/dev/null 2>&1 || true
    systemctl start cron >/dev/null 2>&1 || true
elif command -v yum &>/dev/null; then
    yum install -y curl wget git cronie tar gzip postgresql ca-certificates >/dev/null 2>&1 || true
    systemctl enable crond >/dev/null 2>&1 || true
    systemctl start crond >/dev/null 2>&1 || true
fi

# 3. Preparar diretórios da aplicação
echo -e "${BLUE}[2/6] Configurando diretório de instalação em ${INSTALL_DIR}...${NC}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "/var/backups/ieducar-idiario"

# Se o script está sendo rodado diretamente da pasta clonada, copia; senão faz download dos scripts
if [[ -f "$(pwd)/scripts/backup.sh" ]]; then
    echo -e "${GREEN}Copiando arquivos locais para ${INSTALL_DIR}...${NC}"
    cp -r "$(pwd)"/* "${INSTALL_DIR}/"
else
    echo -e "${BLUE}Baixando os scripts mais recentes do repositório...${NC}"
    REPO_URL="${GITHUB_REPO_URL:-https://github.com/douglas14031999/ieducar-idiario-backup.git}"
    if command -v git &>/dev/null; then
        if [[ -d "${INSTALL_DIR}/.git" ]]; then
            git -C "${INSTALL_DIR}" pull origin main || true
        else
            git clone "${REPO_URL}" "${INSTALL_DIR}" || true
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
    echo -e "${YELLOW}--- CONFIGURAÇÃO INTERATIVA DE CREDENCIAIS ---${NC}"
    echo "Pressione ENTER para manter os valores padrão recomendados."
    echo ""

    read -r -p "Usuário MinIO [admin]: " IN_MINIO_USER
    IN_MINIO_USER="${IN_MINIO_USER:-admin}"

    read -r -p "Senha MinIO [Douglas140399.]: " IN_MINIO_PASS
    IN_MINIO_PASS="${IN_MINIO_PASS:-Douglas140399.}"

    read -r -p "Bucket MinIO [ieducar-backups]: " IN_MINIO_BUCKET
    IN_MINIO_BUCKET="${IN_MINIO_BUCKET:-ieducar-backups}"

    read -r -p "Dias de retenção automática [20]: " IN_RETENTION
    IN_RETENTION="${IN_RETENTION:-20}"

    read -r -p "Senha do banco PostgreSQL do i-Educar: " IN_IEDUCAR_PASS
    read -r -p "Senha do banco PostgreSQL do i-Diário: " IN_IDIARIO_PASS

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
read -r -p "Deseja rodar o primeiro teste de backup agora? (s/N): " RUN_TEST
if [[ "$RUN_TEST" =~ ^[sS]$ ]]; then
    echo -e "${BLUE}Iniciando backup de teste...${NC}"
    /usr/local/bin/ieducar-backup
fi
