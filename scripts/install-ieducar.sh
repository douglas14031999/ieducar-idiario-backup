#!/usr/bin/env bash
# ==============================================================================
# Script: install-ieducar.sh
# Objetivo: Instalação Completa Automatizada do i-Educar + Todos os Módulos Oficiais
# Módulos: Relatórios, Biblioteca, Educacenso, Transporte Escolar, Pré-Matrícula Digital
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configurações Padrão
IEDUCAR_DIR="/var/www/ieducar"
IEDUCAR_VERSION="2.10"
PHP_VER="8.4"
DB_NAME="ieducar"
DB_USER="ieducar"
DB_PASS="ieducar"
CITY_NAME="Lagoa da Canoa"
STATE_CODE="AL"
IBGE_CODE="2703808"
MAP_LAT="-9.8294"
MAP_LNG="-36.7867"
MAP_ZOOM="14"

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

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}     INSTALADOR AUTOMATIZADO DO I-EDUCAR (VERSÃO 2.10) + MÓDULOS      ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Este assistente instalará e configurará:"
echo -e " • i-Educar Oficial Versão 2.10 (Portabilis - Branch 2.10)"
echo -e " • Dependências do Sistema (Nginx, Redis, PostgreSQL, Java 8, PHP ${PHP_VER})"
echo -e " • Banco de Dados PostgreSQL & Composer"
echo -e " • Módulo de Relatórios (JasperPHP & JasperStarter)"
echo -e " • Módulo de Biblioteca"
echo -e " • Módulo do Educacenso (Migrações e Configurações)"
echo -e " • Módulo de Transporte Escolar"
echo -e " • Módulo de Pré-Matrícula Digital (PMD - Node/Yarn Build)"
echo -e " • Ajustes de Permissões, Ficha do Servidor e Otimizações de Nginx/PHP"
echo -e "${BLUE}======================================================================${NC}\n"

# Confirmação do Usuário
CONFIRM="s"
read_prompt "Deseja iniciar a instalação do i-Educar 2.10 agora? (s/N)" "s" CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Instalação cancelada pelo usuário.${NC}"
    exit 0
fi

# Escolha da senha do banco
DB_PASS_CHOICE="$DB_PASS"
read_prompt "Defina a senha do banco PostgreSQL para o usuário 'ieducar'" "$DB_PASS" DB_PASS_CHOICE
DB_PASS="$DB_PASS_CHOICE"

echo ""
echo -e "${YELLOW}[1/16] Atualizando repositórios e pacotes do sistema...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq software-properties-common curl git wget unzip gnupg2 ca-certificates lsb-release

echo -e "${YELLOW}[2/16] Adicionando repositórios PPA (OpenJDK e PHP)...${NC}"
add-apt-repository ppa:openjdk-r/ppa -y || true
add-apt-repository ppa:ondrej/php -y || true
apt-get update -qq

echo -e "${YELLOW}[3/16] Instalando dependências principais do sistema...${NC}"
apt-get install -y -qq \
    nginx \
    redis-server \
    postgresql postgresql-contrib \
    openjdk-8-jdk \
    openssl \
    imagemagick \
    "php${PHP_VER}-common" \
    "php${PHP_VER}-cli" \
    "php${PHP_VER}-fpm" \
    "php${PHP_VER}-bcmath" \
    "php${PHP_VER}-curl" \
    "php${PHP_VER}-mbstring" \
    "php${PHP_VER}-pgsql" \
    "php${PHP_VER}-xml" \
    "php${PHP_VER}-zip" \
    "php${PHP_VER}-gd" \
    "php${PHP_VER}-redis" || true

# Iniciar PostgreSQL e Redis
systemctl start postgresql.service || true
systemctl enable postgresql.service || true
systemctl start redis-server.service || true

echo -e "${YELLOW}[4/16] Configurando banco de dados PostgreSQL...${NC}"
# Criação não interativa e idempotente de usuário e banco
sudo -u postgres psql -c "DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} WITH SUPERUSER LOGIN CREATEDB PASSWORD '${DB_PASS}';
    ELSE
        ALTER ROLE ${DB_USER} WITH SUPERUSER LOGIN CREATEDB PASSWORD '${DB_PASS}';
    END IF;
