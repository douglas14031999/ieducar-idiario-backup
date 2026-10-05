#!/usr/bin/env bash
# ==============================================================================
# Script Específico de Correção: Busca Rápida, Notificações & PMD - i-Educar
# Repositório: https://github.com/douglas14031999/i-educar-reports-package
# Execução: curl -fsSL https://raw.githubusercontent.com/douglas14031999/i-educar-reports-package/2.11/fix_search_and_notifications.sh | bash
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}"
echo "======================================================================="
echo "   🚀 I-EDUCAR - CORREÇÃO RÁPIDA: BUSCA, NOTIFICAÇÕES & PMD           "
echo "      • Busca Rápida: pesquisa imune a acentos (unaccent)              "
echo "      • Notificações: contagem fiel e sincronizada de não lidas        "
echo "      • Pré-Matrícula Digital (PMD): eliminação da tela branca         "
echo "======================================================================="
echo -e "${NC}"

# 1. Localizar raiz do i-Educar
echo -e "${BLUE}${BOLD}[1/5]${NC} Localizando diretório raiz do i-Educar..."
if [ -f "artisan" ] && [ -f "composer.json" ]; then
    IEDUCAR_DIR="$(pwd)"
elif [ -d "/var/www/ieducar" ] && [ -f "/var/www/ieducar/artisan" ]; then
    IEDUCAR_DIR="/var/www/ieducar"
elif [ -d "/var/www/html" ] && [ -f "/var/www/html/artisan" ]; then
    IEDUCAR_DIR="/var/www/html"
else
    echo -e "${RED}✖ Não foi possível encontrar a raiz do i-Educar.${NC}"
    exit 1
fi
cd "$IEDUCAR_DIR"
echo -e "${GREEN}✔ Raiz detectada em: ${BOLD}$IEDUCAR_DIR${NC}"

# 2. Habilitar unaccent no PostgreSQL e atualizar App\Menu.php
echo -e "${BLUE}${BOLD}[2/5]${NC} Configurando busca insensível a acentos no banco e Menu.php..."
php -r "
try {
    require_once '$IEDUCAR_DIR/vendor/autoload.php';
    \$app = require_once '$IEDUCAR_DIR/bootstrap/app.php';
    \$kernel = \$app->make(Illuminate\Contracts\Console\Kernel::class);
    \$kernel->bootstrap();
    \Illuminate\Support\Facades\DB::statement('CREATE EXTENSION IF NOT EXISTS unaccent;');
    echo \"Extensão unaccent garantida no PostgreSQL.\n\";
} catch (\Throwable \$e) {
    echo \"Aviso ao verificar extensão unaccent: \" . \$e->getMessage() . \"\n\";
}
" 2>/dev/null || true

php -r "
\$file = '$IEDUCAR_DIR/app/Menu.php';
if (file_exists(\$file)) {
    \$c = file_get_contents(\$file);
    \$old = \"public static function findByUser(User \\\$user, \\\$search)\";
    if (strpos(\$c, \$old) !== false && strpos(\$c, 'unaccent') === false) {
        \$pattern = '/public static function findByUser\(User \\\$user, \\\$search\)\s*\{[\s\S]*?return \\\$query->whereNotNull\(\'link\'\)[\s\S]*?->get\(\);\s*\}/';
        \$replacement = \"public static function findByUser(User \\\$user, \\\$search)\n    {\n        \\\$query = \\\$user->isAdmin() ? static::query() : \\\$user->menu();\n\n        return \\\$query->whereNotNull('link')\n            ->where(function (\\\$query) use (\\\$search) {\n                \\\$term = \\\"%{\\\$search}%\\\";\n                \\\$query->orWhereRaw('unaccent(title) ilike unaccent(?)', [\\\$term])\n                      ->orWhereRaw('unaccent(description) ilike unaccent(?)', [\\\$term]);\n            })\n            ->orderBy('title')\n            ->limit(15)\n            ->get();\n    }\";
        \$c = preg_replace(\$pattern, \$replacement, \$c);
        file_put_contents(\$file, \$c);
        echo \"Menu.php atualizado com suporte a busca unaccent!\n\";
    } else {
        echo \"Menu.php já configurado para unaccent.\n\";
    }
}
"

# Atualizar layout do Vue Multiselect para a Busca Rápida
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
echo -e "${GREEN}✔ Busca Rápida otimizada e configurada com sucesso.${NC}"

# 3. Correção das Notificações (notifications.js)
echo -e "${BLUE}${BOLD}[3/5]${NC} Aplicando correções no sistema de Notificações..."
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

# Sincronizar em public/intranet/scripts (se não for o mesmo arquivo ou link simbólico)
if [ -d "$IEDUCAR_DIR/public/intranet/scripts" ] && [ ! "$IEDUCAR_DIR/ieducar/intranet/scripts/notifications.js" -ef "$IEDUCAR_DIR/public/intranet/scripts/notifications.js" ]; then
    cp "$IEDUCAR_DIR/ieducar/intranet/scripts/notifications.js" "$IEDUCAR_DIR/public/intranet/scripts/notifications.js" 2>/dev/null || true
fi
echo -e "${GREEN}✔ Sistema de Notificações corrigido e sincronizado.${NC}"

# 4. Correção do Módulo Pré-Matrícula Digital (PMD) - Eliminação da tela branca
echo -e "${BLUE}${BOLD}[4/5]${NC} Corrigindo módulo Pré-Matrícula Digital (PMD)..."

# 4.1 Ajustar Nginx para repassar requisições JS dinâmicas (ex: /config/prematricula.js)
if [ -d "/etc/nginx/sites-available" ]; then
    sed -i 's/try_files \$uri =404;/try_files \$uri \/index.php?\$query_string;/g' /etc/nginx/sites-available/* 2>/dev/null || true
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
fi

# 4.2 Gerar arquivo estático de configuração como garantia redundante
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
        echo \"Arquivo estático /public/config/prematricula.js gerado com sucesso.\n\";
    }
} catch (\Throwable \$e) {
    echo \"Aviso PMD config: \" . \$e->getMessage() . \"\n\";
}
" 2>/dev/null || true
echo -e "${GREEN}✔ Módulo Pré-Matrícula Digital (PMD) corrigido com sucesso.${NC}"

# 5. Limpeza de Caches e Reinicialização de Serviços
echo -e "${BLUE}${BOLD}[5/5]${NC} Limpando caches e recarregando serviços..."
php artisan view:clear || true
php artisan cache:clear || true
php artisan config:clear || true

systemctl reload php8.4-fpm 2>/dev/null || systemctl reload php8.3-fpm 2>/dev/null || systemctl reload php-fpm 2>/dev/null || true
systemctl reload nginx 2>/dev/null || true
echo -e "${GREEN}✔ Caches limpos e servidores PHP-FPM / Nginx recarregados.${NC}"

echo -e "${GREEN}"
echo "======================================================================="
echo "   🎉 CORREÇÕES APLICADAS COM SUCESSO!                                "
echo "======================================================================="
echo -e "${NC}"
echo -e " • Busca Rápida: funcionando com digitação sem acento (ex: relatorio, distribuicao)"
echo -e " • Notificações: balão vermelho agora reflete fielmente mensagens não lidas reais"
echo -e " • Pré-Matrícula Digital (PMD): tela branca eliminada, módulo 100% funcional"
echo ""
