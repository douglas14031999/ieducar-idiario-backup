#!/usr/bin/env bash
# ==============================================================================
# Script: setup-login-theme.sh
# Objetivo: Aplicar o design moderno Glassmorphism (Sistema Canoa 2026 / Lagoa da Canoa)
#           em TODAS as telas públicas do i-Educar:
#           - Login (auth/login.blade.php)
#           - Recuperação / Redefinição de Senha (auth/passwords/email.blade.php)
#           - Redefinição de Senha com Token (auth/passwords/reset.blade.php)
#           - Troca Obrigatória de Senha (password/change.blade.php)
#           - Layout Base Público (layout/public.blade.php)
#           Preservando 100% dos dados dinâmicos, rotas, tokens, GTM e reCAPTCHA.
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}   🎨  TEMA MODERNO DE LOGIN & SENHAS - I-EDUCAR (CANOA 2026)         ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "Aplicando design com Glassmorphism, ondas orgânicas, paleta oficial"
echo -e "em todas as telas públicas (Login, Redefinição e Troca de Senha)."
echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"

# 1. Checagem de privilégios de root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERRO] Este utilitário precisa ser executado como root (sudo).${NC}" >&2
    exit 1
fi

# 2. Localização do Diretório do i-Educar
detect_ieducar_dir() {
    local candidate_paths=(
        "/var/www/ieducar"
        "/var/www/i-educar"
        "/var/www/html/ieducar"
        "/var/www/html"
        "$(pwd)"
    )

    for p in "${candidate_paths[@]}"; do
        if [[ -d "$p/resources/views/auth" && -f "$p/artisan" ]]; then
            echo "$p"
            return 0
        fi
    done

    # Busca no disco se não encontrado nos caminhos padrão
    local found_file
    found_file=$(find /var/www /srv /opt -maxdepth 4 -type f -path "*/resources/views/auth/login.blade.php" 2>/dev/null | head -n 1 || true)
    if [[ -n "$found_file" ]]; then
        dirname "$(dirname "$(dirname "$(dirname "$found_file")")")"
        return 0
    fi

    return 1
}

IEDUCAR_DIR=$(detect_ieducar_dir || true)

if [[ -z "$IEDUCAR_DIR" || ! -d "$IEDUCAR_DIR" ]]; then
    echo -e "${RED}[ERRO] Instalação do i-Educar não foi localizada no servidor.${NC}" >&2
    exit 1
fi

echo -e "${BLUE}[+] Diretório base do i-Educar detectado:${NC} ${IEDUCAR_DIR}"
cd "$IEDUCAR_DIR"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
PUBLIC_LAYOUT="${IEDUCAR_DIR}/resources/views/layout/public.blade.php"
LOGIN_VIEW="${IEDUCAR_DIR}/resources/views/auth/login.blade.php"
EMAIL_PASS_VIEW="${IEDUCAR_DIR}/resources/views/auth/passwords/email.blade.php"
RESET_PASS_VIEW="${IEDUCAR_DIR}/resources/views/auth/passwords/reset.blade.php"
CHANGE_PASS_VIEW="${IEDUCAR_DIR}/resources/views/password/change.blade.php"

# 3. Criar backup dos arquivos originais
echo -e "\n${YELLOW}[1/6] Criando backup de segurança das views atuais...${NC}"
for f in "$PUBLIC_LAYOUT" "$LOGIN_VIEW" "$EMAIL_PASS_VIEW" "$RESET_PASS_VIEW" "$CHANGE_PASS_VIEW"; do
    if [[ -f "$f" ]]; then
        cp "$f" "${f}.bak.${TIMESTAMP}"
        echo -e "      Backup salvo: ${CYAN}${f}.bak.${TIMESTAMP}${NC}"
    fi
done

# 4. Escrever o novo layout base (layout.public)
echo -e "\n${YELLOW}[2/6] Escrevendo layout público moderno (layout.public.blade.php)...${NC}"
mkdir -p "$(dirname "$PUBLIC_LAYOUT")"