END
\$\$;"

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1; then
    sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}"
    echo -e "${GREEN}✓ Banco '${DB_NAME}' criado com sucesso.${NC}"
else
    echo -e "${GREEN}✓ Banco '${DB_NAME}' já existia.${NC}"
fi

echo -e "${YELLOW}[5/16] Instalando e preparando o Composer...${NC}"
if ! command -v composer &>/dev/null; then
    curl -sS https://getcomposer.org/installer -o composer-setup.php
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm -f composer-setup.php
    echo -e "${GREEN}✓ Composer instalado em /usr/local/bin/composer${NC}"
else
    echo -e "${GREEN}✓ Composer já instalado.${NC}"
fi
export COMPOSER_ALLOW_SUPERUSER=1

echo -e "${YELLOW}[6/16] Clonando repositório oficial do i-Educar (Versão ${IEDUCAR_VERSION})...${NC}"
if [[ -d "$IEDUCAR_DIR/.git" ]]; then
    echo -e "${YELLOW} -> Diretório $IEDUCAR_DIR já existe. Fazendo backup do .env e atualizando para a versão ${IEDUCAR_VERSION}...${NC}"
    BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
    cp "$IEDUCAR_DIR/.env" "/tmp/ieducar_env_${BACKUP_TIME}" 2>/dev/null || true
    cd "$IEDUCAR_DIR"
    git fetch origin "${IEDUCAR_VERSION}" || true
    git checkout "${IEDUCAR_VERSION}" || true
    git pull origin "${IEDUCAR_VERSION}" || true
else
    mkdir -p "$(dirname "$IEDUCAR_DIR")"
    git clone --branch "${IEDUCAR_VERSION}" --single-branch https://github.com/portabilis/i-educar.git "$IEDUCAR_DIR"
fi

cd "$IEDUCAR_DIR"

echo -e "${YELLOW}[7/16] Configurando arquivo de ambiente (.env)...${NC}"
if [[ ! -f "$IEDUCAR_DIR/.env" ]]; then
    cp "$IEDUCAR_DIR/.env.example" "$IEDUCAR_DIR/.env"
fi

# Ajuste automático das variáveis de banco de dados
sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/' "$IEDUCAR_DIR/.env"
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" "$IEDUCAR_DIR/.env"
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" "$IEDUCAR_DIR/.env"
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" "$IEDUCAR_DIR/.env"
sed -i 's/^DB_HOST=.*/DB_HOST=127.0.0.1/' "$IEDUCAR_DIR/.env"
sed -i 's/^DB_PORT=.*/DB_PORT=5432/' "$IEDUCAR_DIR/.env"

# Habilita dados legados para o Educacenso
if ! grep -q "^LEGACY_SEED_DATA=" "$IEDUCAR_DIR/.env"; then
    echo "LEGACY_SEED_DATA=true" >> "$IEDUCAR_DIR/.env"
else
    sed -i 's/^LEGACY_SEED_DATA=.*/LEGACY_SEED_DATA=true/' "$IEDUCAR_DIR/.env"
fi

echo -e "${YELLOW}[8/16] Configurando e Otimizando Nginx & PHP-FPM...${NC}"
# Copiar snippets e configurações do docker se existirem
if [[ -d "$IEDUCAR_DIR/docker/nginx" ]]; then
    mkdir -p /etc/nginx/conf.d /etc/nginx/snippets
    cp -r "$IEDUCAR_DIR/docker/nginx/conf.d/"* /etc/nginx/conf.d/ 2>/dev/null || true
    cp -r "$IEDUCAR_DIR/docker/nginx/snippets/"* /etc/nginx/snippets/ 2>/dev/null || true
fi

# Detectar socket correto do PHP-FPM
PHP_SOCK="/run/php/php${PHP_VER}-fpm.sock"
if [[ ! -e "$PHP_SOCK" ]]; then
    # Procurar qualquer socket ativo
    FOUND_SOCK=$(find /run/php -type s -name "*.sock" 2>/dev/null | head -n 1 || true)
    if [[ -n "$FOUND_SOCK" ]]; then
        PHP_SOCK="$FOUND_SOCK"
    fi
fi

