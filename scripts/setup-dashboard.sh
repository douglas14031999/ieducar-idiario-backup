#!/usr/bin/env bash
# ==============================================================================
# Script: setup-dashboard.sh
# Objetivo: Configurar a tela inicial de Atalhos Rápidos modernos no i-Educar
#           com 5 cards elegantes (Alunos, Servidores, Relatório por Turma,
#           Boletim Escolar e Histórico Escolar) e rotas diretas.
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== Configurando Painel de Atalhos Rápidos do i-Educar ===${NC}"

# 1. Localização 100% Automática do Diretório do i-Educar
detect_ieducar_dir() {
    # Estratégia A: Variável IEDUCAR_STORAGE_PATH no /etc/ieducar-backup/.env se existir
    if [[ -f /etc/ieducar-backup/.env ]]; then
        local env_storage
        env_storage=$(grep -E "^IEDUCAR_STORAGE_PATH=" /etc/ieducar-backup/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        if [[ -n "$env_storage" && -d "$env_storage" ]]; then
            local cand
            cand=$(dirname "$env_storage")
            if [[ -d "$cand/ieducar/intranet" || -d "$cand/intranet" || -f "$cand/artisan" ]]; then
                echo "$cand"
                return 0
            fi
        fi
    fi

    # Estratégia B: Caminhos padrão mais comuns em servidores Linux
    local common_paths=(
        "/var/www/ieducar"
        "/var/www/i-educar"
        "/var/www/html/ieducar"
        "/var/www/html/i-educar"
        "/var/www/html"
        "/srv/ieducar"
        "/opt/ieducar"
    )
    for p in "${common_paths[@]}"; do
        if [[ -d "$p/ieducar/intranet" || ( -d "$p/intranet" && -f "$p/artisan" ) ]]; then
            echo "$p"
            return 0
        fi
    done

    # Estratégia C: Detectar nas configurações do Nginx (/etc/nginx)
    if [[ -d /etc/nginx ]]; then
        local ngx_roots
        ngx_roots=$(grep -rhE "^\s*root\s+.*ieducar" /etc/nginx/ 2>/dev/null | awk '{print $2}' | tr -d ';' || true)
        for ngx_p in $ngx_roots; do
            local cand="$ngx_p"
            while [[ "$cand" != "/" && -n "$cand" ]]; do
                if [[ -d "$cand/ieducar/intranet" || ( -d "$cand/intranet" && -f "$cand/artisan" ) ]]; then
                    echo "$cand"
                    return 0
                fi
                cand=$(dirname "$cand")
            done
        done
    fi

    # Estratégia D: Detectar nas configurações do Apache (/etc/apache2 ou /etc/httpd)
    if [[ -d /etc/apache2 || -d /etc/httpd ]]; then
        local ap_roots
        ap_roots=$(grep -rhE "^\s*DocumentRoot\s+.*ieducar" /etc/apache2/ /etc/httpd/ 2>/dev/null | awk '{print $2}' | tr -d '"' || true)
        for ap_p in $ap_roots; do
            local cand="$ap_p"
            while [[ "$cand" != "/" && -n "$cand" ]]; do
                if [[ -d "$cand/ieducar/intranet" || ( -d "$cand/intranet" && -f "$cand/artisan" ) ]]; then
                    echo "$cand"
                    return 0
                fi
                cand=$(dirname "$cand")
            done
        done
    fi

    # Estratégia E: Busca rápida nos diretórios de aplicações (/var/www, /srv, /opt, /home, /root)
    local fast_file
    fast_file=$(find /var/www /srv /opt /home /root -maxdepth 5 -type f -name "educar_index.php" 2>/dev/null | head -n 1 || true)
    if [[ -n "$fast_file" ]]; then
        local d1 d2 d3
        d1=$(dirname "$fast_file") # .../intranet
        d2=$(dirname "$d1")        # .../ieducar
        d3=$(dirname "$d2")        # ex: /var/www/ieducar
        if [[ -f "$d3/artisan" || -d "$d3/routes" ]]; then
            echo "$d3"
            return 0
        elif [[ -f "$d2/artisan" || -d "$d2/routes" ]]; then
            echo "$d2"
            return 0
        else
            echo "$d2"
            return 0
        fi
    fi

    # Estratégia F: Busca profunda global no sistema de arquivos
    local deep_file
    deep_file=$(find / -path "/proc" -prune -o -path "/sys" -prune -o -path "/dev" -prune -o -path "/run" -prune -o -path "/tmp" -prune -o -type f -name "educar_index.php" -print 2>/dev/null | head -n 1 || true)
    if [[ -n "$deep_file" ]]; then
        local d1 d2 d3
        d1=$(dirname "$deep_file")
        d2=$(dirname "$d1")
        d3=$(dirname "$d2")
        if [[ -f "$d3/artisan" || -d "$d3/routes" ]]; then
            echo "$d3"
            return 0
        else
            echo "$d2"
            return 0
        fi
    fi

    return 1
}

echo -e "${BLUE}Localizando instalação do i-Educar automaticamente no servidor...${NC}"
IEDUCAR_DIR=$(detect_ieducar_dir || true)

if [[ -z "$IEDUCAR_DIR" || ! -d "$IEDUCAR_DIR" ]]; then
    echo -e "${RED}[ERRO] Instalação do i-Educar não foi localizada automaticamente.${NC}"
    echo "Certifique-se de que o i-Educar está presente neste servidor."
    exit 1
fi

echo -e "${GREEN}✓ i-Educar localizado com sucesso em: ${IEDUCAR_DIR}${NC}"

# Definir a pasta intranet exata
if [[ -d "${IEDUCAR_DIR}/ieducar/intranet" ]]; then
    INTRANET_DIR="${IEDUCAR_DIR}/ieducar/intranet"
elif [[ -d "${IEDUCAR_DIR}/intranet" ]]; then
    INTRANET_DIR="${IEDUCAR_DIR}/intranet"
else
    echo -e "${RED}[ERRO] Diretório intranet não encontrado em ${IEDUCAR_DIR}.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Pasta intranet identificada em: ${INTRANET_DIR}${NC}"

# Detectar proprietário e grupo web automaticamente a partir das permissões da pasta
WEB_USER=$(stat -c '%U' "$INTRANET_DIR" 2>/dev/null || echo "www-data")
WEB_GROUP=$(stat -c '%G' "$INTRANET_DIR" 2>/dev/null || echo "$WEB_USER")

if [[ "$WEB_USER" == "root" ]] && id -u "www-data" &>/dev/null; then
    WEB_USER="www-data"
    WEB_GROUP="www-data"
elif [[ "$WEB_USER" == "root" ]] && id -u "nginx" &>/dev/null; then
    WEB_USER="nginx"
    WEB_GROUP="nginx"
fi

# 2. Configurar a página index.php com os Atalhos Rápidos
echo -e "${BLUE}Configurando ${INTRANET_DIR}/index.php...${NC}"
cp -n "${INTRANET_DIR}/index.php" "${INTRANET_DIR}/index.php.bkp" 2>/dev/null || true

cat <<'EOF' > "${INTRANET_DIR}/index.php"
<?php

use Illuminate\Support\Facades\Auth;

return new class {
    public function RenderHTML()
    {
        $id_pessoa = Auth::id();
        if (!$id_pessoa) {
            return '';
        }

        // Links oficiais do i-Educar
        $urlAlunos = file_exists(__DIR__ . '/educar_aluno_lst.php') ? 'educar_aluno_lst.php' : 'educar_aluno_cad.php';
        $urlServidores = file_exists(__DIR__ . '/educar_servidor_lst.php') ? 'educar_servidor_lst.php' : 'educar_servidor_cad.php';
        $urlRelatorioAlunos = '/module/Reports/StudentsPerClass';
        $urlBoletim = '/module/Reports/ReportCard';
        $urlHistorico = file_exists(__DIR__ . '/educar_historico_escolar_lst.php') ? 'educar_historico_escolar_lst.php' : (file_exists(__DIR__ . '/educar_historico_escolar_cad.php') ? 'educar_historico_escolar_cad.php' : '/module/Reports/SchoolHistory');

        $html = '
        <style>
            #menu_dinamico,
            .menu_dinamico,
            #menu-horizontal,
            .menu-horizontal,
            #tr_menu_dinamico,
            table[id*="menu_dinamico"],
            #menu_lateral_superior {
                display: none !important;
                height: 0px !important;
                margin: 0px !important;
                padding: 0px !important;
            }

            .ieducar-dashboard-content {
                margin-top: -24px !important;
                padding: 0px 28px 30px 28px !important;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                clear: both;
            }
            .ieducar-breadcrumb {
                display: flex;
                align-items: center;
                gap: 6px;
                color: #1b4c6b;
                font-size: 13.5px;
                font-weight: 600;
                margin-bottom: 14px !important;
                padding-top: 4px;
            }
            .ieducar-breadcrumb svg {
                fill: #1b4c6b;
                width: 15px;
                height: 15px;
            }
            .ieducar-section-title {
                color: #1b4c6b;
                font-size: 19px;
                font-weight: 700;
                margin: 0 0 20px 0 !important;
                letter-spacing: -0.2px;
            }
            .ieducar-cards-row {
                display: flex;
                flex-wrap: wrap;
                gap: 22px;
                align-items: stretch;
            }
            .ieducar-quick-card {
                background: #ffffff;
                border-radius: 6px;
                width: 165px;
                min-height: 160px;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                padding: 22px 14px 18px 14px;
                text-align: center;
                text-decoration: none !important;
                box-shadow: 0 3px 14px rgba(0, 0, 0, 0.07);
                border: 1px solid rgba(0, 0, 0, 0.04);
                transition: transform 0.2s ease, box-shadow 0.2s ease;
                box-sizing: border-box;
                cursor: pointer;
            }
            .ieducar-quick-card:hover {
                transform: translateY(-4px);
                box-shadow: 0 8px 24px rgba(0, 98, 255, 0.16);
            }
            .ieducar-icon-circle {
                width: 66px;
                height: 66px;
                border-radius: 50%;
                background: #0062ff;
                display: flex;
                align-items: center;
                justify-content: center;
                margin-bottom: 14px;
                box-shadow: 0 4px 12px rgba(0, 98, 255, 0.28);
                transition: transform 0.2s ease;
            }
            .ieducar-quick-card:hover .ieducar-icon-circle {
                transform: scale(1.05);
            }
            .ieducar-card-title {
                color: #2b425b;
                font-size: 13.5px;
                font-weight: 600;
                line-height: 1.35;
                margin: 0;
            }
        </style>

        <div class="ieducar-dashboard-content">
            <!-- Breadcrumb -->
            <div class="ieducar-breadcrumb">
                <svg viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>
                <span>Início</span>
            </div>

            <!-- Título da Seção -->
            <h2 class="ieducar-section-title">Acesso rápido</h2>

            <!-- Cards de Acesso Rápido -->
            <div class="ieducar-cards-row">
                <!-- 1. Cadastro de alunos -->
                <a href="' . $urlAlunos . '" class="ieducar-quick-card">
                    <div class="ieducar-icon-circle">
                        <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M4 4v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2z"></path>
                            <line x1="2" y1="6" x2="4" y2="6"></line>
                            <line x1="2" y1="12" x2="4" y2="12"></line>
                            <line x1="2" y1="18" x2="4" y2="18"></line>
                            <circle cx="12" cy="10" r="3" fill="#ffffff"></circle>
                            <path d="M8 17a4 4 0 0 1 8 0" fill="#ffffff"></path>
                        </svg>
                    </div>
                    <span class="ieducar-card-title">Cadastro de alunos</span>
                </a>

                <!-- 2. Cadastro de Servidores -->
                <a href="' . $urlServidores . '" class="ieducar-quick-card">
                    <div class="ieducar-icon-circle">
                        <svg width="34" height="34" viewBox="0 0 24 24" fill="#ffffff">
                            <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                        </svg>
                    </div>
                    <span class="ieducar-card-title">Cadastro de<br>Servidores</span>
                </a>

                <!-- 3. Relatório de alunos por turma -->
                <a href="' . $urlRelatorioAlunos . '" class="ieducar-quick-card">
                    <div class="ieducar-icon-circle">
                        <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                            <polyline points="14 2 14 8 20 8"></polyline>
                            <rect x="8" y="12" width="8" height="6" rx="1" fill="#ffffff"></rect>
                        </svg>
                    </div>
                    <span class="ieducar-card-title">Relatório de alunos<br>por turma</span>
                </a>

                <!-- 4. Boletim escolar -->
                <a href="' . $urlBoletim . '" class="ieducar-quick-card">
                    <div class="ieducar-icon-circle">
                        <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">
                            <line x1="9" y1="6" x2="20" y2="6"></line>
                            <line x1="9" y1="12" x2="20" y2="12"></line>
                            <line x1="9" y1="18" x2="20" y2="18"></line>
                            <circle cx="4" cy="6" r="1.5" fill="#ffffff"></circle>
                            <circle cx="4" cy="12" r="1.5" fill="#ffffff"></circle>
                            <circle cx="4" cy="18" r="1.5" fill="#ffffff"></circle>
                        </svg>
                    </div>
                    <span class="ieducar-card-title">Boletim escolar</span>
                </a>

                <!-- 5. Histórico escolar -->
                <a href="' . $urlHistorico . '" class="ieducar-quick-card">
                    <div class="ieducar-icon-circle">
                        <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"></path>
                            <polyline points="3 3 3 8 8 8"></polyline>
                            <polyline points="12 7 12 12 15 15"></polyline>
                        </svg>
                    </div>
                    <span class="ieducar-card-title">Histórico escolar</span>
                </a>
            </div>
        </div>';

        return $html;
    }

    public function Formular()
    {
        $this->title = 'Início';
        $this->processoAp = 0;
    }
};
EOF

