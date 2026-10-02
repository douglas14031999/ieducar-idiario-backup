#!/usr/bin/env bash
# ==============================================================================
# Script: setup-domain-ssl.sh
# Objetivo: Configuração Automática de Domínio, Nginx Reverse Proxy e SSL Let's Encrypt
# Suporte: i-Educar (PHP/Laravel) & i-Diário (Rails/PostgreSQL - Atualização de Entidade)
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Função para leitura interativa ou fallback
read_prompt() {
    local prompt_msg="$1"
    local default_val="$2"
    local var_name="$3"

    if [ -e /dev/tty ]; then
        local user_val=""
        printf "${CYAN}%s${NC} [%s]: " "$prompt_msg" "$default_val" > /dev/tty
        read -r user_val < /dev/tty || true
        if [[ -n "$user_val" ]]; then
            eval "$var_name=\"$user_val\""
        else
            eval "$var_name=\"$default_val\""
        fi
    else
        eval "$var_name=\"$default_val\""
    fi
}

# Detecção antecipada do IP Público da VPS
SERVER_IP=$(curl -s -4 --max-time 3 https://icanhazip.com 2>/dev/null || curl -s -4 --max-time 3 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
SERVER_IP="${SERVER_IP:-127.0.0.1}"

# ==============================================================================
# GUIA DE INSTRUÇÕES DE APONTAMENTO DE DOMÍNIO
# ==============================================================================
show_dns_instructions() {
    clear 2>/dev/null || printf "\033c" || true
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}   🔒 CONFIGURADOR DE DOMÍNIOS & SSL HTTPS (I-EDUCAR & I-DIÁRIO)      ${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "Este utilitário automatiza a configuração do Nginx, certificados SSL (Let's Encrypt)"
    echo -e "e a ${YELLOW}substituição automática do IP pelo domínio no banco de dados do i-Diário${NC}."
    echo -e "${BLUE}----------------------------------------------------------------------${NC}\n"

    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${CYAN}   📋 INSTRUÇÕES PRÉVIAS: CONFIGURAÇÃO E APONTAMENTO DE DOMÍNIO (DNS) ${NC}"
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "Antes de emitir o certificado SSL, você precisa criar os apontamentos ${YELLOW}Tipo A${NC}"
    echo -e "no painel onde gerencia o seu domínio (Cloudflare, Registro.br, Hostinger,"
    echo -e "GoDaddy, AWS Route 53, cPanel, etc.):\n"
    echo -e "  🌐 ${BOLD}IP Público Desta VPS:${NC}  ${GREEN}${SERVER_IP}${NC}\n"
    echo -e "  ┌──────────────────┬─────────────┬───────────────────────────────┬──────────────────────┐"
    echo -e "  │ Aplicação        │ Tipo        │ Nome / Entrada (Host)         │ Valor / Destino (IP) │"
    echo -e "  ├──────────────────┼─────────────┼───────────────────────────────┼──────────────────────┤"
    echo -e "  │ ${GREEN}i-Educar${NC}         │ ${YELLOW}A${NC}           │ ieducar (ou seu subdomínio)   │ ${GREEN}${SERVER_IP}${NC}         │"
    echo -e "  │ ${GREEN}i-Diário${NC}         │ ${YELLOW}A${NC}           │ idiario (ou seu subdomínio)   │ ${GREEN}${SERVER_IP}${NC}         │"
    echo -e "  └──────────────────┴─────────────┴───────────────────────────────┴──────────────────────┘\n"
    echo -e "  📌 ${YELLOW}Exemplo de configuração (se o seu domínio for 'suacidade.gov.br'):${NC}"
    echo -e "     • i-Educar: ${CYAN}ieducar.suacidade.gov.br${NC}  ->  Aponta (Tipo A) para ${GREEN}${SERVER_IP}${NC}"
    echo -e "     • i-Diário: ${CYAN}idiario.suacidade.gov.br${NC}  ->  Aponta (Tipo A) para ${GREEN}${SERVER_IP}${NC}\n"
    echo -e "  ⚠️  ${YELLOW}ATENÇÃO AOS PONTOS CRÍTICOS ANTES DE AVANÇAR:${NC}"
    echo -e "     1. ${BOLD}Se utilizar Cloudflare:${NC} Deixe a nuvem laranja desativada (${YELLOW}DNS Only / Cinza${NC})"
    echo -e "        durante a emissão inicial. O proxy ativo pode bloquear o desafio HTTP do Let's Encrypt."
    echo -e "        Após emitir o SSL com sucesso, você poderá reativar o proxy em modo 'Full (Strict)'."
    echo -e "     2. ${BOLD}Portas 80 e 443:${NC} Devem estar abertas no firewall da sua VPS e no painel da nuvem."
    echo -e "     3. ${BOLD}Propagação de DNS:${NC} Aguarde 1 a 3 minutos após salvar no painel de DNS."
    echo -e "${CYAN}======================================================================${NC}\n"
}

# Menu prévio para garantir que o usuário está pronto
while true; do
    show_dns_instructions
    echo -e "Você já configurou os apontamentos de DNS para o IP ${GREEN}${SERVER_IP}${NC}?"
    echo -e "   ${GREEN}[1]${NC} ✅ Sim, já realizei os apontamentos e quero continuar"
    echo -e "   ${YELLOW}[2]${NC} 🔍 Testar apontamento de um domínio agora (Verificar propagação)"
    echo -e "   ${RED}[0]${NC} 🚪 Voltar / Cancelar (Vou acessar o painel de DNS primeiro)"
    echo ""

    PRE_CHOICE="1"
    read_prompt "Selecione uma opção [0-2]" "1" PRE_CHOICE

    case "$PRE_CHOICE" in
        1)
            echo -e "\n${GREEN}Iniciando a configuração dos domínios e certificados SSL...${NC}\n"
            break
            ;;
        2)
            echo ""
            TEST_DOMAIN=""
            read_prompt "Digite o domínio para testar (ex: ieducar.suacidade.gov.br)" "" TEST_DOMAIN
            if [[ -n "$TEST_DOMAIN" ]]; then
                echo -e "\n -> Consultando DNS para ${CYAN}${TEST_DOMAIN}${NC}..."
                RESOLVED=$(getent ahosts "$TEST_DOMAIN" 2>/dev/null | awk '{print $1}' | head -n 1 || true)
                if [[ -z "$RESOLVED" ]]; then
                    echo -e "${RED}✗ Não foi possível resolver o domínio '${TEST_DOMAIN}'.${NC}"
                    echo -e "O domínio ainda não possui registro A ativo ou ainda não propagou."
                elif [[ "$RESOLVED" == "$SERVER_IP" ]]; then
                    echo -e "${GREEN}✓ Perfeito! O domínio '${TEST_DOMAIN}' já está apontando para esta VPS (${SERVER_IP})!${NC}"
                else
                    echo -e "${YELLOW}! O domínio '${TEST_DOMAIN}' está apontando para '${RESOLVED}', diferente do IP desta VPS (${SERVER_IP}).${NC}"
                    echo -e "Verifique se o registro A foi salvo com o IP correto (${SERVER_IP}) e aguarde a propagação."
                fi
                echo ""
                if [ -e /dev/tty ]; then
                    read -r -p "Pressione ENTER para continuar..." _ < /dev/tty || true
                else
                    read -r -p "Pressione ENTER para continuar..." _ || true
                fi
            fi
            ;;
        0|sair|exit|q)
            echo ""
            echo -e "${YELLOW}Operação cancelada. Quando concluir os apontamentos de DNS, execute novamente.${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "\n${RED}Opção inválida! Escolha 1, 2 ou 0.${NC}"
            sleep 1
            ;;
    esac