cat << 'EOF' > "$PUBLIC_LAYOUT"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="shortcut icon" href="{{ url('favicon.ico') }}">
    <title>@if(isset($title)) {!! html_entity_decode($title) !!} - @endif {{ html_entity_decode(config('legacy.app.entity.name', 'i-Educar')) }} - i-Educar</title>

    <!-- Tailwind CSS CDN v3 com plugins -->
    <script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
    
    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=Public+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">

    <!-- Tailwind Configuration -->
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        canoa: {
                            green: '#135e46',
                            greenHover: '#0e4936',
                            orange: '#f37023',
                            pink: '#e52565',
                            softBg: '#f7faf8'
                        }
                    },
                    fontFamily: {
                        sans: ['"Plus Jakarta Sans"', '"Public Sans"', 'system-ui', 'sans-serif'],
                    }
                }
            }
        }
    </script>

    <style>
        .glass-card {
            background: rgba(255, 255, 255, 0.82);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.85);
            box-shadow: 0 20px 45px -10px rgba(19, 94, 70, 0.12),
                        0 8px 20px -6px rgba(0, 0, 0, 0.05),
                        inset 0 1px 0 0 rgba(255, 255, 255, 0.95);
        }
        .input-focus-ring:focus-within {
            border-color: #135e46;
            box-shadow: 0 0 0 3px rgba(19, 94, 70, 0.12);
        }
        .btn-glow {
            box-shadow: 0 4px 18px rgba(19, 94, 70, 0.32);
        }
        .btn-glow:hover {
            box-shadow: 0 6px 24px rgba(19, 94, 70, 0.42);
        }

        /* Estilização de contingência para qualquer elemento legado dentro de #login-form */
        #login-form h2 {
            font-size: 1.25rem;
            font-weight: 700;
            text-align: center;
            color: #0f172a;
            margin-bottom: 0.5rem;
        }
        #login-form p {
            font-size: 0.75rem;
            color: #64748b;
            text-align: center;
            margin-bottom: 1rem;
        }
        #login-form label {
            display: block;
            font-size: 0.75rem;
            font-weight: 600;
            color: #334155;
            margin-bottom: 0.25rem;
            margin-top: 0.75rem;
        }
        #login-form input[type="text"],
        #login-form input[type="password"] {
            display: block;
            width: 100%;
            padding: 0.625rem 0.875rem;
            font-size: 0.75rem;
            color: #0f172a;
            background-color: rgba(255, 255, 255, 0.95);
            border: 1px solid rgba(203, 213, 225, 0.8);
            border-radius: 0.75rem;
            outline: none;
            box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
            box-sizing: border-box;
        }
        #login-form input[type="text"]:focus,
        #login-form input[type="password"]:focus {
            border-color: #135e46;
            box-shadow: 0 0 0 3px rgba(19, 94, 70, 0.12);
        }
        #login-form button.submit,
        #login-form button[type="submit"] {
            width: 100%;
            margin-top: 1rem;
            padding: 0.75rem 1rem;
            color: #ffffff;
            font-size: 0.75rem;
            font-weight: 600;
            letter-spacing: 0.025em;
            border-radius: 0.75rem;
            background-color: #135e46;
            border: none;
            cursor: pointer;
            box-shadow: 0 4px 18px rgba(19, 94, 70, 0.32);
            transition: all 0.15s ease-in-out;
        }
        #login-form button.submit:hover,
        #login-form button[type="submit"]:hover {
            background-color: #0e4936;
            box-shadow: 0 6px 24px rgba(19, 94, 70, 0.42);
        }
        #login-form .remember {
            margin-top: 0.75rem;
            text-align: center;
            font-size: 0.75rem;
        }
        #login-form .remember a {
            color: #135e46;
            font-weight: 600;
            font-size: 0.75rem;
            text-decoration: none;
        }
        #login-form .remember a:hover {
            text-decoration: underline;
            color: #0e4936;
        }
    </style>

    @if(config('legacy.gtm'))
    <!-- Google Tag Manager -->
    <script>
        dataLayer = [{
            'slug': '{{ $config['app']['database']['dbname'] ?? '' }}',
            'user_id': 0
        }];

        (function (w, d, s, l, i) {
            w[l] = w[l] || [];
            w[l].push({'gtm.start': new Date().getTime(), event: 'gtm.js'});
            var f = d.getElementsByTagName(s)[0], j = d.createElement(s), dl = l != 'dataLayer' ? '&l=' + l : '';
            j.async = true;
            j.src = 'https://www.googletagmanager.com/gtm.js?id=' + i + dl;
            f.parentNode.insertBefore(j, f);
        })(window, document, 'script', 'dataLayer', '{{ config('legacy.gtm') }}');
    </script>
    <!-- End Google Tag Manager -->
    @endif

    @if($errors->count() && str_contains($errors->first(), 'errou a senha muitas vezes' ))
    <script>
        window.onload = function() {
            var submitBtn = document.getElementById("form-login-submit");
            if (submitBtn) {
                submitBtn.disabled = true;
                setTimeout(function () {
                    submitBtn.disabled = false;
                }, 60000);
            }
        }
    </script>
    @endif