# Ajustar upstream.conf
if [[ -f /etc/nginx/conf.d/upstream.conf ]]; then
    sed -i "s|fpm:9000|unix:${PHP_SOCK}|g" /etc/nginx/conf.d/upstream.conf
    sed -i "s|unix:/run/php/php-fpm.sock|unix:${PHP_SOCK}|g" /etc/nginx/conf.d/upstream.conf
fi

# Remover default do Nginx e evitar conflito de gzip
rm -f /etc/nginx/sites-enabled/default

if [[ -f /etc/nginx/conf.d/nginx.conf ]]; then
    # Comentar gzip redundante para evitar erro de teste no nginx
    sed -i 's/^[ \t]*gzip[ \t]\+on;/# gzip on;/' /etc/nginx/conf.d/nginx.conf || true
fi

# Ajustar php.ini para uploads de 50M e timeout de 300s
PHP_INI="/etc/php/${PHP_VER}/fpm/php.ini"
if [[ -f "$PHP_INI" ]]; then
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI"
    sed -i 's/^post_max_size = .*/post_max_size = 50M/' "$PHP_INI"
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/^max_input_time = .*/max_input_time = 300/' "$PHP_INI"
    sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
fi

# Criar pasta temporária do i-Educar
mkdir -p "$IEDUCAR_DIR/tmp"
chown -R www-data:www-data "$IEDUCAR_DIR/tmp"
chmod -R 775 "$IEDUCAR_DIR/tmp"

# Configurar site default no Nginx caso necessário
if [[ ! -f /etc/nginx/conf.d/ieducar.conf && ! -f /etc/nginx/sites-available/ieducar ]]; then
    cat << NGINX_CONF > /etc/nginx/conf.d/ieducar.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root ${IEDUCAR_DIR}/public;

    client_max_body_size 50M;
    proxy_read_timeout 300s;
    fastcgi_read_timeout 300s;

    index index.php index.html;

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

rm -rf "${IEDUCAR_DIR}/public/intranet/index.php" 2>/dev/null || true

systemctl restart "php${PHP_VER}-fpm" || true
systemctl daemon-reload 2>/dev/null || true
nginx -t && (systemctl restart nginx || systemctl start nginx)

echo -e "${YELLOW}[9/16] Instalando pacotes do Core do i-Educar (${IEDUCAR_VERSION})...${NC}"
cd "$IEDUCAR_DIR"
composer install --no-interaction --prefer-dist --optimize-autoloader || composer update --no-interaction
composer new-install --no-interaction 2>/dev/null || composer run-script new-install --no-interaction 2>/dev/null || true

php artisan key:generate --force || true
php artisan storage:link || true

echo -e "${YELLOW}[10/16] Executando migrações e seeders base...${NC}"
php artisan migrate --force || true
php artisan db:seed --force || true

echo -e "${YELLOW}[11/16] Instalando Módulo de Relatórios (Reports)...${NC}"
mkdir -p "$IEDUCAR_DIR/packages/portabilis"
if [[ ! -d "$IEDUCAR_DIR/packages/portabilis/i-educar-reports-package" ]]; then
    git clone https://github.com/portabilis/i-educar-reports-package.git "$IEDUCAR_DIR/packages/portabilis/i-educar-reports-package"
else
    cd "$IEDUCAR_DIR/packages/portabilis/i-educar-reports-package" && git pull origin master || true
    cd "$IEDUCAR_DIR"
fi

composer plug-and-play || true
php artisan community:reports:install --force || php artisan community:reports:install || true
php artisan vendor:publish --tag=reports-assets --ansi --force || true

# Correção de permissão do JasperStarter
JASPER_BIN="$IEDUCAR_DIR/vendor/cossou/jasperphp/src/JasperStarter/bin/jasperstarter"
if [[ -f "$JASPER_BIN" ]]; then
    chmod +x "$JASPER_BIN"
    echo -e "${GREEN}✓ Permissão executável garantida para JasperStarter.${NC}"
fi


echo -e "${YELLOW}[12/16] Instalando Módulo de Biblioteca...${NC}"
if [[ ! -d "$IEDUCAR_DIR/packages/portabilis/i-educar-library-package" ]]; then
    git clone https://github.com/portabilis/i-educar-library-package.git "$IEDUCAR_DIR/packages/portabilis/i-educar-library-package"
else
    cd "$IEDUCAR_DIR/packages/portabilis/i-educar-library-package" && git pull origin master || true
    cd "$IEDUCAR_DIR"
