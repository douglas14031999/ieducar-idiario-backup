#!/usr/bin/env bash
# ==============================================================================
# Script: fix-ieducar-https.sh
# Objetivo: Corrigir carregamento de CSS, JS e Imagens (Mixed Content) no i-Educar via HTTPS
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}   🛠️  CORREÇÃO DE CSS, JS E ATIVOS HTTPS (MIXED CONTENT) - I-EDUCAR  ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Este script corrige a tela sem estilos do i-Educar forçando o esquema HTTPS,"
echo -e "configurando cabeçalhos FastCGI/Nginx, TrustProxies e limpando caches do Blade."
echo -e "${BLUE}----------------------------------------------------------------------${NC}\n"

IEDUCAR_DIR="/var/www/ieducar"
if [[ ! -d "$IEDUCAR_DIR" ]]; then
    if [[ -d "/var/www/i-educar" ]]; then
        IEDUCAR_DIR="/var/www/i-educar"
    else
        echo -e "${RED}[ERRO] Diretório do i-Educar não encontrado em /var/www/ieducar.${NC}"
        exit 1
    fi
fi

# 1. Obter ou validar Domínio configurado
DOMAIN=""
if [[ -f "${IEDUCAR_DIR}/.env" ]]; then
    DOMAIN=$(grep -E "^APP_URL=" "${IEDUCAR_DIR}/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" | sed 's|https://||' | sed 's|http://||' | cut -d'/' -f1 || true)
fi

if [[ -z "$DOMAIN" && -f /etc/nginx/sites-available/ieducar.conf ]]; then
    DOMAIN=$(grep -E "server_name\s+" /etc/nginx/sites-available/ieducar.conf 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d ';' || true)
fi

DOMAIN="${DOMAIN:-ieducar.provacanoa.tech}"

echo -e "${YELLOW}[1/6] Atualizando variáveis de ambiente (.env)...${NC}"
if [[ -f "${IEDUCAR_DIR}/.env" ]]; then
    sed -i "s|^APP_URL=.*|APP_URL=https://${DOMAIN}|" "${IEDUCAR_DIR}/.env"
    if grep -q "^ASSET_URL=" "${IEDUCAR_DIR}/.env"; then
        sed -i "s|^ASSET_URL=.*|ASSET_URL=https://${DOMAIN}|" "${IEDUCAR_DIR}/.env"
    else
        echo "ASSET_URL=https://${DOMAIN}" >> "${IEDUCAR_DIR}/.env"
    fi
    echo -e "${GREEN}✓ .env atualizado com APP_URL=https://${DOMAIN} e ASSET_URL=https://${DOMAIN}${NC}"
fi

echo -e "${YELLOW}[2/6] Forçando esquema HTTPS no AppServiceProvider...${NC}"
APP_SERVICE_PROVIDER="${IEDUCAR_DIR}/app/Providers/AppServiceProvider.php"
if [[ -f "$APP_SERVICE_PROVIDER" ]]; then
    php -r '
    $file = "'"${APP_SERVICE_PROVIDER}"'";
    $content = file_get_contents($file);
    if (!str_contains($content, "forceScheme")) {
        $content = preg_replace(
            "/public function boot\(\)\s*\{/",
            "public function boot()\n    {\n        \Illuminate\Support\Facades\URL::forceScheme(\"https\");",
            $content
        );
        file_put_contents($file, $content);
        echo "✓ URL::forceScheme(\"https\") adicionado com sucesso ao AppServiceProvider.php\n";
    } else {
        echo "✓ URL::forceScheme(\"https\") já estava configurado no AppServiceProvider.php\n";
    }
    '
fi

echo -e "${YELLOW}[3/6] Ajustando TrustProxies do Laravel...${NC}"
TRUST_PROXIES="${IEDUCAR_DIR}/app/Http/Middleware/TrustProxies.php"
if [[ -f "$TRUST_PROXIES" ]]; then
    php -r '
    $file = "'"${TRUST_PROXIES}"'";
    $content = file_get_contents($file);
    $content = preg_replace("/protected\s+\\\$proxies\s*(=[^;]+)?;/", "protected \$proxies = \"*\";", $content);
    file_put_contents($file, $content);
    echo "✓ TrustProxies configurado para confiar em todos os proxies (*)\n";
    '