</head>

<body class="min-h-screen w-screen overflow-x-hidden bg-[#f7faf8] font-sans text-slate-800 flex flex-col justify-between selection:bg-[#135e46] selection:text-white relative select-none">

@if(config('legacy.gtm'))
<!-- Google Tag Manager (noscript) -->
<noscript>
    <iframe src="https://www.googletagmanager.com/ns.html?id={{ config('legacy.gtm') }}" height="0" width="0" style="display:none;visibility:hidden" title="Google Tag Manager"></iframe>
</noscript>
<!-- End Google Tag Manager (noscript) -->
@endif

<!-- BACKGROUND: Dynamic multi-layered organic waves & soft gradients using exact Lagoa da Canoa palette -->
<div class="fixed inset-0 pointer-events-none overflow-hidden z-0">
    <div class="absolute inset-0 bg-gradient-to-tr from-[#f0f6f3] via-[#f7faf8] to-[#fff6f0]"></div>
    <!-- Organic glowing color nodes -->
    <div class="absolute -top-36 -right-24 w-[520px] h-[520px] bg-[#f37023]/14 rounded-full blur-3xl pointer-events-none"></div>
    <div class="absolute -bottom-32 -left-28 w-[580px] h-[580px] bg-[#135e46]/16 rounded-full blur-3xl pointer-events-none"></div>
    <div class="absolute top-1/4 -left-36 w-96 h-96 bg-[#e52565]/10 rounded-full blur-3xl pointer-events-none"></div>
    <div class="absolute bottom-1/4 right-0 w-80 h-80 bg-[#135e46]/10 rounded-full blur-3xl pointer-events-none"></div>
    <!-- Fluid waves layer -->
    <svg class="absolute bottom-0 left-0 right-0 w-full h-[48vh] min-h-[340px] pointer-events-none transform-gpu" fill="none" preserveAspectRatio="none" viewBox="0 0 1440 380">
        <path d="M0,192L48,197.3C96,203,192,213,288,202.7C384,192,480,160,576,154.7C672,149,768,171,864,192C960,213,1056,235,1152,224C1248,213,1344,171,1392,149.3L1440,128L1440,380L1392,380C1344,380,1248,380,1152,380C1056,380,960,380,864,380C768,380,672,380,576,380C480,380,384,380,288,380C192,380,96,380,48,380L0,380Z" fill="#135e46" fill-opacity="0.065"></path>
        <path d="M0,240L60,229.3C120,219,240,197,360,197.3C480,197,600,219,720,229.3C840,240,960,240,1080,224C1200,208,1320,176,1380,160L1440,144L1440,380L1380,380C1320,380,1200,380,1080,380C960,380,840,380,720,380C600,380,480,380,360,380C240,380,120,380,60,380L0,380Z" fill="#e52565" fill-opacity="0.04"></path>
        <path d="M0,295L60,284C120,273,240,251,360,253C480,255,600,281,720,275C840,269,960,231,1080,225C1200,219,1320,245,1380,258L1440,270L1440,380L1380,380C1320,380,1200,380,1080,380C960,380,840,380,720,380C600,380,480,380,360,380C240,380,120,380,60,380L0,380Z" fill="#f37023" fill-opacity="0.055"></path>
    </svg>
