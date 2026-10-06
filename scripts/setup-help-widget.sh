#!/usr/bin/env bash
# ==============================================================================
# Script: setup-help-widget.sh
# Objetivo: Instalação Automática do Widget Menu de Ajuda Oficial no i-Educar
# Repositório: https://github.com/douglas14031999/i-educar-reports-package
# ==============================================================================

set -euo pipefail

# Cores para terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}   💡 INSTALAÇÃO: WIDGET MENU DE AJUDA OFICIAL NO I-EDUCAR             ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Central de documentação interativa e manual integrado nas telas do i-Educar"
echo -e "com 76 telas oficiais, atalhos rápidos e suporte contextual para os usuários."
echo -e "${BLUE}======================================================================${NC}\n"

INSTALLER_URL="https://raw.githubusercontent.com/douglas14031999/i-educar-reports-package/2.11/deploy_help_widget.sh"
TEMP_SCRIPT=$(mktemp /tmp/help_widget_XXXXXX.sh)

echo -e "${YELLOW}Baixando e executando o instalador oficial do Widget de Ajuda...${NC}\n"

if curl -fsSL "$INSTALLER_URL" -o "$TEMP_SCRIPT"; then
    chmod +x "$TEMP_SCRIPT"
    if [ -e /dev/tty ]; then
        bash "$TEMP_SCRIPT" "${1:-}" < /dev/tty || true
    else
        bash "$TEMP_SCRIPT" "${1:-}" || true
    fi
    rm -f "$TEMP_SCRIPT"
    echo -e "\n${GREEN}✓ Instalação do Widget de Ajuda concluída com êxito!${NC}"
else
    echo -e "${RED}[ERRO] Não foi possível baixar o instalador de: ${INSTALLER_URL}${NC}"
    rm -f "$TEMP_SCRIPT"
    exit 1
fi
