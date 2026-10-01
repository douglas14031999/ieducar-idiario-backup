#!/usr/bin/env bash
# ==============================================================================
# Script: common.sh
# Objetivo: Funções compartilhadas para logs, leitura de variáveis, checagens
#           de integridade e envio de notificações.
# ==============================================================================

# Cores
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m'

LOG_FILE="${LOG_FILE:-/var/log/ieducar-backup.log}"

# Timestamp padrão
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

_write_log() {
    local level="$1"
    local message="$2"
    local color="$3"
    local ts
    ts=$(get_timestamp)

    # Saída no terminal
    echo -e "${color}[${ts}] [${level}]${COLOR_NC} ${message}"

    # Saída no arquivo de log (sem códigos de cor ANSI)
    if [[ -n "${LOG_FILE:-}" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        echo "[${ts}] [${level}] ${message}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_info() { _write_log "INFO" "$1" "$COLOR_BLUE"; }
log_success() { _write_log "SUCCESS" "$1" "$COLOR_GREEN"; }
log_warn() { _write_log "WARN" "$1" "$COLOR_YELLOW"; }
log_error() { _write_log "ERROR" "$1" "$COLOR_RED"; }

# Carregar variáveis de ambiente com segurança
load_env() {
    local env_path="${1:-/etc/ieducar-backup/.env}"
    if [[ ! -f "$env_path" ]]; then
        if [[ -f "$(dirname "$0")/../config/backup.env" ]]; then
            env_path="$(dirname "$0")/../config/backup.env"
        elif [[ -f "$(dirname "$0")/../.env" ]]; then
            env_path="$(dirname "$0")/../.env"
        else
            log_error "Arquivo de configuração não encontrado em: $env_path"
            return 1
        fi
    fi

    # Verificar permissões seguras se estiver rodando como root
    if [[ $EUID -eq 0 ]]; then
        chmod 600 "$env_path" 2>/dev/null || true
    fi

    log_info "Carregando configurações de: $env_path"
    # shellcheck disable=SC1090
    source "$env_path"
    return 0
}

# Enviar notificação para Discord e Telegram se configurados
send_notification() {
    local status="$1"    # SUCCESS ou FAILED
    local message="$2"
    local host_ip
    host_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "VPS")

    # Discord Webhook
    if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
        local color_code=65280 # Verde
        if [[ "$status" != "SUCCESS" ]]; then
            color_code=16711680 # Vermelho
        fi

        local payload
        payload=$(cat <<EOF
{
  "embeds": [{
    "title": "Backup Automático: ${status}",
    "description": "${message}",
    "color": ${color_code},
    "fields": [
      {"name": "Host", "value": "${host_ip}", "inline": true},
      {"name": "Data", "value": "$(get_timestamp)", "inline": true}
    ]
  }]
}
EOF
)
        curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi

    # Telegram
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        local icon="✅"
        if [[ "$status" != "SUCCESS" ]]; then
            icon="🚨"
        fi
        local tg_text="${icon} *Backup Automático: ${status}*%0A*Host:* \`${host_ip}\`%0A*Data:* $(get_timestamp)%0A*Detalhes:* ${message}"
        curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=${tg_text}&parse_mode=Markdown" >/dev/null 2>&1 || true
    fi
}

# Checar ferramentas e espaço em disco
check_prerequisites() {
    log_info "Validando pré-requisitos do sistema..."

    # Verificar MinIO Client
    if ! command -v mc &>/dev/null && [[ ! -x /usr/local/bin/mc ]]; then
        log_error "MinIO Client (mc) não encontrado. Execute o instalador ou install-minio.sh primeiro."
        return 1
    fi

    # Ferramentas de compactação
    for cmd in tar gzip; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Comando essencial não encontrado: $cmd"
            return 1
        fi
    done

    # Checar espaço livre em disco no diretório temporário (mínimo 500MB livre)
    local target_dir="${LOCAL_BACKUP_DIR:-/var/backups/ieducar-idiario}"
    mkdir -p "$target_dir"
    local free_kb
    free_kb=$(df -k "$target_dir" | awk 'NR==2 {print $4}')
    if [[ $free_kb -lt 512000 ]]; then
        log_warn "Espaço em disco em $target_dir pode ser insuficiente (< 500MB disponíveis)."
    fi

    return 0
}

# Detectar se o banco roda em container Docker ou Baremetal
detect_execution_mode() {
    local app_name="$1"        # "ieducar" ou "idiario"
    local configured_mode="$2" # "auto", "docker" ou "baremetal"
    local container_hint="$3"

    if [[ "$configured_mode" != "auto" ]]; then
        echo "$configured_mode"
        return 0
    fi

    # Modo Auto: Verificar se docker está disponível e se há container com nome correspondente
    if command -v docker &>/dev/null && docker ps &>/dev/null; then
        local found_container
        found_container=$(docker ps --format '{{.Names}}' | grep -iE "$container_hint|$app_name.*(db|postgres)" | head -n 1 || true)
        if [[ -n "$found_container" ]]; then
            echo "docker:$found_container"
            return 0
        fi
    fi

    # Fallback para baremetal
    echo "baremetal"
    return 0
}
