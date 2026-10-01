#!/usr/bin/env bash
# ==============================================================================
# Script: restore.sh
# Objetivo: Utilitário interativo para listar e restaurar backups do i-Educar
#           e do i-Diário armazenados no MinIO.
# ==============================================================================

set -euo pipefail

TARGET_FILE="${BASH_SOURCE[0]}"
while [ -h "$TARGET_FILE" ]; do
    TARGET_DIR="$(cd -P "$(dirname "$TARGET_FILE")" && pwd)"
    TARGET_FILE="$(readlink "$TARGET_FILE")"
    [[ $TARGET_FILE != /* ]] && TARGET_FILE="$TARGET_DIR/$TARGET_FILE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$TARGET_FILE")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

load_env "${1:-/etc/ieducar-backup/.env}"
export PATH="/usr/local/bin:$PATH"

log_info "================================================================="
log_info "Assistente de Restauração (Disaster Recovery)"
log_info "================================================================="

# 1. Listar backups disponíveis no MinIO
log_info "Backups disponíveis no MinIO (${MINIO_ALIAS}/${MINIO_BUCKET}):"
echo -e "${COLOR_CYAN}-----------------------------------------------------------------${COLOR_NC}"
mc ls "${MINIO_ALIAS}/${MINIO_BUCKET}" --recursive
echo -e "${COLOR_CYAN}-----------------------------------------------------------------${COLOR_NC}"

echo ""
echo "Digite o caminho relativo do arquivo no bucket que deseja restaurar"
echo "(Exemplo: 2026/10/ieducar_db_20261001_235900.sql.gz):"
read -r -p "Arquivo: " CHOSEN_FILE

if [[ -z "$CHOSEN_FILE" ]]; then
    log_error "Nenhum arquivo informado. Operação cancelada."
    exit 1
fi

DEST_DIR="/tmp/ieducar_restore"
mkdir -p "$DEST_DIR"
LOCAL_RESTORE_FILE="${DEST_DIR}/$(basename "$CHOSEN_FILE")"

log_info "Baixando ${CHOSEN_FILE} do MinIO..."
mc cp "${MINIO_ALIAS}/${MINIO_BUCKET}/${CHOSEN_FILE}" "${LOCAL_RESTORE_FILE}"

log_success "Arquivo baixado para: ${LOCAL_RESTORE_FILE}"

# Identificar tipo de restauração
if [[ "$LOCAL_RESTORE_FILE" =~ _db_.*\.sql\.gz$ ]]; then
    # É um backup de banco
    if [[ "$LOCAL_RESTORE_FILE" =~ ieducar ]]; then
        APP="ieducar"
        DB_NAME="${IEDUCAR_DB_NAME:-ieducar}"
        DB_USER="${IEDUCAR_DB_USER:-ieducar}"
        DB_PASS="${IEDUCAR_DB_PASSWORD:-}"
        DB_HOST="${IEDUCAR_DB_HOST:-127.0.0.1}"
        DB_PORT="${IEDUCAR_DB_PORT:-5432}"
        MODE_INFO=$(detect_execution_mode "ieducar" "${IEDUCAR_MODE:-auto}" "${IEDUCAR_CONTAINER_DB:-ieducar-database}")
    else
        APP="idiario"
        DB_NAME="${IDIARIO_DB_NAME:-idiario}"
        DB_USER="${IDIARIO_DB_USER:-idiario}"
        DB_PASS="${IDIARIO_DB_PASSWORD:-}"
        DB_HOST="${IDIARIO_DB_HOST:-127.0.0.1}"
        DB_PORT="${IDIARIO_DB_PORT:-5432}"
        MODE_INFO=$(detect_execution_mode "idiario" "${IDIARIO_MODE:-auto}" "${IDIARIO_CONTAINER_DB:-idiario-database}")
    fi

    echo -e "${COLOR_YELLOW}[ATENÇÃO] Esta ação irá sobrescrever os dados existentes no banco '${DB_NAME}' do ${APP}!${COLOR_NC}"
    read -r -p "Deseja prosseguir com a restauração do banco? (s/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
        log_info "Restaurando banco de dados..."
        if [[ "$MODE_INFO" =~ ^docker: ]]; then
            CONTAINER_NAME="${MODE_INFO#docker:}"
            gunzip -c "${LOCAL_RESTORE_FILE}" | docker exec -i -e PGPASSWORD="${DB_PASS}" "${CONTAINER_NAME}" psql -U "${DB_USER}" -d "${DB_NAME}"
        else
            gunzip -c "${LOCAL_RESTORE_FILE}" | PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"
        fi
        log_success "Banco de dados '${DB_NAME}' restaurado com sucesso!"
    else
        log_info "Restauração de banco cancelada pelo usuário."
    fi

elif [[ "$LOCAL_RESTORE_FILE" =~ _storage_.*\.tar\.gz$ ]]; then
    echo "Informe o diretório de destino para descompactar os arquivos:"
    read -r -p "Diretório de destino: " TARGET_PATH
    if [[ -n "$TARGET_PATH" ]]; then
        mkdir -p "$TARGET_PATH"
        tar -xzf "${LOCAL_RESTORE_FILE}" -C "$TARGET_PATH"
        log_success "Arquivos restaurados em: ${TARGET_PATH}"
    fi
fi

# Limpeza
rm -rf "$DEST_DIR"
log_info "Operação finalizada."