</div>

<!-- MAIN CONTENT: Centered 440px Glassmorphism Card -->
<main class="flex-1 flex items-center justify-center px-4 py-8 relative z-10" data-purpose="authentication-wrapper">
    <div class="w-full max-w-[440px] glass-card rounded-3xl p-7 sm:p-8 transition-all duration-300">
        <!-- Logo Header -->
        <div class="text-center mb-5">
            <div class="inline-flex items-center justify-center mb-3">
                <div class="p-2 rounded-2xl bg-white/95 shadow-md shadow-slate-200/60 border border-slate-100/90 transition-transform duration-200 hover:scale-105">
                    <img alt="{{ config('legacy.config.ieducar_entity_name') ?? 'Prefeitura de Lagoa da Canoa' }}" 
                         class="w-16 h-16 object-contain" 
                         src="{{ config('legacy.config.ieducar_image') ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuCtHMCsnOnk4y_ENFnmgg-3jxDOy5007ftK0-mU0JM613vW_xkr6j_aIFJcb0syav3LMuaDhcgqa65z8851hlLfQcqPIB3wO5ye5MCtROuZeU3PvvdZNBPdv7EWzWpYUYM5CieFIDJzVe4hXel1d5jqfzLA6-g-k1GFHWm-WHPvZxb6au10FNLl0kIwHphWqiVRjT-Rs4ArAJPZetXw3BI8ffHa6jOs603AI7mr3T0GWu9b0PcjCisNTlAKkfwBEL0bI6M' }}">
                </div>
            </div>
            @if(config('legacy.config.ieducar_entity_name'))
                <p class="text-[11px] font-semibold text-slate-500 uppercase tracking-wider mb-0.5">
                    {{ config('legacy.config.ieducar_entity_name') }}
                </p>
            @endif
        </div>

        @if (session('status'))
            <div class="mb-4 p-3 rounded-xl bg-emerald-50/90 border border-emerald-200 text-emerald-800 text-xs font-medium flex items-center gap-2">
                <svg class="w-4 h-4 text-emerald-600 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                <span>{{ session('status') }}</span>
            </div>
        @endif

        @if($errors->count())
            <div class="mb-4 p-3 rounded-xl bg-rose-50/90 border border-rose-200 text-rose-800 text-xs font-medium flex items-center gap-2">
                <svg class="w-4 h-4 text-rose-600 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                <span>{{ $errors->first() }}</span>
            </div>
        @endif

        <div id="login-form">
            @yield('content')
        </div>
    </div>
</main>

<!-- FOOTER: Discreet legal and support links -->
<footer class="w-full px-6 py-3.5 flex flex-col sm:flex-row items-center justify-between text-[11px] text-slate-500 z-10 shrink-0 gap-2">
    <div>
        © 2026 Secretaria Municipal de Educação de Lagoa da Canoa • Alagoas
    </div>
    <div class="flex items-center gap-3">
        @if(config('legacy.config.ieducar_login_footer'))
            <span>{!! config('legacy.config.ieducar_login_footer') !!}</span>
        @endif
        @if(config('legacy.config.ieducar_external_footer'))
            <span>{!! config('legacy.config.ieducar_external_footer') !!}</span>
        @endif
    </div>
</footer>

@yield('scripts')

</body>
</html>
EOF

echo -e "${GREEN}✓ Layout base (public.blade.php) atualizado com sucesso!${NC}"

# 5. Escrever a tela de login (auth/login.blade.php)
echo -e "\n${YELLOW}[3/6] Escrevendo formulário de login (auth/login.blade.php)...${NC}"
mkdir -p "$(dirname "$LOGIN_VIEW")"