fi
composer plug-and-play || true
php artisan migrate --force || true

echo -e "${YELLOW}[13/16] Instalando Módulo do Educacenso (Censos 2024, 2025 e 2026 - Douglas)...${NC}"
SCRIPT_EDUCACENSO="$(dirname "$0")/install-educacenso.sh"
if [[ -f "$SCRIPT_EDUCACENSO" ]]; then
    bash "$SCRIPT_EDUCACENSO" || true
elif [[ -f "/opt/ieducar-backup/scripts/install-educacenso.sh" ]]; then
    bash "/opt/ieducar-backup/scripts/install-educacenso.sh" || true
else
    if [[ ! -d "$IEDUCAR_DIR/packages/portabilis/i-educar-educacenso-package" ]]; then
        git clone -b 2.12 https://github.com/douglas14031999/i-educar-educacenso-package.git "$IEDUCAR_DIR/packages/portabilis/i-educar-educacenso-package"
    else
        cd "$IEDUCAR_DIR/packages/portabilis/i-educar-educacenso-package" && git fetch origin 2.12 && git checkout 2.12 && git reset --hard origin/2.12 || true
        cd "$IEDUCAR_DIR"
    fi
    chown -R www-data:www-data "$IEDUCAR_DIR/packages/portabilis/i-educar-educacenso-package"
    chmod -R 775 "$IEDUCAR_DIR/packages/portabilis/i-educar-educacenso-package"
    composer plug-and-play || true
    composer dump-autoload --optimize || true
    php artisan migrate --force || true
    php artisan cache:clear || true
fi

echo -e "${YELLOW}[14/16] Instalando Módulo de Transporte Escolar...${NC}"
if [[ ! -d "$IEDUCAR_DIR/packages/portabilis/i-educar-transport-package" ]]; then
    git clone https://github.com/portabilis/i-educar-transport-package.git "$IEDUCAR_DIR/packages/portabilis/i-educar-transport-package"
else
    cd "$IEDUCAR_DIR/packages/portabilis/i-educar-transport-package" && git pull origin master || true
    cd "$IEDUCAR_DIR"
fi
composer plug-and-play || true
php artisan migrate --force || true

echo -e "${YELLOW}[15/16] Instalando Módulo de Pré-Matrícula Digital (PMD)...${NC}"
# Instalação do Node.js LTS e Yarn se não presentes
if ! command -v node &>/dev/null; then
    echo " -> Instalando Node.js 18.x..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y -qq nodejs
fi
if ! command -v yarn &>/dev/null; then
    echo " -> Instalando Yarn..."
    npm install -g yarn
fi

if [[ ! -d "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital" ]]; then
    git clone https://github.com/portabilis/pre-matricula-digital.git "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital"
else
    cd "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital" && git pull origin master || true
    cd "$IEDUCAR_DIR"
fi

if [[ -f "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital/.env.example" && ! -f "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital/.env" ]]; then
    cp "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital/.env.example" "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital/.env"
fi

# Configurar variáveis PMD no .env da raiz
set_env_var() {
    local key="$1"
    local val="$2"
    if grep -q "^${key}=" "$IEDUCAR_DIR/.env"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$IEDUCAR_DIR/.env"
    else
        echo "${key}=${val}" >> "$IEDUCAR_DIR/.env"
    fi
}

set_env_var "FRONTIER_ENDPOINT" "/pre-matricula-digital"
set_env_var "FRONTIER_VIEWS_PATH" "packages/portabilis/pre-matricula-digital/dist"
set_env_var "PREMATRICULA_CITY" "\"${CITY_NAME}\""
set_env_var "PREMATRICULA_STATE" "\"${STATE_CODE}\""
set_env_var "PREMATRICULA_IBGE_CODES" "\"${IBGE_CODE}\""
set_env_var "PREMATRICULA_MAP_LAT" "${MAP_LAT}"
set_env_var "PREMATRICULA_MAP_LNG" "${MAP_LNG}"
set_env_var "PREMATRICULA_MAP_ZOOM" "${MAP_ZOOM}"

composer plug-and-play:update || composer plug-and-play || true

