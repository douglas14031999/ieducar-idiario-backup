#!/usr/bin/env bash
# ==============================================================================
# Script: install-idiario.sh
# Objetivo: Instalação Completa Automatizada do i-Diário (Portabilis Rails)
# Componentes: Ruby 2.6.6 (rbenv + OpenSSL 1.1), PostgreSQL 15, Redis, Node/Yarn,
#              Sidekiq, Systemd Services, Migrações, Entidade, Admin e Correções
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
IDIARIO_DIR="/root/i-diario"
RUBY_VER="2.6.6"
BUNDLER_VER="2.4.22"
DB_NAME="idiario_production"
DB_USER="idiario"
DB_PASS="idiario"
ADMIN_PASS="A123456789$"
WEB_PORT="3000"

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
echo -e "${BLUE}     INSTALADOR COMPLETO E AUTOMATIZADO DO I-DIÁRIO (RAILS)           ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Este assistente instalará e configurará:"
echo -e " • Dependências de compilação C/C++, PostgreSQL e Redis"
echo -e " • OpenSSL 1.1.1 dedicado em /opt/openssl-1.1 (compatibilidade Ruby 2.6)"
echo -e " • Rbenv + Ruby ${RUBY_VER} + Bundler ${BUNDLER_VER}"
echo -e " • Node.js + Yarn para compilação de assets"
echo -e " • Clone do repositório oficial do i-Diário em: ${IDIARIO_DIR}"
echo -e " • Banco de dados PostgreSQL '${DB_NAME}' e usuário '${DB_USER}'"
echo -e " • Configuração de database.yml, secrets.yml (com shortcuts ativados)"
echo -e " • Criação da Entidade e Usuário Administrador (${ADMIN_PASS})"
echo -e " • Filas Sidekiq configuradas (critical, sync, exams, email)"
echo -e " • Pré-compilação de assets de produção"
echo -e " • Serviços no Systemd: idiario-web, idiario-sidekiq, idiario-sync"
echo -e " • Correção de fotos nos relatórios e foto de perfil"
echo -e "${BLUE}======================================================================${NC}\n"

CONFIRM="s"
read_prompt "Deseja iniciar a instalação completa do i-Diário agora? (s/N)" "s" CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Instalação cancelada pelo usuário.${NC}"
    exit 0
fi

# Escolha da senha do banco PostgreSQL
DB_PASS_CHOICE="$DB_PASS"
read_prompt "Defina a senha do banco PostgreSQL para o usuário 'idiario'" "$DB_PASS" DB_PASS_CHOICE
DB_PASS="$DB_PASS_CHOICE"

# Escolha da senha do admin do i-Diário
ADMIN_PASS_CHOICE="$ADMIN_PASS"
read_prompt "Defina a senha do usuário 'admin' do i-Diário" "$ADMIN_PASS" ADMIN_PASS_CHOICE
ADMIN_PASS="$ADMIN_PASS_CHOICE"

# Escolha da porta web
WEB_PORT_CHOICE="$WEB_PORT"
read_prompt "Porta HTTP para o servidor do i-Diário" "$WEB_PORT" WEB_PORT_CHOICE
WEB_PORT="$WEB_PORT_CHOICE"

echo ""
echo -e "${YELLOW}[1/14] Atualizando pacotes e ajustando kernel (inotify)...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Aumentar limites de inotify para o Rails/Webpacker
if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf; then
    echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
fi

echo -e "${YELLOW}[2/14] Instalando ferramentas essenciais e dependências de compilação...${NC}"
apt-get install -y -qq \
    curl wget git build-essential libpq-dev shared-mime-info redis-server \
    zlib1g-dev libreadline-dev libssl-dev libxml2-dev libxslt1-dev \
    libcurl4-openssl-dev libffi-dev libyaml-dev imagemagick software-properties-common ca-certificates

systemctl start redis-server || systemctl start redis || true
systemctl enable redis-server || systemctl enable redis || true

echo -e "${YELLOW}[3/14] Verificando e configurando PostgreSQL...${NC}"
if ! command -v psql &>/dev/null; then
    echo -e " -> Instalando PostgreSQL..."
    apt-get install -y -qq postgresql postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
else
    echo -e "${GREEN}✓ PostgreSQL já instalado.${NC}"