cat << 'EOF' > "$LOGIN_VIEW"
@extends('layout.public')

@section('content')
    <div class="text-center mb-5">
        <h1 class="text-xl font-bold tracking-tight text-slate-900 leading-snug">
            Acesse sua conta
        </h1>
        @if(config('legacy.config.url_cadastro_usuario'))
            <div class="text-xs text-slate-500 mt-1">
                Não possui uma conta? <a target="_blank" href="{{ config('legacy.config.url_cadastro_usuario') }}" rel="noopener" class="font-semibold text-[#135e46] hover:text-[#0e4936] hover:underline">Crie sua conta agora</a>.
            </div>
        @endif
    </div>

    <form action="{{ Asset::get('login') }}" method="post" id="form-login" class="space-y-4">
        <!-- Field 1: Matrícula -->
        <div data-purpose="matricula-input-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="login">
                Matrícula institucional
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-3.5 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none font-normal" 
                       id="login" 
                       name="login" 
                       value="{{ old('login') }}" 
                       placeholder="Ex: admin" 
                       required 
                       type="text" 
                       autofocus>
            </div>
        </div>

        <!-- Field 2: Senha -->
        <div data-purpose="password-input-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="password">
                Senha de acesso
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-10 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none" 
                       id="password" 
                       name="password" 
                       placeholder="••••••••" 
                       required 
                       type="password">
                <button aria-label="Alternar visibilidade da senha" 
                        class="absolute inset-y-0 right-0 pr-3 flex items-center text-slate-400 hover:text-slate-600 transition focus:outline-none" 
                        id="togglePasswordBtn" 
                        type="button">
                    <svg class="h-4 w-4" fill="none" id="eyeIcon" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                        <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                    <svg class="h-4 w-4 hidden" fill="none" id="eyeOffIcon" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </button>
            </div>
        </div>

        <!-- Row: Esqueceu a senha? -->
        <div class="flex items-center justify-end pt-0.5 text-xs">
            <a class="text-[11px] font-semibold text-[#135e46] hover:text-[#0e4936] hover:underline transition" 
               href="{{ route('password.request') }}">
                Esqueceu a senha?
            </a>
        </div>

        <!-- Primary CTA Button -->
        <button id="form-login-submit" 
                class="w-full mt-2 py-3 px-4 text-white font-semibold text-xs tracking-wide rounded-xl bg-[#135e46] hover:bg-[#0e4936] btn-glow transition duration-150 flex items-center justify-center gap-2 group focus:outline-none focus:ring-2 focus:ring-[#135e46] focus:ring-offset-2" 
                type="submit">
            <span>Acessar Plataforma</span>
            <svg class="w-3.5 h-3.5 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M14 5l7 7m0 0l-7 7m7-7H3" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2"></path>
            </svg>
        </button>

        @if(config('services.passport.enabled'))
        <div id="sso" class="mt-4 pt-4 border-t border-slate-200/80 relative text-center">
            <span class="absolute -top-2.5 px-3 bg-white/90 text-slate-400 text-[10px] font-semibold left-1/2 -translate-x-1/2 uppercase tracking-wider">ou</span>
            <a href="{{ route('socialite.redirect') }}?intended={{ session()->get('url.intended') }}" 
               class="w-full py-2.5 px-4 text-white text-xs font-semibold rounded-xl bg-[#135e46] hover:bg-[#0e4936] transition flex items-center justify-center gap-2">
                {{ config('services.passport.label') }}
            </a>
        </div>
        @endif
    </form>
@endsection