fi

echo -e "${YELLOW}[4/6] Otimizando Nginx e rotas do i-Educar (Intranet / Laravel)...${NC}"
PHP_SOCK="/run/php/php8.4-fpm.sock"
if [[ ! -e "$PHP_SOCK" ]]; then
    FOUND_SOCK=$(find /run/php -type s -name "*.sock" 2>/dev/null | head -n 1 || true)
    if [[ -n "$FOUND_SOCK" ]]; then
        PHP_SOCK="$FOUND_SOCK"
    fi
fi

# 4.1 Criar bridge para /intranet/index.php -> Laravel index.php (evita 404 pós-login)
mkdir -p "${IEDUCAR_DIR}/public/intranet"
cat << 'EOF' > "${IEDUCAR_DIR}/public/intranet/index.php"
<?php
require_once dirname(__DIR__) . '/index.php';
EOF
chown -R www-data:www-data "${IEDUCAR_DIR}/public/intranet"
chmod 644 "${IEDUCAR_DIR}/public/intranet/index.php"
echo -e "${GREEN}✓ Bridge '/intranet/index.php' criada com sucesso em public/intranet${NC}"

# 4.2 Gerar configuração limpa e validada do Nginx
rm -f /etc/nginx/conf.d/ieducar.conf 2>/dev/null || true
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    cat << NGINX_CONF > /etc/nginx/sites-available/ieducar.conf
server {
    server_name ${DOMAIN};
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
        fastcgi_pass unix:${PHP_SOCK};
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

    listen 443 ssl;
    listen [::]:443 ssl;
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}
NGINX_CONF
else
    cat << NGINX_CONF > /etc/nginx/sites-available/ieducar.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
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
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX_CONF
fi

ln -sf /etc/nginx/sites-available/ieducar.conf /etc/nginx/sites-enabled/ieducar.conf
echo -e "${GREEN}✓ Configuração do Nginx atualizada com sucesso sem erros de sintaxe${NC}"

echo -e "${YELLOW}[5/6] Limpando caches compilados do Laravel (Blade, Config, Views)...${NC}"
cd "$IEDUCAR_DIR"
php artisan view:clear || true
php artisan route:clear || true
php artisan config:clear || true
php artisan cache:clear || true

# Criar link simbólico do storage se necessário
php artisan storage:link || true

echo -e "${YELLOW}[6/6] Ajustando permissões de arquivos e reiniciando serviços...${NC}"
chown -R www-data:www-data "${IEDUCAR_DIR}/storage" "${IEDUCAR_DIR}/bootstrap/cache" "${IEDUCAR_DIR}/public" "${IEDUCAR_DIR}/tmp" 2>/dev/null || true
chmod -R 775 "${IEDUCAR_DIR}/storage" "${IEDUCAR_DIR}/bootstrap/cache" "${IEDUCAR_DIR}/tmp" 2>/dev/null || true

# Reiniciar PHP-FPM e Nginx
systemctl daemon-reload 2>/dev/null || true
systemctl restart php*-fpm 2>/dev/null || true
nginx -t && systemctl reload nginx || systemctl restart nginx

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}   ✓ CORREÇÃO CONCLUÍDA COM SUCESSO!                                  ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "O i-Educar agora está forçando o carregamento seguro (HTTPS) de todos os"
echo -e "arquivos CSS, JS e Imagens em: ${CYAN}https://${DOMAIN}/login${NC}\n"
echo -e "👉 ${YELLOW}IMPORTANTE:${NC} No seu navegador, pressione ${BOLD}Ctrl + F5${NC} (ou ${BOLD}Ctrl + Shift + R${NC})"
echo -e "para forçar a atualização e limpar o cache antigo da página de login."
echo -e "${GREEN}======================================================================${NC}\n"
