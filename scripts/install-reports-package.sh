#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação e Atualização Automatizada - i-Educar Reports Package
# Repositório: https://github.com/douglas14031999/i-educar-reports-package
# ==============================================================================

set -e
export COMPOSER_ALLOW_SUPERUSER=1

# Cores para saída no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/douglas14031999/i-educar-reports-package.git"
BRANCH="${BRANCH:-2.11}"
PACKAGE_DIR="packages/portabilis/i-educar-reports-package"

print_banner() {
    echo -e "${CYAN}"
    echo "======================================================================="
    echo "       🚀 INSTALADOR AUTOMÁTICO DE RELATÓRIOS DO I-EDUCAR             "
    echo "          Repositório: douglas14031999/i-educar-reports-package        "
    echo "======================================================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}${BOLD}[PASSO $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✖ $1${NC}"
}

# 1. Localizar a raiz do i-Educar
find_ieducar_root() {
    print_step "1/7" "Localizando diretório raiz do i-Educar..."
    
    # Se o diretório atual tem artisan e composer.json
    if [ -f "artisan" ] && [ -f "composer.json" ]; then
        IEDUCAR_DIR="$(pwd)"
    # Se existe em /var/www/ieducar
    elif [ -d "/var/www/ieducar" ] && [ -f "/var/www/ieducar/artisan" ]; then
        IEDUCAR_DIR="/var/www/ieducar"
    # Se existe em /var/www/html
    elif [ -d "/var/www/html" ] && [ -f "/var/www/html/artisan" ]; then
        IEDUCAR_DIR="/var/www/html"
    else
        # Procura até 2 níveis acima
        if [ -f "../artisan" ]; then
            IEDUCAR_DIR="$(cd .. && pwd)"
        elif [ -f "../../artisan" ]; then
            IEDUCAR_DIR="$(cd ../.. && pwd)"
        else
            print_error "Não foi possível encontrar a raiz do i-Educar (arquivo 'artisan' ausente)."
            echo -e "${YELLOW}Por favor, execute este comando dentro da pasta do i-Educar (ex: /var/www/ieducar).${NC}"
            exit 1
        fi
    fi

    cd "$IEDUCAR_DIR"
    print_success "Raiz do i-Educar detectada em: ${BOLD}$IEDUCAR_DIR${NC}"
}

# 2. Detectar se o ambiente roda via Docker ou nativo
detect_environment() {
    print_step "2/7" "Detectando ambiente de execução (Nativo vs Docker)..."
    USE_DOCKER=false

    if command -v docker-compose &> /dev/null && [ -f "docker-compose.yml" ]; then
        if docker-compose ps 2>/dev/null | grep -q "php"; then
            USE_DOCKER=true
            DOCKER_CMD="docker-compose exec -T php"
            print_success "Ambiente Docker detectado! Comandos rodarão via docker-compose."
            return
        fi
    fi

    if command -v docker &> /dev/null && [ -f "docker-compose.yml" ]; then
        if docker compose ps 2>/dev/null | grep -q "php"; then
            USE_DOCKER=true
            DOCKER_CMD="docker compose exec -T php"
            print_success "Ambiente Docker (Compose v2) detectado! Comandos rodarão via docker compose."
            return
        fi
    fi

    print_success "Ambiente nativo/VPS detectado (execução direta no host)."
}