@section('scripts')
    <!-- Script para alternar visibilidade da senha -->
    <script data-purpose="toggle-password-visibility">
        document.addEventListener('DOMContentLoaded', function () {
            var togglePasswordBtn = document.getElementById('togglePasswordBtn');
            var passwordInput = document.getElementById('password');
            var eyeIcon = document.getElementById('eyeIcon');
            var eyeOffIcon = document.getElementById('eyeOffIcon');

            if (togglePasswordBtn && passwordInput) {
                togglePasswordBtn.addEventListener('click', function () {
                    var isPassword = passwordInput.getAttribute('type') === 'password';
                    passwordInput.setAttribute('type', isPassword ? 'text' : 'password');
                    
                    if (isPassword) {
                        eyeIcon.classList.add('hidden');
                        eyeOffIcon.classList.remove('hidden');
                    } else {
                        eyeIcon.classList.remove('hidden');
                        eyeOffIcon.classList.add('hidden');
                    }
                });
            }
        });
    </script>

    @if (config('legacy.app.recaptcha_v3.public_key') && config('legacy.app.recaptcha_v3.private_key'))
        <script src="https://www.google.com/recaptcha/api.js?render={{config('legacy.app.recaptcha_v3.public_key')}}"></script>
        <script src="{{ Asset::get("/intranet/scripts/jquery/jquery-1.8.3.min.js") }}"></script>

        <script>
            var grecaptchaKey = "{{config('legacy.app.recaptcha_v3.public_key')}}";
            var form = $('#form-login');

            grecaptcha.ready(function() {
                form.submit(function(e) {
                    e.preventDefault();
                    grecaptcha.execute(grecaptchaKey, {action: 'submit'})
                        .then(function(token) {
                            var input = document.createElement('input');
                            input.type = 'hidden';
                            input.name = 'grecaptcha';
                            input.value = token;

                            form.append(input);

                            $(this).unbind('submit').submit();
                        });
                });
            });
        </script>
    @endif
@endsection
EOF

echo -e "${GREEN}✓ View de login (login.blade.php) atualizada!${NC}"

# 6. Escrever a tela de solicitação de redefinição de senha (auth/passwords/email.blade.php)
echo -e "\n${YELLOW}[4/6] Escrevendo tela de recuperação de senha (auth/passwords/email.blade.php)...${NC}"
mkdir -p "$(dirname "$EMAIL_PASS_VIEW")"

cat << 'EOF' > "$EMAIL_PASS_VIEW"
@extends('layout.public')

@section('content')
    <div class="text-center mb-5">
        <h1 class="text-xl font-bold tracking-tight text-slate-900 leading-snug">
            Recuperação de acesso
        </h1>
        <p class="text-xs text-slate-500 mt-1">
            Informe sua matrícula institucional para prosseguir com a redefinição de senha.
        </p>
    </div>

    <form action="{{ route('password.email') }}" method="post" id="form-password-email" class="space-y-4">
        {{ csrf_field() }}

        <!-- Campo: Matrícula -->
        <div data-purpose="matricula-input-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="login">
                Matrícula institucional
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-3.5 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none font-normal" 
                       id="login" 
                       name="login" 
                       value="{{ old('login') }}" 
                       placeholder="Ex: admin" 
                       required 
                       type="text" 
                       autofocus>
            </div>
        </div>

        <!-- Botão CTA -->
        <button id="form-login-submit" 
                class="w-full mt-2 py-3 px-4 text-white font-semibold text-xs tracking-wide rounded-xl bg-[#135e46] hover:bg-[#0e4936] btn-glow transition duration-150 flex items-center justify-center gap-2 group focus:outline-none focus:ring-2 focus:ring-[#135e46] focus:ring-offset-2" 
                type="submit">
            <span>Redefinir Senha</span>
            <svg class="w-3.5 h-3.5 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M14 5l7 7m0 0l-7 7m7-7H3" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2"></path>
            </svg>
        </button>

        <!-- Link Voltar -->
        <div class="pt-2 text-center">
            <a href="{{ Asset::get('login') }}" 
               class="inline-flex items-center gap-1.5 text-xs font-semibold text-[#135e46] hover:text-[#0e4936] hover:underline transition">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path d="M10 19l-7-7m0 0l7-7m-7 7h18" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                </svg>
                Voltar para o login
            </a>
        </div>
    </form>