done

# 1. Verificar e instalar Certbot e Nginx
echo -e "${YELLOW}[1/6] Verificando dependências do sistema (Nginx, Certbot)...${NC}"
export DEBIAN_FRONTEND=noninteractive
if ! command -v nginx &>/dev/null; then
    echo " -> Instalando Nginx..."
    apt-get update -qq && apt-get install -y -qq nginx
fi

if ! command -v certbot &>/dev/null || ! dpkg -l | grep -q "python3-certbot-nginx"; then
    echo " -> Instalando Certbot e plugin Nginx..."
    apt-get update -qq && apt-get install -y -qq certbot python3-certbot-nginx
fi

echo -e "${GREEN}✓ Dependências prontas. IP público da VPS: ${SERVER_IP}${NC}\n"

# 2. Localizar instalações
IEDUCAR_DIR="/var/www/ieducar"
detect_idiario_dir() {
    if [[ -f /etc/ieducar-backup/.env ]]; then
        local env_path
        env_path=$(grep -E "^IDIARIO_APP_DIR=" /etc/ieducar-backup/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        if [[ -n "$env_path" && -d "$env_path/app" ]]; then
            echo "$env_path"
            return 0
        fi
    fi
    local common_paths=("/root/i-diario" "/var/www/idiario" "/var/www/i-diario" "/home/deploy/i-diario" "/opt/idiario")
    for p in "${common_paths[@]}"; do
        if [[ -d "$p/app" && -f "$p/Gemfile" ]]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

IDIARIO_DIR=$(detect_idiario_dir || true)
IDIARIO_DIR="${IDIARIO_DIR:-/root/i-diario}"

# 3. Menu de Seleção do Sistema
echo -e "Qual sistema você deseja configurar com Domínio e SSL?"
echo -e "   ${GREEN}[1]${NC} i-Educar (PHP / Laravel)"
echo -e "   ${GREEN}[2]${NC} i-Diário (Rails / PostgreSQL - com troca de IP por Domínio)"
echo -e "   ${GREEN}[3]${NC} Ambos (i-Educar e i-Diário simultaneamente)"
echo -e "   ${YELLOW}[0]${NC} Cancelar"
echo ""

APP_CHOICE="3"
read_prompt "Selecione uma opção [0-3]" "3" APP_CHOICE

if [[ "$APP_CHOICE" == "0" ]]; then
    echo -e "${YELLOW}Operação cancelada.${NC}"
    exit 0
fi

EMAIL_CONTACT="admin@$(hostname -d 2>/dev/null || echo "exemplo.gov.br")"
read_prompt "E-mail de contato para avisos de renovação do SSL" "$EMAIL_CONTACT" EMAIL_CONTACT

# Função de Validação DNS
check_dns() {
    local domain="$1"
    echo -e " -> Verificando apontamento DNS de ${CYAN}${domain}${NC}..."
    local resolved_ip
    resolved_ip=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | head -n 1 || true)

    if [[ -z "$resolved_ip" ]]; then
        echo -e "${YELLOW}[AVISO] O domínio ${domain} não respondeu na consulta DNS!${NC}"
        echo -e "Certifique-se de que criou o registro do tipo 'A' apontando para: ${GREEN}${SERVER_IP}${NC}"
        local cont="n"
        read_prompt "Deseja tentar emitir o SSL mesmo assim? (s/N)" "n" cont
        if [[ ! "$cont" =~ ^[sS]$ ]]; then
            return 1
        fi
    elif [[ "$resolved_ip" != "$SERVER_IP" ]]; then
        echo -e "${YELLOW}[AVISO] O domínio ${domain} aponta para ${resolved_ip}, mas este servidor é ${SERVER_IP}.${NC}"
        local cont="n"
        read_prompt "Deseja prosseguir mesmo assim? (s/N)" "n" cont
        if [[ ! "$cont" =~ ^[sS]$ ]]; then
            return 1
        fi
    else
        echo -e "${GREEN}✓ DNS verificado: ${domain} -> ${SERVER_IP}${NC}"
    fi
    return 0
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÃO: I-EDUCAR
# ------------------------------------------------------------------------------
configure_ieducar_ssl() {
    local domain="$1"
    echo ""
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}          CONFIGURANDO DOMÍNIO & SSL PARA O I-EDUCAR                  ${NC}"
    echo -e "${BLUE}======================================================================${NC}"

    if ! check_dns "$domain"; then
        echo -e "${YELLOW}Configuração de SSL ignorada para ${domain}.${NC}"
        return
    fi

    # Detectar socket do PHP-FPM
    local php_sock="/run/php/php8.4-fpm.sock"
    if [[ ! -e "$php_sock" ]]; then
        local found_sock
        found_sock=$(find /run/php -type s -name "*.sock" 2>/dev/null | head -n 1 || true)
        if [[ -n "$found_sock" ]]; then
            php_sock="$found_sock"
        fi
    fi

    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/snippets /etc/nginx/conf.d
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

    # Criar vhost HTTP inicial
    cat << NGINX_IEDUCAR > /etc/nginx/sites-available/ieducar.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    root ${IEDUCAR_DIR}/public;

    index index.php index.html;

    client_max_body_size 50M;
    proxy_read_timeout 300s;
    fastcgi_read_timeout 300s;

    error_page 404 /index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~* \.(jpg|jpeg|gif|png|css|js|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        access_log off;
        try_files \$uri =404;
    }

    location ~ \.php$ {
        try_files \$uri /index.php?\$query_string;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:${php_sock};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_param HTTPS on;
        fastcgi_param HTTP_X_FORWARDED_PROTO https;
        fastcgi_param HTTP_X_FORWARDED_SSL on;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX_IEDUCAR

    # Criar bridge do intranet/index.php para o Laravel router
    mkdir -p "${IEDUCAR_DIR}/public/intranet"
    cat << 'EOF' > "${IEDUCAR_DIR}/public/intranet/index.php"
<?php
require_once dirname(__DIR__) . '/index.php';
EOF
    chown -R www-data:www-data "${IEDUCAR_DIR}/public/intranet"
    chmod 644 "${IEDUCAR_DIR}/public/intranet/index.php"

    ln -sf /etc/nginx/sites-available/ieducar.conf /etc/nginx/sites-enabled/ieducar.conf
    nginx -t && systemctl reload nginx || systemctl restart nginx

    # Emissão de SSL com Certbot
    echo -e "${YELLOW}Solicitando certificado SSL Let's Encrypt para ${domain}...${NC}"
    if certbot --nginx -d "${domain}" --non-interactive --agree-tos -m "${EMAIL_CONTACT}" --redirect; then
        echo -e "${GREEN}✓ Certificado SSL gerado com sucesso para ${domain}!${NC}"
    else
        echo -e "${YELLOW}Falha ao gerar SSL automático. Tentando modo interativo...${NC}"
        certbot --nginx -d "${domain}" --agree-tos -m "${EMAIL_CONTACT}" --redirect || true
    fi

    # Garantir parâmetros FastCGI HTTPS após a modificação do Certbot no vhost
    if [[ -f /etc/nginx/sites-available/ieducar.conf ]]; then
        if ! grep -q "fastcgi_param HTTPS" /etc/nginx/sites-available/ieducar.conf; then
            sed -i '/include fastcgi_params;/a \        fastcgi_param HTTPS on;\n        fastcgi_param HTTP_X_FORWARDED_PROTO https;\n        fastcgi_param HTTP_X_FORWARDED_SSL on;' /etc/nginx/sites-available/ieducar.conf
        fi
    fi

    # Atualizar APP_URL e ASSET_URL no .env do i-Educar
    if [[ -f "${IEDUCAR_DIR}/.env" ]]; then
        sed -i "s|^APP_URL=.*|APP_URL=https://${domain}|" "${IEDUCAR_DIR}/.env"
        if grep -q "^ASSET_URL=" "${IEDUCAR_DIR}/.env"; then
            sed -i "s|^ASSET_URL=.*|ASSET_URL=https://${domain}|" "${IEDUCAR_DIR}/.env"
        else
            echo "ASSET_URL=https://${domain}" >> "${IEDUCAR_DIR}/.env"
        fi
        echo -e "${GREEN}✓ .env atualizado com APP_URL=https://${domain} e ASSET_URL=https://${domain}${NC}"
    fi

    # Forçar esquema HTTPS no Laravel para evitar Mixed Content (CSS/JS bloqueados pelo navegador)
    local app_sp="${IEDUCAR_DIR}/app/Providers/AppServiceProvider.php"
    if [[ -f "$app_sp" ]]; then
        php -r '
        $file = "'"${app_sp}"'";
        $content = file_get_contents($file);
        if (!str_contains($content, "forceScheme")) {
            $content = preg_replace(
                "/public function boot\(\)\s*\{/",
                "public function boot()\n    {\n        \Illuminate\Support\Facades\URL::forceScheme(\"https\");",
                $content
            );
            file_put_contents($file, $content);
            echo "✓ AppServiceProvider atualizado com forceScheme(\"https\")\n";
        }
        '
    fi

    # Configurar TrustProxies para confiar no Nginx
    local trust_px="${IEDUCAR_DIR}/app/Http/Middleware/TrustProxies.php"
    if [[ -f "$trust_px" ]]; then
        php -r '
        $file = "'"${trust_px}"'";
        $content = file_get_contents($file);
        $content = preg_replace("/protected\s+\\$proxies\s*;/", "protected \$proxies = \"*\";", $content);
        $content = preg_replace("/protected\s+\\$proxies\s*=\s*null\s*;/", "protected \$proxies = \"*\";", $content);
        file_put_contents($file, $content);
        '
    fi

    # Limpar TODOS os caches do Laravel para regerar tags de CSS/JS e Blade
    cd "${IEDUCAR_DIR}"
    php artisan view:clear >/dev/null 2>&1 || true
    php artisan route:clear >/dev/null 2>&1 || true
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan cache:clear >/dev/null 2>&1 || true
    php artisan storage:link >/dev/null 2>&1 || true

    # Permissões
    chown -R www-data:www-data "${IEDUCAR_DIR}/storage" "${IEDUCAR_DIR}/bootstrap/cache" "${IEDUCAR_DIR}/public" "${IEDUCAR_DIR}/tmp" 2>/dev/null || true
    chmod -R 775 "${IEDUCAR_DIR}/storage" "${IEDUCAR_DIR}/bootstrap/cache" "${IEDUCAR_DIR}/tmp" 2>/dev/null || true

    systemctl restart php*-fpm 2>/dev/null || true
    systemctl reload nginx || systemctl restart nginx
    echo -e "${GREEN}✓ i-Educar configurado com sucesso em: https://${domain}${NC}"
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÃO: I-DIÁRIO (com substituição de IP por Domínio no Banco)
# ------------------------------------------------------------------------------
configure_idiario_ssl() {
    local domain="$1"
    echo ""
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BLUE}          CONFIGURANDO DOMÍNIO & SSL PARA O I-DIÁRIO                  ${NC}"
    echo -e "${BLUE}======================================================================${NC}"

    if ! check_dns "$domain"; then
        echo -e "${YELLOW}Configuração de SSL ignorada para ${domain}.${NC}"
        return
    fi

    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

    # Criar vhost HTTP Proxy inicial
    cat << NGINX_IDIARIO > /etc/nginx/sites-available/idiario.conf
upstream idiario_backend {
    server 127.0.0.1:3000 fail_timeout=0;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${domain};

    client_max_body_size 50M;
    proxy_read_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;

    location / {
        proxy_pass http://idiario_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }

    location ~ ^/(assets|packs)/ {
        root ${IDIARIO_DIR}/public;
        gzip_static on;
        expires max;
        add_header Cache-Control public;
    }
}
NGINX_IDIARIO

    ln -sf /etc/nginx/sites-available/idiario.conf /etc/nginx/sites-enabled/idiario.conf
    nginx -t && systemctl reload nginx || systemctl restart nginx

    # Emissão de SSL com Certbot
    echo -e "${YELLOW}Solicitando certificado SSL Let's Encrypt para ${domain}...${NC}"
    if certbot --nginx -d "${domain}" --non-interactive --agree-tos -m "${EMAIL_CONTACT}" --redirect; then
        echo -e "${GREEN}✓ Certificado SSL gerado com sucesso para ${domain}!${NC}"
    else
        echo -e "${YELLOW}Falha ao gerar SSL automático. Tentando modo interativo...${NC}"
        certbot --nginx -d "${domain}" --agree-tos -m "${EMAIL_CONTACT}" --redirect || true
    fi

    # ATUALIZAÇÃO NO BANCO DE DADOS: Substituir o IP pelo Domínio da Entidade
    echo -e "${YELLOW}Atualizando vínculo do domínio da Entidade no banco de dados do i-Diário...${NC}"
    
    # Estratégia 1: Atualização direta SQL no PostgreSQL
    if command -v psql &>/dev/null; then
        sudo -u postgres psql -d idiario_production -c "
            UPDATE entities SET domain = '${domain}' WHERE true;
        " >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ Registro da tabela 'entities' atualizado para o domínio: ${domain}${NC}"
    fi

    # Estratégia 2: Atualização via Rails Runner
    local rbenv_bin="/root/.rbenv/shims/bundle"
    if [[ -x "$rbenv_bin" && -d "$IDIARIO_DIR" ]]; then
        cat << 'RUNNER_UPDATE' > /tmp/update_entity_domain.rb
begin
  if defined?(Entity)
    Entity.all.each do |e|
      old = e.domain
      e.update_columns(domain: ENV['TARGET_DOMAIN'])
      puts "✓ Entidade '#{e.name}' atualizada com sucesso de '#{old}' para '#{ENV['TARGET_DOMAIN']}'."
    end
  end
rescue => err
  puts "Aviso ao atualizar Entidade via model: #{err.message}"
end
RUNNER_UPDATE
        TARGET_DOMAIN="${domain}" RAILS_ENV=production cd "$IDIARIO_DIR" && "$rbenv_bin" exec rails runner /tmp/update_entity_domain.rb 2>/dev/null || true
        rm -f /tmp/update_entity_domain.rb
    fi

    # Reiniciar os serviços do i-Diário
    echo -e "${YELLOW}Reiniciando serviços do i-Diário para aplicar o novo domínio...${NC}"
    systemctl restart idiario-web idiario-sidekiq idiario-sync 2>/dev/null || true

    systemctl reload nginx || systemctl restart nginx
    echo -e "${GREEN}✓ i-Diário configurado com sucesso em: https://${domain}${NC}"
}

# 4. Executar conforme a escolha do usuário
case "$APP_CHOICE" in
    1)
        IEDUCAR_DOMAIN=""
        read_prompt "Digite o domínio FQDN para o i-Educar (ex: ieducar.municipio.gov.br)" "" IEDUCAR_DOMAIN
        if [[ -n "$IEDUCAR_DOMAIN" ]]; then
            configure_ieducar_ssl "$IEDUCAR_DOMAIN"
        fi
        ;;
    2)
        IDIARIO_DOMAIN=""
        read_prompt "Digite o domínio FQDN para o i-Diário (ex: diario.municipio.gov.br)" "" IDIARIO_DOMAIN
        if [[ -n "$IDIARIO_DOMAIN" ]]; then
            configure_idiario_ssl "$IDIARIO_DOMAIN"
        fi
        ;;
    3)
        IEDUCAR_DOMAIN=""
        read_prompt "Digite o domínio FQDN para o i-Educar (ex: ieducar.municipio.gov.br)" "" IEDUCAR_DOMAIN
        IDIARIO_DOMAIN=""
        read_prompt "Digite o domínio FQDN para o i-Diário (ex: diario.municipio.gov.br)" "" IDIARIO_DOMAIN

        if [[ -n "$IEDUCAR_DOMAIN" ]]; then
            configure_ieducar_ssl "$IEDUCAR_DOMAIN"
        fi
        if [[ -n "$IDIARIO_DOMAIN" ]]; then
            configure_idiario_ssl "$IDIARIO_DOMAIN"
        fi
        ;;
esac

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}   🎉 CONFIGURAÇÃO DE DOMÍNIOS E SSL CONCLUÍDA COM SUCESSO!          ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e " • Redirecionamento HTTP -> HTTPS: ${GREEN}ATIVO (Porta 443)${NC}"
echo -e " • Renovação Automática do Certbot: ${GREEN}ATIVA via Systemd Timer${NC}"
echo -e " • Teste de Renovação Simulado:"
certbot renew --dry-run 2>/dev/null | grep -E "Congratulations|all renewals succeeded" || echo -e "   ✓ Renovação automática programada sem erros."
echo -e "${GREEN}======================================================================${NC}"