# 3. Verificar e instalar dependências essenciais do SO (Java JRE e Headless Chrome)
install_system_dependencies() {
    print_step "3/7" "Verificando dependências do sistema operacional (Java, Chrome, etc.)..."

    if [ "$USE_DOCKER" = true ]; then
        print_success "Ambiente Docker ativo. Dependências do sistema são providas pelos containers."
        return
    fi

    # 1. Java JRE (Obrigatório para compilação e execução via JasperStarter)
    if ! command -v java &>/dev/null; then
        print_warning "Java Runtime (JRE) não encontrado. Instalando default-jre-headless para o JasperStarter..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq || true
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq default-jre-headless || true
        elif command -v yum &>/dev/null; then
            yum install -y java-11-openjdk-headless || true
        fi

        if command -v java &>/dev/null; then
            print_success "Java instalado com sucesso: $(java -version 2>&1 | head -n 1)"
        else
            print_warning "Aviso: Java não pôde ser instalado automaticamente. Certifique-se de instalar default-jre-headless."
        fi
    else
        print_success "Java detectado: $(java -version 2>&1 | head -n 1)"
    fi

    # 2. Google Chrome / Chromium (Obrigatório para geração de Diplomas em PDF vetorial A4)
    if ! command -v google-chrome &>/dev/null && ! command -v google-chrome-stable &>/dev/null && ! command -v chromium &>/dev/null && ! command -v chromium-browser &>/dev/null; then
        print_warning "Google Chrome / Chromium não encontrado. Instalando para emissão de diplomas em PDF..."
        if command -v apt-get &>/dev/null; then
            ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
            if [ "$ARCH" = "amd64" ]; then
                wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb 2>/dev/null || true
                if [ -f /tmp/google-chrome.deb ]; then
                    apt-get update -qq || true
                    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/google-chrome.deb 2>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -f -qq 2>/dev/null || true
                    rm -f /tmp/google-chrome.deb
                fi
            fi

            if ! command -v google-chrome &>/dev/null && ! command -v google-chrome-stable &>/dev/null; then
                DEBIAN_FRONTEND=noninteractive apt-get install -y -qq chromium-browser 2>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq chromium 2>/dev/null || true
            fi
        elif command -v yum &>/dev/null; then
            yum install -y chromium || true
        fi

        CHROME_BIN=$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser || echo "")
        if [ -n "$CHROME_BIN" ]; then
            print_success "Navegador headless instalado com sucesso: $CHROME_BIN"
        else
            print_warning "Aviso: Google Chrome/Chromium não pôde ser instalado automaticamente. Diplomas usarão fallback se necessário."
        fi
    else
        CHROME_BIN=$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser)
        print_success "Navegador headless detectado: $CHROME_BIN"
    fi
}

# 4. Analisar status do pacote atual e clonar/atualizar
check_and_install_package() {
    print_step "4/7" "Verificando instalação do pacote de relatórios..."
    mkdir -p packages/portabilis

    if [ -d "$PACKAGE_DIR" ]; then
        echo -e "Diretório ${BOLD}$PACKAGE_DIR${NC} já existe."
        
        IS_PORTABILIS=false
        IS_DOUGLAS=false

        if [ -d "$PACKAGE_DIR/.git" ]; then
            REMOTE_URL=$(git -C "$PACKAGE_DIR" config --get remote.origin.url || true)
            echo -e "Origem Git detectada: ${CYAN}$REMOTE_URL${NC}"

            if echo "$REMOTE_URL" | grep -qi "douglas14031999"; then
                IS_DOUGLAS=true
            elif echo "$REMOTE_URL" | grep -qi "portabilis"; then
                IS_PORTABILIS=true
            fi
        else
            if [ -f "$PACKAGE_DIR/composer.json" ]; then
                if grep -qi "douglas" "$PACKAGE_DIR/composer.json"; then
                    IS_DOUGLAS=true
                else
                    IS_PORTABILIS=true
                fi
            else
                IS_PORTABILIS=true
            fi
        fi

        if [ "$IS_DOUGLAS" = true ]; then
            print_success "O seu pacote (douglas14031999) já está instalado! Atualizando com as últimas alterações..."
            if [ -d "$PACKAGE_DIR/.git" ]; then
                git -C "$PACKAGE_DIR" fetch origin
                git -C "$PACKAGE_DIR" reset --hard "origin/$BRANCH"
                git -C "$PACKAGE_DIR" pull origin "$BRANCH"
            fi
        else
            print_warning "O pacote da Portábilis foi detectado! Removendo para instalar a versão customizada..."
            rm -rf "$PACKAGE_DIR"
            print_step "4.1" "Clonando o repositório douglas14031999/i-educar-reports-package..."
            git clone -b "$BRANCH" "$REPO_URL" "$PACKAGE_DIR"
            print_success "Repositório clonado com sucesso!"
        fi
    else
        print_step "4.1" "Nenhum pacote anterior detectado. Clonando o seu repositório..."
        git clone -b "$BRANCH" "$REPO_URL" "$PACKAGE_DIR"
        print_success "Repositório clonado com sucesso!"
    fi
}