# 3. Limpar o educar_index.php de resquícios de calendário
echo -e "${BLUE}Limpando ${INTRANET_DIR}/educar_index.php...${NC}"
cp -n "${INTRANET_DIR}/educar_index.php" "${INTRANET_DIR}/educar_index.php.bkp" 2>/dev/null || true
cat <<'EOF' > "${INTRANET_DIR}/educar_index.php"
<?php

use Illuminate\Support\Facades\Auth;

return new class {
    public function RenderHTML()
    {
        return '';
    }

    public function Formular()
    {
        $this->title = 'Escola';
        $this->processoAp = 55;
    }
};
EOF

# 4. Ajustar rotas do Laravel (routes/web.php e WebController.php) para manter fixo no index.php
echo -e "${BLUE}Ajustando rotas de redirecionamento no Laravel...${NC}"
ROUTES_FILE="${IEDUCAR_DIR}/routes/web.php"
if [[ -f "$ROUTES_FILE" ]]; then
    cp -n "$ROUTES_FILE" "${ROUTES_FILE}.bkp" 2>/dev/null || true
    php -r "
    \$file = '${ROUTES_FILE}';
    \$content = file_get_contents(\$file);
    \$content = preg_replace('/Route::redirect\(\x27intranet\/index\.php\x27,\s*\x27\/web\x27\)\s*->name\(\x27home\x27\);/m', '// redirect desativado', \$content);
    \$content = str_replace(\"Route::redirect('/', '/web');\", \"Route::redirect('/', '/intranet/index.php')->name('home');\", \$content);
    file_put_contents(\$file, \$content);
    " 2>/dev/null || true
fi

WEB_CONTROLLER="${IEDUCAR_DIR}/app/Http/Controllers/WebController.php"
if [[ -f "$WEB_CONTROLLER" ]]; then
    cp -n "$WEB_CONTROLLER" "${WEB_CONTROLLER}.bkp" 2>/dev/null || true
    sed -i "s|redirect('intranet/educar_index.php')|redirect('intranet/index.php')|g" "$WEB_CONTROLLER" || true
fi

# 5. Ajustar permissões
chown -R "${WEB_USER}:${WEB_GROUP}" "${INTRANET_DIR}/index.php" "${INTRANET_DIR}/educar_index.php" 2>/dev/null || true

# 6. Limpar caches do Laravel
echo -e "${BLUE}Limpando caches do Laravel...${NC}"
if command -v php &>/dev/null && [[ -f "${IEDUCAR_DIR}/artisan" ]]; then
    php "${IEDUCAR_DIR}/artisan" route:clear >/dev/null 2>&1 || true
    php "${IEDUCAR_DIR}/artisan" config:clear >/dev/null 2>&1 || true
    php "${IEDUCAR_DIR}/artisan" cache:clear >/dev/null 2>&1 || true
fi

# 7. Recarregar servidor web se ativo
systemctl reload nginx >/dev/null 2>&1 || systemctl reload apache2 >/dev/null 2>&1 || systemctl reload httpd >/dev/null 2>&1 || true

echo -e "${GREEN}✓ Painel de Atalhos Rápidos configurado com sucesso!${NC}"