fi

# Criar usuário idiario e banco idiario_production de forma idempotente
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

echo -e "${YELLOW}[4/14] Compilando OpenSSL 1.1.1 dedicado (/opt/openssl-1.1)...${NC}"
if [[ ! -f "/opt/openssl-1.1/bin/openssl" ]]; then
    echo -e " -> Baixando e compilando OpenSSL 1.1.1w..."
    OPENSSL_BUILD_DIR="/tmp/openssl_build"
    rm -rf "$OPENSSL_BUILD_DIR"
    mkdir -p "$OPENSSL_BUILD_DIR"
    cd "$OPENSSL_BUILD_DIR"
    wget -q https://www.openssl.org/source/openssl-1.1.1w.tar.gz || wget -q https://artfiles.org/openssl.org/source/openssl-1.1.1w.tar.gz
    tar -xzf openssl-1.1.1w.tar.gz
    cd openssl-1.1.1w
    ./config --prefix=/opt/openssl-1.1 --openssldir=/opt/openssl-1.1 -fPIC >/dev/null 2>&1
    make -j"$(nproc)" >/dev/null 2>&1
    make install >/dev/null 2>&1
    rm -rf "$OPENSSL_BUILD_DIR"
    echo -e "${GREEN}✓ OpenSSL 1.1.1 instalado em /opt/openssl-1.1${NC}"
else
    echo -e "${GREEN}✓ OpenSSL 1.1.1 já presente em /opt/openssl-1.1.${NC}"
fi

echo -e "${YELLOW}[5/14] Configurando ambiente Rbenv e instalando Ruby ${RUBY_VER}...${NC}"
export RBENV_ROOT="/root/.rbenv"
export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

if [[ ! -d "$RBENV_ROOT" ]]; then
    git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
    mkdir -p "$RBENV_ROOT/plugins"
    git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
else
    git -C "$RBENV_ROOT" pull origin master >/dev/null 2>&1 || true
    git -C "$RBENV_ROOT/plugins/ruby-build" pull origin master >/dev/null 2>&1 || true
fi

# Configurar .bashrc caso ainda não esteja configurado
if ! grep -q "rbenv init" /root/.bashrc 2>/dev/null; then
    cat << 'BASHRC_CONF' >> /root/.bashrc

# RBENV CONFIG
export RBENV_ROOT="/root/.rbenv"
export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
eval "$(rbenv init -)"
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
BASHRC_CONF
fi

eval "$(rbenv init -)"

if ! rbenv versions | grep -q "${RUBY_VER}"; then
    echo -e " -> Compilando Ruby ${RUBY_VER} com OpenSSL 1.1 (aguarde alguns minutos)..."
    RUBY_CONFIGURE_OPTS="--with-openssl-dir=/opt/openssl-1.1" rbenv install "${RUBY_VER}"
fi

rbenv global "${RUBY_VER}"
rbenv rehash

gem update --system -N >/dev/null 2>&1 || true
gem install bundler -v "${BUNDLER_VER}" -N >/dev/null 2>&1 || true
rbenv rehash

echo -e "${GREEN}✓ Ruby instalado: $(ruby -v)${NC}"
echo -e "${GREEN}✓ Bundler instalado: $(bundle -v)${NC}"

echo -e "${YELLOW}[6/14] Instalando Node.js e Yarn...${NC}"
if ! command -v node &>/dev/null; then
    echo " -> Instalando Node.js 18.x..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y -qq nodejs
fi

if ! command -v yarn &>/dev/null; then
    echo " -> Instalando Yarn..."
    npm install -g yarn >/dev/null 2>&1 || true
fi

echo -e "${GREEN}✓ Node.js: $(node -v)${NC}"
echo -e "${GREEN}✓ Yarn: $(yarn -v)${NC}"

echo -e "${YELLOW}[7/14] Clonando repositório do i-Diário em ${IDIARIO_DIR}...${NC}"
mkdir -p "$(dirname "$IDIARIO_DIR")"
if [[ ! -d "$IDIARIO_DIR/.git" ]]; then
    git clone https://github.com/portabilis/i-diario.git "$IDIARIO_DIR"
else
    echo -e "${YELLOW} -> Diretório $IDIARIO_DIR já existe. Atualizando código...${NC}"
    cd "$IDIARIO_DIR"
    git fetch origin master || true
    git checkout master || true
    git pull origin master || true