@endsection
EOF

echo -e "${GREEN}✓ View de recuperação de senha (passwords/email.blade.php) atualizada!${NC}"

# 7. Escrever a tela de redefinição com token (auth/passwords/reset.blade.php)
echo -e "\n${YELLOW}[5/6] Escrevendo tela de nova senha com token (auth/passwords/reset.blade.php)...${NC}"
mkdir -p "$(dirname "$RESET_PASS_VIEW")"

cat << 'EOF' > "$RESET_PASS_VIEW"
@extends('layout.public')

@section('content')
    <div class="text-center mb-5">
        <h1 class="text-xl font-bold tracking-tight text-slate-900 leading-snug">
            Criar nova senha
        </h1>
        <p class="text-xs text-slate-500 mt-1">
            Defina uma nova senha de acesso segura para a sua conta.
        </p>
    </div>

    <form action="{{ route('password.update') }}" method="post" id="form-password-reset" class="space-y-4">
        {{ csrf_field() }}
        <input type="hidden" name="token" value="{{ $token }}">

        <!-- Matrícula -->
        <div data-purpose="matricula-input-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="login">
                Matrícula institucional
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-3.5 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none font-normal" 
                       id="login" 
                       name="login" 
                       value="{{ old('login') }}" 
                       placeholder="Ex: admin" 
                       required 
                       type="text">
            </div>
        </div>

        <!-- Nova Senha -->
        <div data-purpose="password-input-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="password">
                Nova senha
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-10 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none" 
                       id="password" 
                       name="password" 
                       placeholder="••••••••" 
                       required 
                       type="password">
            </div>
        </div>

        <!-- Confirmar Senha -->
        <div data-purpose="password-confirm-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="password-confirm">
                Confirme a nova senha
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-3.5 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none" 
                       id="password-confirm" 
                       name="password_confirmation" 
                       placeholder="••••••••" 
                       required 
                       type="password">
            </div>
        </div>

        <!-- Botão CTA -->
        <button id="form-login-submit" 
                class="w-full mt-2 py-3 px-4 text-white font-semibold text-xs tracking-wide rounded-xl bg-[#135e46] hover:bg-[#0e4936] btn-glow transition duration-150 flex items-center justify-center gap-2 group focus:outline-none focus:ring-2 focus:ring-[#135e46] focus:ring-offset-2" 
                type="submit">
            <span>Salvar Nova Senha</span>
            <svg class="w-3.5 h-3.5 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M14 5l7 7m0 0l-7 7m7-7H3" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2"></path>
            </svg>
        </button>

        <!-- Link Voltar -->
        <div class="pt-2 text-center">
            <a href="{{ route('login') }}" 
               class="inline-flex items-center gap-1.5 text-xs font-semibold text-[#135e46] hover:text-[#0e4936] hover:underline transition">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path d="M10 19l-7-7m0 0l7-7m-7 7h18" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                </svg>
                Voltar para o login
            </a>
        </div>
    </form>
@endsection
EOF

echo -e "${GREEN}✓ View de redefinição com token (passwords/reset.blade.php) atualizada!${NC}"

# 8. Escrever a tela de troca obrigatória de senha (password/change.blade.php)
if [[ -d "$(dirname "$CHANGE_PASS_VIEW")" || -f "$CHANGE_PASS_VIEW" ]]; then
    mkdir -p "$(dirname "$CHANGE_PASS_VIEW")"
    cat << 'EOF' > "$CHANGE_PASS_VIEW"
@extends('layout.public')

