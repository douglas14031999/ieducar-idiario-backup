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

# 1. Localizar o diretório do i-Educar
IEDUCAR_DIR=""
for dir in /var/www/ieducar /var/www/i-educar /var/www/html/ieducar; do
    if [[ -d "$dir/ieducar/intranet" ]]; then
        IEDUCAR_DIR="$dir"
        break
    fi
done

if [[ -z "$IEDUCAR_DIR" ]]; then
    echo -e "${RED}[ERRO] Diretório do i-Educar não encontrado automaticamente.${NC}"
    echo "Verifique se a aplicação está instalada em /var/www/ieducar."
    exit 1
fi

echo -e "${GREEN}i-Educar localizado em: ${IEDUCAR_DIR}${NC}"

# Detectar proprietário web
WEB_USER="www-data"
if ! id -u "$WEB_USER" &>/dev/null; then
    WEB_USER="nginx"
    if ! id -u "$WEB_USER" &>/dev/null; then
        WEB_USER="root"
    fi
fi

# 2. Configurar a página /intranet/index.php com os Atalhos Rápidos
echo -e "${BLUE}Configurando /intranet/index.php...${NC}"
cp -n "${IEDUCAR_DIR}/ieducar/intranet/index.php" "${IEDUCAR_DIR}/ieducar/intranet/index.php.bkp" 2>/dev/null || true

cat <<'EOF' > "${IEDUCAR_DIR}/ieducar/intranet/index.php"
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
echo -e "${BLUE}Limpando educar_index.php...${NC}"
cat <<'EOF' > "${IEDUCAR_DIR}/ieducar/intranet/educar_index.php"
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
if [[ -f "${IEDUCAR_DIR}/routes/web.php" ]]; then
    cp -n "${IEDUCAR_DIR}/routes/web.php" "${IEDUCAR_DIR}/routes/web.php.bkp" 2>/dev/null || true
    php -r "
    \$file = '${IEDUCAR_DIR}/routes/web.php';
    \$content = file_get_contents(\$file);
    \$content = preg_replace('/Route::redirect\(\x27intranet\/index\.php\x27,\s*\x27\/web\x27\)\s*->name\(\x27home\x27\);/m', '// redirect desativado', \$content);
    \$content = str_replace(\"Route::redirect('/', '/web');\", \"Route::redirect('/', '/intranet/index.php')->name('home');\", \$content);
    file_put_contents(\$file, \$content);
    " 2>/dev/null || true
fi

if [[ -f "${IEDUCAR_DIR}/app/Http/Controllers/WebController.php" ]]; then
    cp -n "${IEDUCAR_DIR}/app/Http/Controllers/WebController.php" "${IEDUCAR_DIR}/app/Http/Controllers/WebController.php.bkp" 2>/dev/null || true
    sed -i "s|redirect('intranet/educar_index.php')|redirect('intranet/index.php')|g" "${IEDUCAR_DIR}/app/Http/Controllers/WebController.php" || true
fi

# 5. Ajustar permissões
chown -R "${WEB_USER}:${WEB_USER}" "${IEDUCAR_DIR}/ieducar/intranet/index.php" "${IEDUCAR_DIR}/ieducar/intranet/educar_index.php" 2>/dev/null || true

# 6. Limpar caches do Laravel
echo -e "${BLUE}Limpando caches do Laravel...${NC}"
if command -v php &>/dev/null && [[ -f "${IEDUCAR_DIR}/artisan" ]]; then
    php "${IEDUCAR_DIR}/artisan" route:clear >/dev/null 2>&1 || true
    php "${IEDUCAR_DIR}/artisan" config:clear >/dev/null 2>&1 || true
    php "${IEDUCAR_DIR}/artisan" cache:clear >/dev/null 2>&1 || true
fi

echo -e "${GREEN}✓ Painel de Atalhos Rápidos configurado com sucesso!${NC}"