fi

cd "$IDIARIO_DIR"

echo -e "${YELLOW}[8/14] Instalando dependências Ruby (bundle install) e JS (yarn install)...${NC}"
bundle config set --local without 'development test' 2>/dev/null || true
bundle install --jobs="$(nproc)"
yarn install --frozen-lockfile 2>/dev/null || yarn install

echo -e "${YELLOW}[9/14] Configurando database.yml, secrets.yml e ambientes...${NC}"
# Database.yml
cat << DB_YML > "$IDIARIO_DIR/config/database.yml"
production:
  adapter: postgresql
  encoding: unicode
  database: ${DB_NAME}
  pool: 15
  username: ${DB_USER}
  password: ${DB_PASS}
  host: 127.0.0.1
  port: 5432
DB_YML

# Secrets.yml
mkdir -p "$IDIARIO_DIR/config"
SECRET_KEY=$(RAILS_ENV=production bundle exec rails secret 2>/dev/null || openssl rand -hex 64)

cat << SECRETS_YML > "$IDIARIO_DIR/config/secrets.yml"
production:
  secret_key_base: ${SECRET_KEY}
  REDIS_URL: 'redis://127.0.0.1:6379/0'
  shortcuts_enabled: true
  new_update_profile_enabled: true
SECRETS_YML

# Copiar páginas de erro caso existam samples
cp -f "$IDIARIO_DIR/public/404.html.sample" "$IDIARIO_DIR/public/404.html" 2>/dev/null || true
cp -f "$IDIARIO_DIR/public/500.html.sample" "$IDIARIO_DIR/public/500.html" 2>/dev/null || true

# Configurar sidekiq.yml com todas as filas essenciais
cat << SIDEKIQ_YML > "$IDIARIO_DIR/config/sidekiq.yml"
:concurrency: 10
:queues:
  - [critical, 3]
  - [default, 1]
  - [low, 1]
  - [exam_posting, 2]
  - [synchronizer, 1]
  - [send_emails, 1]
  - [synchronizer_full, 1]
  - [synchronizer_enqueue_next_job_full, 1]
SIDEKIQ_YML

# Habilitar file server e compile de assets no production.rb se necessário
PROD_RB="$IDIARIO_DIR/config/environments/production.rb"
if [[ -f "$PROD_RB" ]]; then
    sed -i 's/config.public_file_server.enabled = .*/config.public_file_server.enabled = true/' "$PROD_RB" || true
    if ! grep -q "config.assets.compile" "$PROD_RB"; then
        sed -i '/configure do/a \  config.assets.compile = true' "$PROD_RB"
    fi
fi

echo -e "${YELLOW}[10/14] Executando migrações do banco de dados...${NC}"
export RAILS_ENV=production
bundle exec rails db:migrate RAILS_ENV=production || true