@section('content')
    <div class="text-center mb-5">
        <h1 class="text-xl font-bold tracking-tight text-slate-900 leading-snug">
            Alteração de senha
        </h1>
        <p class="text-xs text-slate-500 mt-1">
            Para sua segurança institucional, sua senha provisória deve ser alterada.
        </p>
    </div>

    <form action="{{ route('post-change-password') }}" method="post" id="form-change-password" class="space-y-4">
        {{ csrf_field() }}

        <!-- Matrícula -->
        <div data-purpose="matricula-input-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="login">
                Matrícula institucional
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-3.5 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none font-normal" 
                       id="login" 
                       name="login" 
                       value="{{ old('login') }}" 
                       placeholder="Ex: admin" 
                       required 
                       type="text">
            </div>
        </div>

        <!-- Nova Senha -->
        <div data-purpose="password-input-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="password">
                Nova senha
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-10 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none" 
                       id="password" 
                       name="password" 
                       placeholder="••••••••" 
                       required 
                       type="password">
            </div>
        </div>

        <!-- Confirmar Senha -->
        <div data-purpose="password-confirm-group">
            <label class="block text-xs font-semibold text-slate-700 mb-1" for="password-confirm">
                Confirme a nova senha
            </label>
            <div class="relative rounded-xl border border-slate-300/80 bg-white/95 transition input-focus-ring shadow-xs">
                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
                    </svg>
                </div>
                <input class="block w-full pl-9 pr-3.5 py-2.5 text-xs text-slate-900 placeholder-slate-400 bg-transparent border-0 rounded-xl focus:ring-0 focus:outline-none" 
                       id="password-confirm" 
                       name="password_confirmation" 
                       placeholder="••••••••" 
                       required 
                       type="password">
            </div>
        </div>

        <!-- Botão CTA -->
        <button id="form-login-submit" 
                class="w-full mt-2 py-3 px-4 text-white font-semibold text-xs tracking-wide rounded-xl bg-[#135e46] hover:bg-[#0e4936] btn-glow transition duration-150 flex items-center justify-center gap-2 group focus:outline-none focus:ring-2 focus:ring-[#135e46] focus:ring-offset-2" 
                type="submit">
            <span>Atualizar Senha</span>
            <svg class="w-3.5 h-3.5 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path d="M14 5l7 7m0 0l-7 7m7-7H3" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2"></path>
            </svg>
        </button>
    </form>
@endsection
EOF
    echo -e "${GREEN}✓ View de troca obrigatória de senha (password/change.blade.php) atualizada!${NC}"
fi

# 9. Ajustar permissões e limpar cache do Blade
echo -e "\n${YELLOW}[6/6] Ajustando permissões e limpando cache do Blade...${NC}"
chown -R www-data:www-data "$PUBLIC_LAYOUT" "$LOGIN_VIEW" "$EMAIL_PASS_VIEW" "$RESET_PASS_VIEW" 2>/dev/null || true
if [[ -f "$CHANGE_PASS_VIEW" ]]; then
    chown -R www-data:www-data "$CHANGE_PASS_VIEW" 2>/dev/null || true
fi
chmod 664 "$PUBLIC_LAYOUT" "$LOGIN_VIEW" "$EMAIL_PASS_VIEW" "$RESET_PASS_VIEW" 2>/dev/null || true
if [[ -f "$CHANGE_PASS_VIEW" ]]; then
    chmod 664 "$CHANGE_PASS_VIEW" 2>/dev/null || true
fi

php artisan view:clear || true
php artisan optimize:clear 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  ✓ TEMA MODERNO APLICADO EM TODAS AS TELAS PÚBLICAS COM SUCESSO!     ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e " • Layout Base:          ${CYAN}${PUBLIC_LAYOUT}${NC}"
echo -e " • Login:                ${CYAN}${LOGIN_VIEW}${NC}"
echo -e " • Redefinição de Senha: ${CYAN}${EMAIL_PASS_VIEW}${NC}"
echo -e " • Nova Senha com Token: ${CYAN}${RESET_PASS_VIEW}${NC}"
echo -e " • Troca de Senha:       ${CYAN}${CHANGE_PASS_VIEW}${NC}"
echo -e " • Estilo:               ${GREEN}Glassmorphism + Ondas Orgânicas Canoa 2026${NC}"
echo -e " • Autenticação:         ${GREEN}100% preservada (Asset::get('login'), tokens e CSRF)${NC}"
echo -e "${GREEN}======================================================================${NC}\n"
