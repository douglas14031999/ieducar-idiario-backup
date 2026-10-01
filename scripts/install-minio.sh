#!/usr/bin/env bash
# ==============================================================================
# Script: install-minio.sh
# Objetivo: Instala e configura o MinIO Server versão RELEASE.2021-04-22T15-44-28Z
#           e o MinIO Client (mc) como serviço systemd no Linux (x86_64).
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCESSO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1" >&2; }

# Garantir execução como root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script precisa ser executado como root."
   exit 1
fi

# Carregar variáveis de ambiente se existirem
ENV_FILE="${ENV_FILE:-/etc/ieducar-backup/.env}"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

# Parâmetros padrão
MINIO_VERSION="RELEASE.2021-04-22T15-44-28Z"
MINIO_BIN_URL="https://github.com/minio/minio/releases/download/${MINIO_VERSION}/minio.linux-amd64.${MINIO_VERSION}"
MC_BIN_URL="https://dl.min.io/client/mc/release/linux-amd64/mc"

MINIO_DATA_DIR="${MINIO_DATA_DIR:-/data/minio}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-admin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-Douglas140399.}"
MINIO_BUCKET="${MINIO_BUCKET:-ieducar-backups}"
MINIO_ALIAS="${MINIO_ALIAS:-local-minio}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://127.0.0.1:9000}"

log_info "==> Iniciando instalação do MinIO (${MINIO_VERSION})..."

# 1. Instalar dependências essenciais
log_info "Verificando dependências básicas (curl, wget, tar)..."
if command -v apt-get &>/dev/null; then
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y -qq curl wget ca-certificates >/dev/null 2>&1 || true
elif command -v yum &>/dev/null; then
    yum install -y curl wget ca-certificates >/dev/null 2>&1 || true
fi

# 2. Download do binário do MinIO Server
log_info "Baixando o MinIO Server da versão ${MINIO_VERSION}..."
if [[ ! -f /usr/local/bin/minio ]] || ! /usr/local/bin/minio --version 2>&1 | grep -q "${MINIO_VERSION}"; then
    curl -fsSL --retry 3 "${MINIO_BIN_URL}" -o /usr/local/bin/minio
    chmod +x /usr/local/bin/minio
    log_success "MinIO Server instalado em /usr/local/bin/minio"
else
    log_info "MinIO Server já está instalado na versão correta."
fi

# 3. Download do MinIO Client (mc)
log_info "Baixando o MinIO Client (mc)..."
if [[ ! -f /usr/local/bin/mc ]]; then
    curl -fsSL --retry 3 "${MC_BIN_URL}" -o /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
    log_success "MinIO Client (mc) instalado em /usr/local/bin/mc"
else
    log_info "MinIO Client (mc) já está instalado."
fi

# 4. Criar usuário e grupo de sistema para isolamento
if ! id -u minio-user &>/dev/null; then
    log_info "Criando usuário de sistema 'minio-user'..."
    useradd -r minio-user -s /sbin/nologin || true
fi

# 5. Criar diretório de dados
log_info "Configurando diretório de armazenamento em: ${MINIO_DATA_DIR}..."
mkdir -p "${MINIO_DATA_DIR}"
chown -R minio-user:minio-user "${MINIO_DATA_DIR}"
chmod 750 "${MINIO_DATA_DIR}"

# 6. Criar arquivo de configuração /etc/default/minio
log_info "Gerando arquivo de configuração em /etc/default/minio..."
mkdir -p /etc/default
cat <<EOF > /etc/default/minio
# Configuração MinIO Server - RELEASE.2021-04-22T15-44-28Z
MINIO_VOLUMES="${MINIO_DATA_DIR}"
MINIO_OPTS="--address 0.0.0.0:9000"

# Credenciais (Compatíveis com v2021 e versões modernas)
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY}"
MINIO_ROOT_USER="${MINIO_ACCESS_KEY}"
MINIO_ROOT_PASSWORD="${MINIO_SECRET_KEY}"
EOF

chmod 600 /etc/default/minio
chown root:root /etc/default/minio

# 7. Criar serviço systemd
log_info "Configurando serviço systemd (/etc/systemd/system/minio.service)..."
cat <<'EOF' > /etc/systemd/system/minio.service
[Unit]
Description=MinIO Object Storage
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStartPre=/bin/sh -c "[ -d ${MINIO_VOLUMES} ] || mkdir -p ${MINIO_VOLUMES}"
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES
Restart=always
LimitNOFILE=65536
TasksMax=infinity
TimeoutSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF

# 8. Recarregar e iniciar serviço
log_info "Iniciando e habilitando o serviço MinIO..."
systemctl daemon-reload
systemctl enable minio.service
systemctl restart minio.service

# 9. Aguardar o serviço responder
log_info "Aguardando o MinIO inicializar na porta 9000..."
RETRIES=15
READY=0
while [[ $RETRIES -gt 0 ]]; do
    if curl -s -m 2 "http://127.0.0.1:9000/minio/health/live" >/dev/null 2>&1 || curl -s -m 2 "http://127.0.0.1:9000" >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 1
    RETRIES=$((RETRIES - 1))
done

if [[ $READY -eq 1 ]]; then
    log_success "MinIO está ativo e respondendo na porta 9000!"
else
    log_warn "O MinIO iniciou, mas a checagem HTTP demorou. Prosseguindo com o setup do alias..."
fi

# 10. Configurar alias do MinIO Client (mc)
log_info "Configurando alias '${MINIO_ALIAS}' no MinIO Client..."
/usr/local/bin/mc alias set "${MINIO_ALIAS}" "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" --api S3v4 || true

# 11. Criar bucket se não existir
log_info "Garantindo que o bucket '${MINIO_BUCKET}' exista..."
/usr/local/bin/mc mb --ignore-existing "${MINIO_ALIAS}/${MINIO_BUCKET}" || true

log_success "==> Instalação e configuração do MinIO concluída com sucesso!"
echo -e "${GREEN}------------------------------------------------------------${NC}"
echo -e " Endpoint Web: ${YELLOW}http://$(curl -s https://api.ipify.org || echo "IP_DA_SUA_VPS"):9000${NC}"
echo -e " Usuário:      ${YELLOW}${MINIO_ACCESS_KEY}${NC}"
echo -e " Bucket:       ${YELLOW}${MINIO_BUCKET}${NC}"
echo -e " Status:       ${GREEN}systemctl status minio.service${NC}"
echo -e "${GREEN}------------------------------------------------------------${NC}"