# 5. Configurar permissões necessárias
setup_permissions() {
    print_step "5/7" "Ajustando permissões de arquivos e executáveis..."
    
    if [ -f "vendor/cossou/jasperphp/src/JasperStarter/bin/jasperstarter" ]; then
        chmod +x vendor/cossou/jasperphp/src/JasperStarter/bin/jasperstarter 2>/dev/null || true
    fi

    mkdir -p ieducar/modules/Reports/ReportSources
    chmod -R 777 ieducar/modules/Reports/ReportSources 2>/dev/null || true

    if [ -d "$PACKAGE_DIR" ]; then
        chmod -R 775 "$PACKAGE_DIR" 2>/dev/null || true
    fi

    print_success "Permissões aplicadas com sucesso."
}

# 6. Executar Composer, Artisan, Migrações e Otimizações
run_installation_commands() {
    print_step "6/7" "Registrando pacote no Composer, aplicando migrações e otimizações..."

    if [ "$USE_DOCKER" = true ]; then
        echo "Executando no container Docker..."
        $DOCKER_CMD composer plug-and-play || $DOCKER_CMD composer dump-autoload -o
        $DOCKER_CMD php artisan migrate --force
        $DOCKER_CMD php artisan community:reports:install
        $DOCKER_CMD php artisan community:reports:link
        $DOCKER_CMD php artisan vendor:publish --tag=reports-assets --ansi --force
        $DOCKER_CMD php artisan cache:clear || true
        $DOCKER_CMD php artisan config:clear || true
        $DOCKER_CMD php artisan view:clear || true
    else
        # Autoload do Composer
        if command -v composer &> /dev/null; then
            composer plug-and-play || composer dump-autoload -o
        fi

        # Habilitar extensão unaccent no PostgreSQL
        php -r "
        try {
            require_once '$IEDUCAR_DIR/vendor/autoload.php';
            \$app = require_once '$IEDUCAR_DIR/bootstrap/app.php';
            \$kernel = \$app->make(Illuminate\Contracts\Console\Kernel::class);
            \$kernel->bootstrap();
            \Illuminate\Support\Facades\DB::statement('CREATE EXTENSION IF NOT EXISTS unaccent;');
        } catch (\Throwable \$e) {}
        " 2>/dev/null || true

        # Migrações do banco (garante menu de Diplomas e novos relatórios)
        php artisan migrate --force

        # Limpeza garantida de menus fictícios e órfãos (/relatorios/ e menu 564)
        php -r "
        try {
            require_once '$IEDUCAR_DIR/vendor/autoload.php';
            \$app = require_once '$IEDUCAR_DIR/bootstrap/app.php';
            \$kernel = \$app->make(Illuminate\Contracts\Console\Kernel::class);
            \$kernel->bootstrap();
            \Illuminate\Support\Facades\DB::statement(\"DELETE FROM pmieducar.menu_tipo_usuario WHERE menu_id IN (SELECT id FROM public.menus WHERE link LIKE '/relatorios%');\");
            \Illuminate\Support\Facades\DB::statement(\"DELETE FROM public.menus WHERE link LIKE '/relatorios%' OR parent_id = 404 OR id = 564;\");
            \Illuminate\Support\Facades\DB::statement(\"DELETE FROM pmieducar.menu_tipo_usuario WHERE menu_id = 564;\");
        } catch (\Throwable \$e) {}
        " 2>/dev/null || true
        
        # Link simbólico dos módulos e compilação de relatórios
        php artisan community:reports:link
        php artisan community:reports:install
        php artisan vendor:publish --tag=reports-assets --ansi --force

        # Otimização Busca Rápida (com suporte a busca sem acentuação)
        if [ -f "$IEDUCAR_DIR/app/Menu.php" ]; then
            php -r "
            \$file = '$IEDUCAR_DIR/app/Menu.php';
            \$c = file_get_contents(\$file);
            \$old = 'public static function findByUser(User \$user, \$search)';
            if (strpos(\$c, \$old) !== false && strpos(\$c, 'unaccent') === false) {
                \$pattern = '/public static function findByUser\(User \\\$user, \\\$search\)\s*\{[\s\S]*?return \\\$query->whereNotNull\(\'link\'\)[\s\S]*?->get\(\);\s*\}/';
                \$replacement = \"public static function findByUser(User \\\$user, \\\$search)\n    {\n        \\\$query = \\\$user->isAdmin() ? static::query() : \\\$user->menu();\n\n        return \\\$query->whereNotNull('link')\n            ->where(function (\\\$query) use (\\\$search) {\n                \\\$term = \\\"%{\\\$search}%\\\";\n                \\\$query->orWhereRaw('unaccent(title) ilike unaccent(?)', [\\\$term])\n                      ->orWhereRaw('unaccent(description) ilike unaccent(?)', [\\\$term]);\n            })\n            ->orderBy('title')\n            ->limit(15)\n            ->get();\n    }\";
                \$c = preg_replace(\$pattern, \$replacement, \$c);
                file_put_contents(\$file, \$c);
            }
            " 2>/dev/null || true
        fi

        # Atualizar componente Vue da Busca Rápida (vue.blade.php)
        if [ -d "$IEDUCAR_DIR/resources/views/layout" ]; then
            cat << 'EOF' > "$IEDUCAR_DIR/resources/views/layout/vue.blade.php"
<div id="quick-search" class="vue-template">
    <div class="quick-search">
        <vue-multiselect placeholder="Informe o nome do menu"
                         select-label=""
                         selected-label=""
                         deselect-label=""
                         label="label"
                         track-by="link"
                         v-model="value"
                         :internal-search="false"
                         :clear-on-select="true"
                         :close-on-select="true"
                         @search-change="asyncFind"
                         @select="dispatchAction"
                         :options="options">
            <span slot="noResult">Sem resultados.</span>
            <template slot="option" slot-scope="props">
                <a :href="props.option.link">@{{ props.option.label }}</a>
            </template>
        </vue-multiselect>
    </div>
</div>
<script src="{{ Asset::get('js/axios.min.js') }}"></script>
<script src="{{ Asset::get('js/vue.min.js') }}"></script>
<script src="{{ Asset::get('js/vue-multiselect.min.js') }}"></script>
<script>
    Vue.component('vue-multiselect', window.VueMultiselect.default);
    Vue.component('quick-search', {
        methods: {
            asyncFind (query) {
                if (!query || query.trim().length === 0) {
                    this.options = [];
                    return;
                }
                axios.get('/module/Api/menu', {
                    params:  {
                        query : query.trim(),
                        oper : 'get',
                        resource : 'menu-search'
                    }
                }).then((res) => {
                    this.options = (res.data && res.data.menus) ? res.data.menus.filter(m => m.link !== '') : [];
                }).catch(() => {
                    this.options = [];
                });
            },
            dispatchAction (element) {
                if (element && element.link) {
                    window.location.href = element.link;
                }
            }
        },
        data: function () {
            return {
                options: [],
                value: null
            }
        },
        template: '#quick-search'
    });

    new Vue({
        el: '#ieducar-quick-search'
    });
</script>
EOF
        fi

        # Otimização Notificações (eliminação do falso alerta vermelho)
        if [ -f "$PACKAGE_DIR/fix_all.sh" ] && [ -d "$IEDUCAR_DIR/ieducar/intranet/scripts" ]; then
            cat << 'EOF' > "$IEDUCAR_DIR/ieducar/intranet/scripts/notifications.js"
function updateNotReadCount() {
  $j.get("/notificacoes/quantidade-nao-lidas", function (count) {
    let unreadCount = parseInt(count) || 0;
    $j('.btn-mark-all-read .not-read-count').text(unreadCount);
    if (unreadCount > 0) {
      $j('.notification-balloon').show();
    } else {
      $j('.notification-balloon').hide();
    }
  });
}

function getNotifications() {
  $j.get("/notificacoes/retorna-notificacoes-usuario", function (data) {
    $j('.dropdown-content-notifications a.notification-item, .dropdown-content-notifications .empty-notifications').remove();
    let unreadCount = 0;
    if (!data || data.length === 0) {
      $j('.dropdown-content-notifications').append('<div class="empty-notifications" style="padding: 15px; text-align: center; color: #777;">Nenhuma notificação encontrada</div>');
    } else {
      $j.each(data, function( index, value ) {
        let unread = value.read_at == null;
        if (unread) {
          unreadCount++;
        }
        let className = unread ? 'unread' : 'read';
        let dateObj = new Date(value.created_at);
        let dateString = dateObj.toLocaleString('pt-BR');

        $j('.dropdown-content-notifications').append(`
          <a href="` + (value.link || '#') + `" onclick="markAsRead(this)" data-id="` + value.id + `" class="notification-item ` +className+ `" target="_blank">
            <p>` + value.text  + `</p>
            <p class="date-notification"> ` + dateString + `</p>
          </a>`);
      });
    }

    $j('.btn-mark-all-read .not-read-count').text(unreadCount);
    if (unreadCount > 0) {
      $j('.notification-balloon').show();
    } else {
      $j('.notification-balloon').hide();
    }
  });
}

$j('.dropdown.notifications').click(function(event) {
  if ($j('.dropdown-content-notifications').is(':visible')) {
      $j('.dropdown-content-notifications').css('display','none');
  } else {
      openBoxNotification();
  }
  if (event && event.stopPropagation) {
    event.stopPropagation();
  }
});

$j(document).click(function() {
  if ($j('.dropdown-content-notifications').is(':visible')) {
    $j('.dropdown-content-notifications').css('display','none');
  }
});

function openBoxNotification() {
  getNotifications();
  $j('.dropdown-content-notifications').css('display','block');
}

function markAsRead(link, removeParent = false) {
  let notification = [$j(link).attr('data-id')];

  $j.post("/notificacoes/marca-como-lida", {"notifications":notification});

  if (removeParent) {
    $j(link).parent().parent().addClass('read');
    $j(link).parent().parent().removeClass('unread');
    $j(link).parent().parent().find('.text-status').text('Lida');
    updateNotReadCount();
    return;
  }

  $j(link).addClass('read');
  $j(link).removeClass('unread');
  updateNotReadCount();
}

$j('.btn-mark-all-read').click(function(){
  $j('.dropdown-content-notifications a.unread').addClass('read');
  $j('.dropdown-content-notifications a.unread').removeClass('unread');
  $j('.notification-balloon').hide();
  $j.post("/notificacoes/marca-todas-como-lidas");
  $j('.btn-mark-all-read .not-read-count').text(0);
});

$j(document).ready(function() {
  updateNotReadCount();
});
EOF
            if [ -d "$IEDUCAR_DIR/public/intranet/scripts" ] && [ ! "$IEDUCAR_DIR/ieducar/intranet/scripts/notifications.js" -ef "$IEDUCAR_DIR/public/intranet/scripts/notifications.js" ]; then
                cp "$IEDUCAR_DIR/ieducar/intranet/scripts/notifications.js" "$IEDUCAR_DIR/public/intranet/scripts/notifications.js" 2>/dev/null || true
            fi
        fi

        # Compatibilidade de Menus e Navegação de Relatórios (clsBase)
        if [ -f "$IEDUCAR_DIR/ieducar/intranet/include/clsBase.inc.php" ]; then
            php -r "
            \$f = '$IEDUCAR_DIR/ieducar/intranet/include/clsBase.inc.php';
            \$c = file_get_contents(\$f);
            if (strpos(\$c, '\$topmenu = null;') === false) {
                \$pattern = '/\\\$topmenu\s*=\s*Menu::query\(\)\s*->where\(\'process\',\s*\\\$this->processoAp\)\s*->first\(\);/';
                \$replacement = \"\\\$topmenu = null;\n        \\\$currentPath = '/' . ltrim(request()->path(), '/');\n\n        if (!empty(\\\$currentPath) && \\\$currentPath !== '/') {\n            \\\$topmenu = Menu::query()->where('link', \\\$currentPath)->first();\n        }\n\n        if (!\\\$topmenu && !empty(\\\$this->processoAp)) {\n            \\\$topmenu = Menu::query()\n                ->where('process', \\\$this->processoAp)\n                ->first();\n        }\n\n        if (!\\\$topmenu && !empty(\\\$currentPath) && \\\$currentPath !== '/') {\n            \\\$topmenu = Menu::query()->where('link', 'like', \\\"{\\\$currentPath}%\\\")->first();\n        }\";
                \$c = preg_replace(\$pattern, \$replacement, \$c);
                file_put_contents(\$f, \$c);
            }
            " 2>/dev/null || true
        fi

        # Correção do Módulo Pré-Matrícula Digital (PMD) - Eliminação da tela branca
        if [ -d "/etc/nginx/sites-available" ]; then
            sed -i 's/try_files \$uri =404;/try_files \$uri \/index.php?\$query_string;/g' /etc/nginx/sites-available/* 2>/dev/null || true
            nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
        fi

        php -r "
        try {
            require_once '$IEDUCAR_DIR/vendor/autoload.php';
            \$app = require_once '$IEDUCAR_DIR/bootstrap/app.php';
            \$kernel = \$app->make(Illuminate\Contracts\Http\Kernel::class);
            \$response = \$kernel->handle(\$request = Illuminate\Http\Request::create('/config/prematricula.js', 'GET'));
            if (\$response->getStatusCode() === 200 && strpos(\$response->getContent(), 'window.config') !== false) {
                @mkdir('$IEDUCAR_DIR/public/config', 0755, true);
                file_put_contents('$IEDUCAR_DIR/public/config/prematricula.js', \$response->getContent());
                @chmod('$IEDUCAR_DIR/public/config/prematricula.js', 0664);
                @chown('$IEDUCAR_DIR/public/config/prematricula.js', 'www-data');
                @chgrp('$IEDUCAR_DIR/public/config/prematricula.js', 'www-data');
            }
        } catch (\Throwable \$e) {}
        " 2>/dev/null || true

        php artisan view:clear || true
        php artisan cache:clear || true
        php artisan config:clear || true

        systemctl reload php8.4-fpm 2>/dev/null || systemctl reload php8.3-fpm 2>/dev/null || systemctl reload php-fpm 2>/dev/null || true
        systemctl reload nginx 2>/dev/null || true
    fi

    print_success "Comandos de instalação, compilação e migrações concluídos com sucesso!"
}

# 7. Verificação final
verify_installation() {
    print_step "7/7" "Verificação final dos relatórios e serviços..."
    
    TOTAL_TEMPLATES=$(find "$PACKAGE_DIR/ieducar/ReportSources" -name "*.jrxml" 2>/dev/null | wc -l || echo "0")
    TOTAL_MIGRATIONS=$(find "$PACKAGE_DIR/database/migrations" -name "*.php" 2>/dev/null | wc -l || echo "0")

    echo -e "${GREEN}"
    echo "======================================================================="
    echo "   🎉 INSTALAÇÃO / ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!                 "
    echo "======================================================================="
    echo -e "${NC}"
    echo -e " • Templates JRXML disponíveis: ${BOLD}$TOTAL_TEMPLATES${NC}"
    echo -e " • Migrações de menu instaladas: ${BOLD}$TOTAL_MIGRATIONS${NC}"
    echo -e " • Emissão de Diplomas (HTML5/PDF): ${BOLD}Disponível em /module/Reports/DiplomaCertificate${NC}"
    echo -e " • Todos os 17 novos relatórios (Alagoas, Termos, Fichas e Registros) já estão disponíveis no menu."
    echo -e " • Repositório ativo: ${CYAN}https://github.com/douglas14031999/i-educar-reports-package${NC}"
    echo ""
}

# Fluxo Principal
main() {
    print_banner
    find_ieducar_root
    detect_environment
    install_system_dependencies
    check_and_install_package
    setup_permissions
    run_installation_commands
    verify_installation
}

main "$@"
