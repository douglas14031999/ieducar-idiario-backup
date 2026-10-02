#!/usr/bin/env bash
# ==============================================================================
# Script: install-omr.sh
# Objetivo: Instalação Automatizada do Gabarito OMR & Elaborador de Provas
# Repositório: https://github.com/douglas14031999/correcao-provas
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}   🎯 INSTALAÇÃO: GABARITO OMR & ELABORADOR DE PROVAS (BNCC)          ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Sistema open-source para elaboração de avaliações, geração de folhas"
echo -e "de respostas em PDF e correção instantânea via visão computacional (OMR)."
echo -e "Stack: FastAPI, Python, OpenCV, PostgreSQL, Nginx e Systemd."
echo -e "${BLUE}======================================================================${NC}\n"

CONFIRM="s"
if [ -e /dev/tty ]; then
    printf "${CYAN}Deseja iniciar a instalação do Gabarito OMR agora? (s/N) [s]: ${NC}" > /dev/tty
    read -r CONFIRM < /dev/tty || true
    CONFIRM="${CONFIRM:-s}"
fi

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Instalação cancelada pelo usuário.${NC}"
    exit 0
fi

echo -e "${YELLOW}Baixando e executando o instalador oficial do Gabarito OMR...${NC}\n"

INSTALLER_URL="https://raw.githubusercontent.com/douglas14031999/correcao-provas/main/install.sh"
TEMP_SCRIPT=$(mktemp /tmp/omr_install_XXXXXX.sh)

if curl -fsSL "$INSTALLER_URL" -o "$TEMP_SCRIPT"; then
    chmod +x "$TEMP_SCRIPT"
    if [ -e /dev/tty ]; then
        bash "$TEMP_SCRIPT" < /dev/tty || true
    else
        bash "$TEMP_SCRIPT" || true
    fi
    rm -f "$TEMP_SCRIPT"
else
    echo -e "${RED}[ERRO] Não foi possível baixar o instalador de: ${INSTALLER_URL}${NC}"
    rm -f "$TEMP_SCRIPT"
    exit 1
fi