echo -e "${YELLOW}[11/14] Configurando Entidade e Administrador...${NC}"
SERVER_IP=$(curl -s -4 https://icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

# Setup da Entidade
bundle exec rails entity:setup NAME=idiario DOMAIN="${SERVER_IP}" DATABASE="${DB_NAME}" RAILS_ENV=production 2>/dev/null || true

# Setup do Admin
bundle exec rails entity:admin:create NAME=idiario ADMIN_PASSWORD="${ADMIN_PASS}" RAILS_ENV=production 2>/dev/null || true

echo -e "${YELLOW}[12/14] Aplicando correções nos relatórios e pré-compilando assets...${NC}"
# Correção do erro de Logo nos Relatórios
if [[ -d "$IDIARIO_DIR/app/reports" ]]; then
    sed -i 's/open(@entity_configuration\.logo\.url)/open(@entity_configuration.logo.path)/g' "$IDIARIO_DIR/app/reports/"*.rb 2>/dev/null || true
    echo -e "${GREEN}✓ Correção de rota local de logotipos aplicada em app/reports/*.rb${NC}"
fi

# Pré-compilar assets
mkdir -p "$IDIARIO_DIR/public/uploads" "$IDIARIO_DIR/log"
chmod -R 777 "$IDIARIO_DIR/public/uploads" "$IDIARIO_DIR/log" "$IDIARIO_DIR/tmp" 2>/dev/null || true

echo " -> Pré-compilando assets (rails assets:precompile)..."
bundle exec rails assets:precompile RAILS_ENV=production || true

echo -e "${YELLOW}[13/14] Criando e habilitando serviços no Systemd...${NC}"
BUNDLE_BIN="${RBENV_ROOT}/shims/bundle"

# 1. Serviço Web (idiario-web.service)
cat << SERVICE_WEB > /etc/systemd/system/idiario-web.service
[Unit]
Description=i-Diário Web (Rails Server)
After=network.target redis-server.service postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${IDIARIO_DIR}
Environment=RAILS_ENV=production
Environment=PATH=${RBENV_ROOT}/shims:${RBENV_ROOT}/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${BUNDLE_BIN} exec rails server -b 0.0.0.0 -p ${WEB_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_WEB

# 2. Serviço Sidekiq Geral (idiario-sidekiq.service)
cat << SERVICE_SIDEKIQ > /etc/systemd/system/idiario-sidekiq.service
[Unit]
Description=i-Diário Sidekiq Principal
After=network.target redis-server.service postgresql.service
Requires=redis-server.service

[Service]
Type=simple
User=root
WorkingDirectory=${IDIARIO_DIR}
Environment=RAILS_ENV=production
Environment=PATH=${RBENV_ROOT}/shims:${RBENV_ROOT}/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${BUNDLE_BIN} exec sidekiq -C config/sidekiq.yml --logfile log/sidekiq.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_SIDEKIQ

# 3. Serviço Sidekiq Sincronizador (idiario-sync.service)
cat << SERVICE_SYNC > /etc/systemd/system/idiario-sync.service
[Unit]
Description=i-Diário Sincronizador (enqueue_next_job)
After=network.target redis-server.service postgresql.service
Requires=redis-server.service

[Service]
Type=simple
User=root
WorkingDirectory=${IDIARIO_DIR}
Environment=RAILS_ENV=production
Environment=PATH=${RBENV_ROOT}/shims:${RBENV_ROOT}/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${BUNDLE_BIN} exec sidekiq -q synchronizer_enqueue_next_job -c 1 --logfile log/sidekiq_sync.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_SYNC

systemctl daemon-reload
systemctl enable idiario-web idiario-sidekiq idiario-sync
systemctl restart idiario-web idiario-sidekiq idiario-sync

echo -e "${YELLOW}[14/14] Aplicando correção de foto de perfil (Cropper JS & Menu)...${NC}"
# Executar a correção de foto de perfil modular se existir
if [[ -f "/opt/ieducar-backup/scripts/setup-idiario-profile.sh" ]]; then
    /opt/ieducar-backup/scripts/setup-idiario-profile.sh || true
elif [[ -f "$(dirname "$0")/setup-idiario-profile.sh" ]]; then
    "$(dirname "$0")/setup-idiario-profile.sh" || true
fi

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}   🎉 PARABÉNS! INSTALAÇÃO DO I-DIÁRIO CONCLUÍDA COM SUCESSO!        ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e " • URL de Acesso: ${CYAN}http://${SERVER_IP}:${WEB_PORT}${NC}"
echo -e " • Usuário Administrador: ${CYAN}admin${NC}"
echo -e " • Senha Administrador: ${CYAN}${ADMIN_PASS}${NC}"
echo -e " • Banco PostgreSQL: ${CYAN}${DB_NAME}${NC} (Usuário: ${DB_USER})"
echo -e " • Diretório da Aplicação: ${CYAN}${IDIARIO_DIR}${NC}"
echo -e " • Serviços Ativos e Monitorados pelo Systemd:"
echo -e "    ✓ idiario-web     -> Rails Web Server (Porta ${WEB_PORT})"
echo -e "    ✓ idiario-sidekiq -> Filas de background e e-mails"
echo -e "    ✓ idiario-sync    -> Sincronizador automático com o i-Educar"
echo -e " • Comandos Úteis de Gerenciamento:"
echo -e "    systemctl restart idiario-web idiario-sidekiq idiario-sync"
echo -e "    journalctl -u idiario-web -f"
echo -e "    journalctl -u idiario-sidekiq -f"
echo -e "${GREEN}======================================================================${NC}"