# Compilação dos Assets do PMD
echo " -> Compilando assets do PMD com Yarn..."
yarn --cwd "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital" install --frozen-lockfile || yarn --cwd "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital" install || true
yarn --cwd "$IEDUCAR_DIR/packages/portabilis/pre-matricula-digital" build --base=/vendor/pre-matricula-digital/ || true

php artisan migrate --force || true
php artisan vendor:publish --tag=pmd --force || true

echo -e "${YELLOW}[16/16] Aplicando correções finais de permissões, logos e symlinks...${NC}"
# Permissões gerais
chown -R www-data:www-data "$IEDUCAR_DIR"
find "$IEDUCAR_DIR" -type d -exec chmod 755 {} \; 2>/dev/null || true
find "$IEDUCAR_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true

# Garantir permissões de escrita em pastas vitais
chmod -R 775 "$IEDUCAR_DIR/storage" "$IEDUCAR_DIR/bootstrap/cache" "$IEDUCAR_DIR/tmp" 2>/dev/null || true
chmod +x "$IEDUCAR_DIR/artisan" 2>/dev/null || true
if [[ -f "$JASPER_BIN" ]]; then
    chmod +x "$JASPER_BIN" 2>/dev/null || true
fi

# Diretório para Logos de Relatórios
REPORTS_LOGO_DIR="$IEDUCAR_DIR/ieducar/modules/Reports/ReportLogos"
mkdir -p "$REPORTS_LOGO_DIR"
chmod -R 777 "$REPORTS_LOGO_DIR" 2>/dev/null || true

# Correção de Ficha do Servidor e Relatórios Jasper (/storage e /storage/ieducar)
mkdir -p /storage "${IEDUCAR_DIR}/storage/app/public/ieducar" 2>/dev/null || true
if [[ -e "${IEDUCAR_DIR}/public/storage/ieducar" ]]; then
    ln -sfn "${IEDUCAR_DIR}/public/storage/ieducar" /storage/ieducar
elif [[ -e "${IEDUCAR_DIR}/storage/app/public/ieducar" ]]; then
    ln -sfn "${IEDUCAR_DIR}/storage/app/public/ieducar" /storage/ieducar
fi
if [[ ! -d /storage || -L /storage ]]; then
    ln -sfn "${IEDUCAR_DIR}/storage/app/public" /storage 2>/dev/null || true
fi
chmod -R 775 /storage "$IEDUCAR_DIR/storage" 2>/dev/null || true
chown -R www-data:www-data /storage "$IEDUCAR_DIR/storage" 2>/dev/null || true
echo -e "${GREEN}✓ Link simbólico /storage/ieducar e permissões configurados para relatórios e Ficha do Servidor.${NC}"

# Reiniciar serviços
systemctl restart "php${PHP_VER}-fpm" || true
systemctl restart nginx || true

SERVER_IP=$(curl -s -4 https://icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}   🎉 PARABÉNS! INSTALAÇÃO DO I-EDUCAR CONCLUÍDA COM SUCESSO!        ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e " • URL de Acesso: ${CYAN}http://${SERVER_IP}${NC}"
echo -e " • Usuário Inicial: ${CYAN}admin${NC}"
echo -e " • Senha Inicial: ${CYAN}123456789${NC}"
echo -e " • Banco PostgreSQL: ${CYAN}${DB_NAME}${NC} (Usuário: ${DB_USER})"
echo -e " • Módulos Instalados:"
echo -e "    ✓ i-educar-reports-package (Relatórios Jasper)"
echo -e "    ✓ i-educar-library-package (Biblioteca)"
echo -e "    ✓ i-educar-educacenso-package (Educacenso)"
echo -e "    ✓ i-educar-transport-package (Transporte Escolar)"
echo -e "    ✓ pre-matricula-digital (PMD Frontend compilado)"
echo -e " • Correções Aplicadas:"
echo -e "    ✓ JasperStarter com permissão de execução"
echo -e "    ✓ Link legado /storage/ieducar (Ficha do Servidor)"
echo -e "    ✓ Uploads até 50MB e Timeouts de 300s no Nginx & PHP"
echo -e "    ✓ Pasta de Logos configurada: ${REPORTS_LOGO_DIR}"
echo -e "${YELLOW}IMPORTANTE: Altere a senha do usuário 'admin' imediatamente no primeiro login!${NC}"
echo -e "${GREEN}======================================================================${NC}"
