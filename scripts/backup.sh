#!/usr/bin/env bash
# ==============================================================================
# Script: backup.sh
# Objetivo: Executa o backup completo (Banco de Dados PostgreSQL + Uploads)
#           do i-Educar e do i-Diário, envia para o MinIO e aplica retenção de 20 dias.
# Agendamento: Chamado via Cron diariamente às 23:59.
# ==============================================================================

set -euo pipefail

# Diretório base do script (resolvendo symlinks)
TARGET_FILE="${BASH_SOURCE[0]}"
while [ -h "$TARGET_FILE" ]; do
    TARGET_DIR="$(cd -P "$(dirname "$TARGET_FILE")" && pwd)"
    TARGET_FILE="$(readlink "$TARGET_FILE")"
    [[ $TARGET_FILE != /* ]] && TARGET_FILE="$TARGET_DIR/$TARGET_FILE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$TARGET_FILE")" && pwd)"

# Importar rotinas comuns
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# Trap para capturar falhas inesperadas
handle_error() {
    local line=$1
    local cmd=$2
    log_error "O processo de backup falhou na linha ${line} (comando: ${cmd})."
    send_notification "FAILED" "Erro crítico durante a execução do backup no comando '${cmd}' (linha ${line}). Consulte ${LOG_FILE:-o log} para detalhes."
    # Limpar diretório temporário se existir
    if [[ -n "${WORK_DIR:-}" && -d "${WORK_DIR}" ]]; then
        rm -rf "${WORK_DIR}"
    fi
    exit 1
}
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

log_info "================================================================="
log_info "Iniciando Rotina de Backup Automático: i-Educar & i-Diário"
log_info "================================================================="

# Carregar variáveis de ambiente
load_env "${1:-/etc/ieducar-backup/.env}"

# Checar ferramentas necessárias
check_prerequisites

# Garantir utilitário mc no PATH se instalado em /usr/local/bin
export PATH="/usr/local/bin:$PATH"

# Definir timestamps e diretórios
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATE_FOLDER=$(date +"%Y/%m")
LOCAL_DIR="${LOCAL_BACKUP_DIR:-/var/backups/ieducar-idiario}"
WORK_DIR="${LOCAL_DIR}/temp_${TIMESTAMP}"
mkdir -p "${WORK_DIR}"

log_info "Diretório de trabalho temporário: ${WORK_DIR}"

# Validar/atualizar credenciais do MinIO Client (mc)
log_info "Verificando conexão com MinIO (${MINIO_ENDPOINT})..."
mc alias set "${MINIO_ALIAS:-local-minio}" "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" --api S3v4 >/dev/null 2>&1 || {
    log_error "Não foi possível conectar ao MinIO em ${MINIO_ENDPOINT}. Verifique se o serviço está rodando."
    exit 1
}
mc mb --ignore-existing "${MINIO_ALIAS}/${MINIO_BUCKET}" >/dev/null 2>&1 || true

BACKUP_FILES=()

# ==============================================================================
# 0. SINCRONIZAÇÃO PRÉ-BACKUP: I-DIÁRIO COM O I-EDUCAR
# ==============================================================================
if [[ "${SYNC_BEFORE_BACKUP:-false}" == "true" ]]; then
    log_info "--- Iniciando Sincronização Pré-Backup (i-Diário <-> i-Educar) ---"
    IDIARIO_PATH="${IDIARIO_APP_DIR:-/root/i-diario}"
    if [[ -d "$IDIARIO_PATH" ]]; then
        log_info "Disparando sincronização do i-Diário com a API do i-Educar..."
        export PATH="/root/.rbenv/shims:/root/.rbenv/bin:$PATH"
        SYNC_CMD="${IDIARIO_SYNC_COMMAND:-RAILS_ENV=production bundle exec rake ieducar_api:synchronize}"
        
        SYNC_OUTPUT=""
        SYNC_STATUS=0
        SYNC_OUTPUT=$(cd "$IDIARIO_PATH" && eval "$SYNC_CMD" 2>&1) || SYNC_STATUS=$?
        
        if [[ $SYNC_STATUS -eq 0 ]]; then
            log_success "Job de sincronização agendado no Sidekiq com sucesso!"
            WAIT_SEC="${IDIARIO_SYNC_WAIT_SECONDS:-15}"
            if [[ "$WAIT_SEC" -gt 0 ]]; then
                log_info "Aguardando ${WAIT_SEC}s para processamento das filas no Sidekiq..."
                sleep "$WAIT_SEC"
            fi
        else
            log_warn "Aviso ao disparar sincronização (código: ${SYNC_STATUS})."
            echo "$SYNC_OUTPUT" | while IFS= read -r line; do log_warn "  [sync] $line"; done
            if [[ "${IDIARIO_SYNC_IGNORE_FAILURES:-true}" != "true" ]]; then
                log_error "Abortando backup devido à falha na sincronização."
                exit 1
            fi
        fi
    else
        log_warn "Diretório do i-Diário (${IDIARIO_PATH}) não encontrado. Pulando sincronização."
    fi
fi

# ==============================================================================
# 1. BACKUP DO I-EDUCAR
# ==============================================================================
if [[ "${IEDUCAR_ENABLED:-true}" == "true" ]]; then
    log_info "--- Iniciando backup do i-Educar ---"
    MODE_INFO=$(detect_execution_mode "ieducar" "${IEDUCAR_MODE:-auto}" "${IEDUCAR_CONTAINER_DB:-ieducar-database}")

    # 1.1 Dump do Banco PostgreSQL
    DB_DUMP_FILE="${WORK_DIR}/ieducar_db_${TIMESTAMP}.sql.gz"
    log_info "Gerando dump do banco PostgreSQL do i-Educar (${MODE_INFO})..."

    if [[ "$MODE_INFO" =~ ^docker: ]]; then
        CONTAINER_NAME="${MODE_INFO#docker:}"
        log_info "Executando pg_dump dentro do container Docker: ${CONTAINER_NAME}..."
        docker exec -i -e PGPASSWORD="${IEDUCAR_DB_PASSWORD:-}" "${CONTAINER_NAME}" pg_dump -U "${IEDUCAR_DB_USER:-ieducar}" -d "${IEDUCAR_DB_NAME:-ieducar}" --no-owner --clean | gzip > "${DB_DUMP_FILE}"
    else
        log_info "Executando pg_dump direto no host..."
        PGPASSWORD="${IEDUCAR_DB_PASSWORD:-}" pg_dump \
            -h "${IEDUCAR_DB_HOST:-127.0.0.1}" \
            -p "${IEDUCAR_DB_PORT:-5432}" \
            -U "${IEDUCAR_DB_USER:-ieducar}" \
            -d "${IEDUCAR_DB_NAME:-ieducar}" \
            --no-owner --clean | gzip > "${DB_DUMP_FILE}"
    fi

    if [[ -s "${DB_DUMP_FILE}" ]]; then
        log_success "Dump do i-Educar gerado com sucesso: $(du -h "${DB_DUMP_FILE}" | awk '{print $1}')"
        BACKUP_FILES+=("${DB_DUMP_FILE}")
    else
        log_warn "O arquivo de dump do i-Educar foi gerado vazio ou não foi concluído."
    fi

    # 1.2 Compactação dos Arquivos de Uploads/Storage
    if [[ -n "${IEDUCAR_STORAGE_PATH:-}" && -d "${IEDUCAR_STORAGE_PATH}" ]]; then
        STORAGE_FILE="${WORK_DIR}/ieducar_storage_${TIMESTAMP}.tar.gz"
        log_info "Compactando storage/uploads do i-Educar (${IEDUCAR_STORAGE_PATH})..."
        tar -czf "${STORAGE_FILE}" -C "${IEDUCAR_STORAGE_PATH}" .
        log_success "Storage do i-Educar compactado: $(du -h "${STORAGE_FILE}" | awk '{print $1}')"
        BACKUP_FILES+=("${STORAGE_FILE}")
    else
        log_info "Caminho de storage do i-Educar não configurado ou inexistente (${IEDUCAR_STORAGE_PATH:-vazio}). Pulando."
    fi
fi

# ==============================================================================
# 2. BACKUP DO I-DIÁRIO
# ==============================================================================
if [[ "${IDIARIO_ENABLED:-true}" == "true" ]]; then
    log_info "--- Iniciando backup do i-Diário ---"
    MODE_INFO=$(detect_execution_mode "idiario" "${IDIARIO_MODE:-auto}" "${IDIARIO_CONTAINER_DB:-idiario-database}")

    # 2.1 Dump do Banco PostgreSQL
    DB_DUMP_FILE="${WORK_DIR}/idiario_db_${TIMESTAMP}.sql.gz"
    log_info "Gerando dump do banco PostgreSQL do i-Diário (${MODE_INFO})..."

    if [[ "$MODE_INFO" =~ ^docker: ]]; then
        CONTAINER_NAME="${MODE_INFO#docker:}"
        log_info "Executando pg_dump dentro do container Docker: ${CONTAINER_NAME}..."
        docker exec -i -e PGPASSWORD="${IDIARIO_DB_PASSWORD:-}" "${CONTAINER_NAME}" pg_dump -U "${IDIARIO_DB_USER:-idiario}" -d "${IDIARIO_DB_NAME:-idiario}" --no-owner --clean | gzip > "${DB_DUMP_FILE}"
    else
        log_info "Executando pg_dump direto no host..."
        PGPASSWORD="${IDIARIO_DB_PASSWORD:-}" pg_dump \
            -h "${IDIARIO_DB_HOST:-127.0.0.1}" \
            -p "${IDIARIO_DB_PORT:-5432}" \
            -U "${IDIARIO_DB_USER:-idiario}" \
            -d "${IDIARIO_DB_NAME:-idiario}" \
            --no-owner --clean | gzip > "${DB_DUMP_FILE}"
    fi

    if [[ -s "${DB_DUMP_FILE}" ]]; then
        log_success "Dump do i-Diário gerado com sucesso: $(du -h "${DB_DUMP_FILE}" | awk '{print $1}')"
        BACKUP_FILES+=("${DB_DUMP_FILE}")
    else
        log_warn "O arquivo de dump do i-Diário foi gerado vazio ou não foi concluído."
    fi

    # 2.2 Compactação dos Arquivos de Uploads/Storage
    if [[ -n "${IDIARIO_STORAGE_PATH:-}" && -d "${IDIARIO_STORAGE_PATH}" ]]; then
        STORAGE_FILE="${WORK_DIR}/idiario_storage_${TIMESTAMP}.tar.gz"
        log_info "Compactando storage/uploads do i-Diário (${IDIARIO_STORAGE_PATH})..."
        tar -czf "${STORAGE_FILE}" -C "${IDIARIO_STORAGE_PATH}" .
        log_success "Storage do i-Diário compactado: $(du -h "${STORAGE_FILE}" | awk '{print $1}')"
        BACKUP_FILES+=("${STORAGE_FILE}")
    else
        log_info "Caminho de storage do i-Diário não configurado ou inexistente (${IDIARIO_STORAGE_PATH:-vazio}). Pulando."
    fi
fi

# ==============================================================================
# 3. ENVIO PARA O MINIO
# ==============================================================================
if [[ ${#BACKUP_FILES[@]} -eq 0 ]]; then
    log_error "Nenhum arquivo de backup foi gerado. Abortando upload."
    exit 1
fi

log_info "--- Enviando backups para o MinIO (${MINIO_BUCKET}/${DATE_FOLDER}) ---"
UPLOAD_SUMMARY=""
for file in "${BACKUP_FILES[@]}"; do
    filename=$(basename "$file")
    target_path="${MINIO_ALIAS}/${MINIO_BUCKET}/${DATE_FOLDER}/${filename}"
    log_info "Enviando ${filename}..."
    mc cp --quiet "$file" "$target_path"
    filesize=$(du -h "$file" | awk '{print $1}')
    UPLOAD_SUMMARY+="${filename} (${filesize})\n"
    log_success "Upload concluído: ${target_path} [${filesize}]"
done

# ==============================================================================
# 4. POLÍTICA DE RETENÇÃO (20 DIAS)
# ==============================================================================
RETENTION="${RETENTION_DAYS:-20}"
log_info "--- Aplicando política de retenção de ${RETENTION} dias ---"

# 4.1 Limpeza no MinIO (arquivos mais antigos que 20 dias)
log_info "Expurgando arquivos com mais de ${RETENTION} dias no bucket do MinIO..."
mc rm --recursive --force --older-than "${RETENTION}d" "${MINIO_ALIAS}/${MINIO_BUCKET}/" >/dev/null 2>&1 || {
    log_warn "Aviso ao expurgar no MinIO (pode ser o primeiro ciclo de backup)."
}

# 4.2 Limpeza local de dumps e diretórios antigos
log_info "Limpando diretório temporário de execução..."
rm -rf "${WORK_DIR}"

log_info "Removendo backups locais antigos (> ${RETENTION} dias)..."
find "${LOCAL_DIR}" -type f \( -name "*.sql.gz" -o -name "*.tar.gz" \) -mtime "+${RETENTION}" -delete 2>/dev/null || true

# ==============================================================================
# 5. FINALIZAÇÃO E NOTIFICAÇÃO
# ==============================================================================
END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
log_success "================================================================="
log_success "Backup concluído com sucesso em: ${END_TIME}"
log_success "================================================================="

send_notification "SUCCESS" "Backup diário realizado com sucesso e sincronizado no MinIO (${MINIO_BUCKET}):\n${UPLOAD_SUMMARY}"

exit 0
