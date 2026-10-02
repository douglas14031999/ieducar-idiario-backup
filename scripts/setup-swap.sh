#!/usr/bin/env bash
# ==============================================================================
# Script: setup-swap.sh
# Objetivo: Configurar e otimizar memória virtual (SWAP) de 4GB no Linux
#           com vm.swappiness=10 e persistência no /etc/fstab
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERRO] Este utilitário precisa ser executado como root (sudo).${NC}" >&2
   exit 1
fi

echo -e "${BLUE}=== Otimização de Performance: Memória SWAP ===${NC}"

SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')

echo -e " • Memória RAM Física:  ${YELLOW}${RAM_TOTAL} MB${NC}"
echo -e " • Memória SWAP Atual:  ${YELLOW}${SWAP_TOTAL:-0} MB${NC} (Em uso: ${SWAP_USED:-0} MB)"
echo ""

if [[ -z "$SWAP_TOTAL" || "$SWAP_TOTAL" -eq 0 ]]; then
    echo -e "${YELLOW}Aviso: Nenhuma memória SWAP ativa no servidor.${NC}"
    echo -e "Aplicações como PostgreSQL, i-Educar e i-Diário (Rails/Sidekiq)"
    echo -e "podem sofrer travamentos (OOM Killer) durante picos de uso ou backups."
else
    echo -e "${GREEN}• SWAP já detectado no sistema.${NC}"
fi
echo ""

CREATE_SWAP="s"
if [ -e /dev/tty ]; then
    read -r -p "Deseja criar/redefinir um arquivo SWAP de 4GB agora? (S/n): " CREATE_SWAP < /dev/tty || true
else
    read -r -p "Deseja criar/redefinir um arquivo SWAP de 4GB agora? (S/n): " CREATE_SWAP || true
fi
CREATE_SWAP="${CREATE_SWAP:-s}"

if [[ "$CREATE_SWAP" =~ ^[sSyY]$ || -z "$CREATE_SWAP" ]]; then
    echo -e "${BLUE}Configurando arquivo SWAP de 4GB em /swapfile...${NC}"

    # Desativa /swapfile se já estiver em uso
    if grep -q "/swapfile" /proc/swaps 2>/dev/null; then
        echo -e "${BLUE}Desativando /swapfile anterior...${NC}"
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
    fi

    # Criar arquivo de 4GB
    if ! fallocate -l 4G /swapfile 2>/dev/null; then
        echo -e "${BLUE}Alocando espaço via dd...${NC}"
        dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096
    fi

    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile

    # Persistir no fstab
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # Otimização de parâmetros do kernel
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    if grep -q "vm.swappiness" /etc/sysctl.conf; then
        sed -i 's/^vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
    else
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
    fi

    sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1 || true
    if grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        sed -i 's/^vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf
    else
        echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf
    fi

    FINAL_SWAP=$(free -m | awk '/Swap:/ {print $2}')
    echo -e "\n${GREEN}✓ Memória SWAP de ${FINAL_SWAP} MB configurada e ativada com sucesso!${NC}"
    echo -e " • Parâmetro vm.swappiness: 10 (otimizado para servidores de banco)"
    echo -e " • Parâmetro vm.vfs_cache_pressure: 50"
else
    echo -e "${YELLOW}Configuração de SWAP ignorada pelo usuário.${NC}"
fi
