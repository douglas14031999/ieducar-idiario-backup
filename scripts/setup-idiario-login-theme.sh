#!/usr/bin/env bash
# ==============================================================================
# Script de Atualização da Tela de Login e Autenticação do i-Diário
# Design Oficial: Comunidade Escolar · Lagoa da Canoa
# ==============================================================================
set -e

# Cores para o terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}   Atualizador da Tela de Login / Autenticação do i-Diário      ${NC}"
echo -e "${BLUE}   Design: Lagoa da Canoa (SVG, Animações e Estilo Moderno)      ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. Localização do diretório do i-diário
POSSIBLE_PATHS=(
  "$1"
  "$ID_PATH"
  "$(pwd)"
  "$(pwd)/i-diario"
  "$(pwd)/i-diario-1.6"
  "$HOME/i-diario"
  "$HOME/i-diario-1.6"
  "/root/i-diario"
  "/root/i-diario-1.6"
  "/var/www/i-diario"
  "/var/www/i-diario-1.6"
  "/var/www/html/i-diario"
  "/home/deploy/i-diario"
  "/home/ubuntu/i-diario"
)

TARGET_DIR=""

for p in "${POSSIBLE_PATHS[@]}"; do
  if [ -n "$p" ] && [ -d "$p/app/views/layouts" ] && [ -d "$p/app/views/devise" ]; then
    TARGET_DIR="$p"
    break
  fi
done

# Se ainda não encontrou, faz uma busca rápida nos diretórios mais comuns
if [ -z "$TARGET_DIR" ]; then
  for base_search in /root /home /var/www "$(pwd)"; do
    if [ -d "$base_search" ]; then
      match=$(find "$base_search" -maxdepth 2 -type d -name "i-diario*" 2>/dev/null | head -n 1)
      if [ -n "$match" ] && [ -d "$match/app/views/layouts" ] && [ -d "$match/app/views/devise" ]; then
        TARGET_DIR="$match"
        break
      fi
    fi
  done
fi

if [ -z "$TARGET_DIR" ]; then
  echo -e "${RED}[AVISO] Não foi possível detectar automaticamente a pasta do i-Diário nos locais padrão.${NC}"
  USER_INPUT_PATH=""
  if [ -t 0 ]; then
    echo -e "${YELLOW}Por favor, informe o caminho do projeto:${NC}"
    read -r -p "Caminho (ex: /var/www/i-diario): " USER_INPUT_PATH
  elif [ -e /dev/tty ]; then
    echo -e "${YELLOW}Por favor, informe o caminho do projeto:${NC}"
    read -r -p "Caminho (ex: /var/www/i-diario): " USER_INPUT_PATH < /dev/tty
  fi

  if [ -n "$USER_INPUT_PATH" ] && [ -d "$USER_INPUT_PATH/app/views/layouts" ]; then
    TARGET_DIR="$USER_INPUT_PATH"
  else
    echo -e "${RED}[FALHA] Diretório inválido ou não informado.${NC}"
    echo -e "${YELLOW}Dica: Execute passando o caminho explicitamente:${NC}"
    echo -e "  bash deploy_login_vps.sh /caminho/do/i-diario"
    echo -e "  ou via curl:"
    echo -e "  curl -sSL <URL> | bash -s -- /caminho/do/i-diario"
    exit 1
  fi
fi

echo -e "${GREEN}✔ Projeto i-Diário localizado em:${NC} $TARGET_DIR"

# 2. Criar backup dos arquivos originais
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$TARGET_DIR/app/views_backup_login_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}ℹ Criando backup em:${NC} $BACKUP_DIR"

backup_file() {
  local rel_path="$1"
  if [ -f "$TARGET_DIR/$rel_path" ]; then
    mkdir -p "$(dirname "$BACKUP_DIR/$rel_path")"
    cp "$TARGET_DIR/$rel_path" "$BACKUP_DIR/$rel_path"
    echo -e "  Backup: $rel_path -> OK"
  fi
}

backup_file "app/views/layouts/devise.html.erb"
backup_file "app/views/layouts/_not_logged_header.html.erb"
backup_file "app/views/layouts/registration.html.erb"
backup_file "app/views/registrations/new.html.erb"
backup_file "app/views/devise/sessions/new.html.erb"
backup_file "app/views/devise/passwords/new.html.erb"
backup_file "app/views/devise/unlocks/new.html.erb"
backup_file "app/views/devise/registrations/new.html.erb"
backup_file "app/views/devise/shared/_links.erb"

echo -e "${GREEN}✔ Backup concluído com sucesso.${NC}"

# 3. Escrever os novos arquivos
echo -e "${BLUE}ℹ Instalando novas telas e layout...${NC}"

# --- A) Layout Devise ---
cat << 'EOF' > "$TARGET_DIR/app/views/layouts/devise.html.erb"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title><%= content_for?(:title) ? yield(:title) : "Acessar | Comunidade escolar de Lagoa da Canoa" %></title>
  <%= csrf_meta_tags %>
  <% dynamic_logo = (logo_url.presence rescue nil) %>
  <% if dynamic_logo.present? %>
    <link rel="icon" href="<%= dynamic_logo %>">
    <link rel="apple-touch-icon" href="<%= dynamic_logo %>">
  <% else %>
    <link rel="icon" href="/assets/favicon.ico" type="image/x-icon">
  <% end %>
  <link rel="shortcut icon" href="<%= dynamic_logo.presence || '/assets/favicon.ico' %>" type="image/x-icon">
  <%= render 'layouts/google_tag_manager_head' if lookup_context.exists?('layouts/_google_tag_manager_head') %>

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&family=Bitter:wght@700&display=swap" rel="stylesheet">

  <style>
    :root {
      --sky: #d9edf0;
      --hill-far: #7bbf9f;
      --hill-near: #3f9a74;
      --water: #12594a;
      --wave: #4a9884;
      --ink: #0f2e28;
      --muted: #4a625b;
      --bg: #f6f9f7;
      --sheet: #fff;
      --field: #8fa69d;
      --line: #cfdcd6;
      --link: #12594a;
      --primary: #12594a;
      --ring: rgba(18, 89, 74, .35);
      --note: #e5f1ec;
      --err: #b3261e;
      box-sizing: border-box;
      padding-top: env(safe-area-inset-top, 0px);
      padding-bottom: env(safe-area-inset-bottom, 0px);
    }
    @media (prefers-color-scheme: dark) {
      :root:not([data-theme="light"]) {
        --sky: #0f2630;
        --hill-far: #1b5a49;
        --hill-near: #134537;
        --water: #072a23;
        --wave: #1b5547;
        --ink: #e4f0ec;
        --muted: #a1b9b1;
        --bg: #0b1613;
        --sheet: #162824;
        --field: #42605a;
        --line: #34504a;
        --link: #6fd3ae;
        --primary: #1f7a63;
        --ring: rgba(111, 211, 174, .4);
        --note: #1c3a33;
        --err: #ff9a92;
      }
    }
    :root[data-theme="dark"] {
      --sky: #0f2630;
      --hill-far: #1b5a49;
      --hill-near: #134537;
      --water: #072a23;
      --wave: #1b5547;
      --ink: #e4f0ec;
      --muted: #a1b9b1;
      --bg: #0b1613;
      --sheet: #162824;
      --field: #42605a;
      --line: #34504a;
      --link: #6fd3ae;
      --primary: #1f7a63;
      --ring: rgba(111, 211, 174, .4);
      --note: #1c3a33;
      --err: #ff9a92;
    }
    html {
      scroll-padding-top: env(safe-area-inset-top, 0px);
    }
    *, *::before, *::after {
      box-sizing: inherit;
    }
    body {
      margin: 0;
      font-family: "Atkinson Hyperlegible", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      font-size: 18px;
      line-height: 1.55;
      background: var(--bg);
      color: var(--ink);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    main {
      flex: 1 0 auto;
    }
    h1, h2 {
      font-family: Bitter, Georgia, serif;
      margin: 0;
    }
    header {
      background: #f4f4f4;
      border-bottom: 1px solid #e0e0e0;
      color: #3a3a3a;
    }
    .bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 12px 32px;
      max-width: 1244px;
      margin: 0 auto;
    }
    header img {
      height: 52px;
      width: auto;
      max-width: 280px;
      object-fit: contain;
      display: block;
    }
    .signup {
      display: flex;
      align-items: center;
      gap: 16px;
      font-size: .95rem;
    }
    .signup a {
      background: #c2185b;
      color: #fff;
      font-weight: 700;
      padding: 10px 18px;
      border-radius: 6px;
      text-decoration: none;
      transition: background 0.15s ease;
    }
    .signup a:hover {
      background: #a8134e;
    }
    .hero {
      position: relative;
      overflow: hidden;
      background: var(--sky);
    }
    .hero-reg {
      height: clamp(260px, 21vw, 360px);
    }
    .scene {
      position: absolute;
      left: 0;
      bottom: 0;
      width: 100%;
      height: clamp(280px, 32vw, 460px);
    }
    .hero-reg .scene {
      inset: 0;
      height: 100%;
    }
    .scene .far { fill: var(--hill-far); }
    .scene .near { fill: var(--hill-near); }
    .scene .lagoon { fill: var(--water); }
    .scene .ripple {
      fill: none;
      stroke: var(--wave);
      stroke-width: 3;
      stroke-linecap: round;
    }
    .sun {
      position: absolute;
      top: 44px;
      right: 14%;
      width: 104px;
      height: 104px;
      border-radius: 50%;
      background: #f28c28;
      animation: rise 1.4s cubic-bezier(.2, .7, .2, 1) both;
    }
    .hero-reg .sun {
      top: 36px;
      width: 88px;
      height: 88px;
    }
    @keyframes rise {
      from { transform: translateY(110px); }
    }
    @media (prefers-reduced-motion: reduce) {
      .sun { animation: none; }
    }
    .wrap {
      position: relative;
      max-width: 1180px;
      margin: 0 auto;
      padding: 0 32px;
      min-height: 680px;
      display: grid;
      grid-template-columns: minmax(0, 1fr) 420px;
      column-gap: 64px;
    }
    .copy {
      align-self: start;
      padding-top: 72px;
    }
    h1 {
      font-size: clamp(2.1rem, 4vw, 3.2rem);
      line-height: 1.15;
      max-width: 14em;
    }
    .lead {
      font-size: 1.2rem;
      max-width: 32em;
      margin: 20px 0 24px;
    }
    .copy a {
      color: var(--ink);
      font-weight: 700;
      text-underline-offset: 4px;
    }
    .sheet-wrapper {
      align-self: end;
      margin-bottom: 56px;
      width: 100%;
    }
    .sheet {
      background: var(--sheet);
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 32px;
      box-shadow: 0 8px 30px rgba(0,0,0,0.06);
    }
    .sheet h2 {
      font-size: 1.7rem;
      margin-bottom: 24px;
    }
    .hint {
      margin: 0 0 24px;
      color: var(--muted);
      font-size: 0.95rem;
    }
    label {
      display: block;
      font-weight: 700;
      margin-bottom: 6px;
    }
    .field {
      position: relative;
      margin-bottom: 20px;
    }
    input[type="text"], input[type="password"], input[type="email"], input[type="tel"] {
      width: 100%;
      height: 48px;
      border: 1.5px solid var(--field);
      border-radius: 6px;
      padding: 0 14px;
      font: inherit;
      background: var(--sheet);
      color: var(--ink);
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
    }
    input:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 3px var(--ring);
    }
    .pw input {
      padding-right: 88px;
    }
    .show {
      position: absolute;
      right: 4px;
      bottom: 4px;
      height: 40px;
      padding: 0 12px;
      border: 0;
      background: none;
      color: var(--link);
      font: inherit;
      font-size: .95rem;
      font-weight: 700;
      cursor: pointer;
      border-radius: 4px;
    }
    .show:hover {
      text-decoration: underline;
    }
    :is(.show, .submit, .btn, a):focus-visible {
      outline: 3px solid var(--ring);
      outline-offset: 2px;
    }
    .links {
      display: flex;
      flex-direction: column;
      gap: 6px;
      font-size: .95rem;
      margin: -4px 0 24px;
    }
    .links a {
      color: var(--link);
      text-decoration: none;
    }
    .links a:hover {
      text-decoration: underline;
    }
    .submit {
      width: 100%;
      height: 50px;
      border: 0;
      border-radius: 6px;
      background: var(--primary);
      color: #fff;
      font: inherit;
      font-weight: 700;
      font-size: 1.05rem;
      cursor: pointer;
      transition: filter 0.15s ease;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
    }
    .submit:hover {
      filter: brightness(.92);
    }
    .submit:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
    .flash-alert, .flash-error {
      padding: 12px 16px;
      background: #fde8e7;
      color: #b3261e;
      border-left: 4px solid #b3261e;
      border-radius: 6px;
      font-size: 0.95rem;
      font-weight: 600;
      margin-bottom: 20px;
    }
    .flash-notice, .flash-success {
      padding: 12px 16px;
      background: var(--note);
      color: var(--water);
      border-left: 4px solid var(--water);
      border-radius: 6px;
      font-size: 0.95rem;
      font-weight: 600;
      margin-bottom: 20px;
    }
    .col {
      max-width: 880px;
      margin-left: auto;
      margin-right: auto;
      padding: 0 20px;
    }
    .hero-reg .col {
      position: relative;
      padding-top: 56px;
    }
    .sheetwrap {
      position: relative;
      margin-top: -88px;
      margin-bottom: 64px;
    }
    .note {
      margin: 0 0 24px;
      padding: 12px 16px;
      background: var(--note);
      border-left: 4px solid var(--link);
      border-radius: 6px;
      font-size: 0.95rem;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px 24px;
    }
    .actions {
      display: flex;
      justify-content: flex-end;
      gap: 12px;
      margin-top: 32px;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      height: 50px;
      padding: 0 24px;
      border-radius: 6px;
      font: inherit;
      font-weight: 700;
      font-size: 1.05rem;
      cursor: pointer;
      text-decoration: none;
    }
    .back {
      background: none;
      border: 1.5px solid var(--field);
      color: var(--ink);
    }
    .back:hover {
      border-color: var(--ink);
    }
    .help {
      max-width: 1180px;
      margin: 0 auto;
      padding: 64px 32px;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 34em));
      gap: 48px;
    }
    .help h2 {
      font-size: 1.25rem;
      margin-bottom: 8px;
    }
    .help p {
      margin: 0;
      color: var(--muted);
    }
    footer {
      max-width: 1180px;
      margin: 0 auto;
      padding: 24px 32px 36px;
      color: var(--muted);
      font-size: .9rem;
      text-align: center;
      border-top: 1px solid var(--line);
    }
    @media (max-width: 900px) {
      .wrap {
        grid-template-columns: 1fr;
        min-height: 0;
        padding: 0 20px;
      }
      .copy {
        padding-top: 88px;
      }
      .sheet-wrapper {
        margin: 32px 0 40px;
      }
      .sun {
        width: 60px;
        height: 60px;
        top: 20px;
        right: 20px;
      }
      .help {
        grid-template-columns: 1fr;
        padding: 48px 20px;
        gap: 32px;
      }
      footer {
        padding: 20px;
      }
    }
    @media (max-width: 640px) {
      .grid {
        grid-template-columns: 1fr;
      }
      .sheet {
        padding: 24px 20px;
      }
      .actions {
        flex-direction: column-reverse;
      }
      .hero-reg .col {
        padding-top: 44px;
      }
    }
    @media (max-width: 560px) {
      .signup span {
        display: none;
      }
      .bar {
        padding: 10px 16px;
      }
    }
  </style>
</head>
<body>
  <%= render 'layouts/google_tag_manager_body' if lookup_context.exists?('layouts/_google_tag_manager_body') %>
  <%= render 'layouts/not_logged_header' %>

  <%= yield %>

  <footer>
    <%= (defined?(current_entity_configuration) && current_entity_configuration.try(:entity_name).presence) || "Prefeitura de Lagoa da Canoa" %>. Nossa gente, nosso orgulho.
  </footer>
</body>
</html>
EOF

# --- B) Header Não-Logado ---
cat << 'EOF' > "$TARGET_DIR/app/views/layouts/_not_logged_header.html.erb"
<header>
  <div class="bar">
    <%= link_to root_path, class: "logo-link", title: "Início" do %>
      <% dynamic_logo = (logo_url.presence rescue nil) %>
      <% if dynamic_logo.present? %>
        <%= image_tag dynamic_logo, height: '52px', alt: (current_entity_configuration.try(:entity_name) rescue "Comunidade Escolar") %>
      <% else %>
        <img src="data:image/png;base64,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" alt="Prefeitura de Lagoa da Canoa, nossa gente, nosso orgulho" height="52px">
      <% end %>
    <% end %>

    <div class="signup">
      <% if controller_name == 'registrations' %>
        <span>Já possui uma conta?</span>
        <%= link_to "Acessar", new_user_session_path %>
      <% else %>
        <span>Não possui uma conta?</span>
        <%= link_to "Criar conta", new_registration_path %>
      <% end %>
    </div>
  </div>
</header>
EOF

# --- C) Tela de Login (Sessions/New) ---
cat << 'EOF' > "$TARGET_DIR/app/views/devise/sessions/new.html.erb"
<main>
  <div class="hero">
    <svg class="scene" viewBox="0 0 1440 360" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
      <path class="far" d="M0 150C180 100 360 130 560 118S940 70 1160 112 1360 120 1440 100V230H0Z"/>
      <path class="near" d="M0 190C200 150 420 175 640 160S1020 150 1220 170 1380 168 1440 160V230H0Z"/>
      <rect class="lagoon" y="205" width="1440" height="155"/>
      <g class="ripple"><path d="M80 250h120M300 300h160M560 236h90M740 300h200M1000 262h140M1180 322h120M120 336h100"/></g>
      <g transform="translate(250 246)">
        <path fill="#d81b60" d="M0 6C30 32 160 32 190 6 170 42 20 42 0 6Z"/>
        <path d="M118-30L160 24" stroke="#f28c28" stroke-width="5" stroke-linecap="round"/>
      </g>
    </svg>
    <div class="sun" aria-hidden="true"></div>

    <div class="wrap">
      <div class="copy">
        <h1>Serviços eletrônicos para a comunidade escolar</h1>
        <p class="lead">Estamos ajudando a conectar pais, alunos e professores. Crie sua conta e confira. Ensinar e aprender nunca foi tão moderno!</p>
        <a href="#ajuda">Ver recursos e ajuda</a>
      </div>

      <div class="sheet-wrapper">
        <% flash.each do |key, value| %>
      <% next if value.blank? %>
      <% css_class = (key.to_s == 'notice' || key.to_s == 'success') ? 'flash-notice' : 'flash-alert' %>
      <% Array(value).each do |msg| %>
        <div class="<%= css_class %>" role="alert"><%= sanitize(msg.to_s) %></div>
      <% end %>
    <% end %>

        <%= simple_form_for(resource, as: resource_name, url: session_path(resource_name), html: { class: "sheet", id: "f" }) do |f| %>
          <h2>Acessar</h2>

          <div class="field">
            <label for="usuario">Nome de usuário, e-mail ou CPF</label>
            <%= f.input_field :credentials, id: 'usuario', autocomplete: 'username', required: true, autofocus: true %>
          </div>

          <div class="field pw">
            <label for="senha">Senha</label>
            <%= f.input_field :password, id: 'senha', autocomplete: 'current-password', required: true %>
            <button class="show" id="show" type="button" aria-controls="senha" aria-label="Mostrar senha">Mostrar</button>
          </div>

          <div class="links">
            <%= render "devise/shared/links" %>
          </div>

          <%= f.button :submit, "Acessar", class: "submit", id: 'btn-login' %>
        <% end %>
      </div>
    </div>
  </div>

  <section class="help" id="ajuda">
    <div>
      <h2>Quais recursos estão disponíveis?</h2>
      <p>Este serviço disponibiliza recursos e informações para pais, alunos e professores. A disponibilidade destes depende exclusivamente da instituição.</p>
    </div>
    <div>
      <h2>Como obter ajuda?</h2>
      <p>Se você precisar de ajuda, poderá contatar por e-mail ou telefone a instituição que você está tentando obter acesso.</p>
    </div>
  </section>
</main>

<script>
  (function() {
    var error = <%= @time.to_i rescue 0 %>;
    if (error > 0) {
      var btn = document.getElementById('btn-login');
      if (btn) {
        btn.disabled = true;
        setTimeout(function() {
          btn.disabled = false;
        }, error);
      }
    }

    var pw = document.getElementById('senha');
    var b = document.getElementById('show');
    if (pw && b) {
      b.addEventListener('click', function() {
        var isPass = pw.type === 'password';
        pw.type = isPass ? 'text' : 'password';
        b.textContent = isPass ? 'Ocultar' : 'Mostrar';
        b.setAttribute('aria-label', isPass ? 'Ocultar senha' : 'Mostrar senha');
      });
    }
  })();
</script>
EOF

# --- D) Tela Esqueceu Senha (Passwords/New) ---
cat << 'EOF' > "$TARGET_DIR/app/views/devise/passwords/new.html.erb"
<main>
  <div class="hero">
    <svg class="scene" viewBox="0 0 1440 360" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
      <path class="far" d="M0 150C180 100 360 130 560 118S940 70 1160 112 1360 120 1440 100V230H0Z"/>
      <path class="near" d="M0 190C200 150 420 175 640 160S1020 150 1220 170 1380 168 1440 160V230H0Z"/>
      <rect class="lagoon" y="205" width="1440" height="155"/>
      <g class="ripple"><path d="M80 250h120M300 300h160M560 236h90M740 300h200M1000 262h140M1180 322h120M120 336h100"/></g>
      <g transform="translate(250 246)">
        <path fill="#d81b60" d="M0 6C30 32 160 32 190 6 170 42 20 42 0 6Z"/>
        <path d="M118-30L160 24" stroke="#f28c28" stroke-width="5" stroke-linecap="round"/>
      </g>
    </svg>
    <div class="sun" aria-hidden="true"></div>

    <div class="wrap">
      <div class="copy">
        <h1>Serviços eletrônicos para a comunidade escolar</h1>
        <p class="lead">Estamos ajudando a conectar pais, alunos e professores. Crie sua conta e confira. Ensinar e aprender nunca foi tão moderno!</p>
        <a href="#ajuda">Ver recursos e ajuda</a>
      </div>

      <div class="sheet-wrapper">
        <% flash.each do |key, value| %>
      <% next if value.blank? %>
      <% css_class = (key.to_s == 'notice' || key.to_s == 'success') ? 'flash-notice' : 'flash-alert' %>
      <% Array(value).each do |msg| %>
        <div class="<%= css_class %>" role="alert"><%= sanitize(msg.to_s) %></div>
      <% end %>
    <% end %>

        <%= simple_form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :post, class: "sheet", id: "f" }) do |f| %>
          <h2>Esqueceu sua senha?</h2>
          <p class="hint">Informe seu e-mail. Vamos enviar as instruções para você criar uma nova senha.</p>

          <div class="field">
            <label for="email">E-mail</label>
            <%= f.input_field :email, id: 'email', autocomplete: 'email', required: true, autofocus: true %>
          </div>

          <div class="links">
            <%= render "devise/shared/links" %>
          </div>

          <%= f.button :submit, "Enviar instruções", class: "submit" %>
        <% end %>
      </div>
    </div>
  </div>

  <section class="help" id="ajuda">
    <div>
      <h2>Quais recursos estão disponíveis?</h2>
      <p>Este serviço disponibiliza recursos e informações para pais, alunos e professores. A disponibilidade destes depende exclusivamente da instituição.</p>
    </div>
    <div>
      <h2>Como obter ajuda?</h2>
      <p>Se você precisar de ajuda, poderá contatar por e-mail ou telefone a instituição que você está tentando obter acesso.</p>
    </div>
  </section>
</main>
EOF

# --- E) Tela Reenviar Desbloqueio (Unlocks/New) ---
cat << 'EOF' > "$TARGET_DIR/app/views/devise/unlocks/new.html.erb"
<main>
  <div class="hero">
    <svg class="scene" viewBox="0 0 1440 360" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
      <path class="far" d="M0 150C180 100 360 130 560 118S940 70 1160 112 1360 120 1440 100V230H0Z"/>
      <path class="near" d="M0 190C200 150 420 175 640 160S1020 150 1220 170 1380 168 1440 160V230H0Z"/>
      <rect class="lagoon" y="205" width="1440" height="155"/>
      <g class="ripple"><path d="M80 250h120M300 300h160M560 236h90M740 300h200M1000 262h140M1180 322h120M120 336h100"/></g>
      <g transform="translate(250 246)">
        <path fill="#d81b60" d="M0 6C30 32 160 32 190 6 170 42 20 42 0 6Z"/>
        <path d="M118-30L160 24" stroke="#f28c28" stroke-width="5" stroke-linecap="round"/>
      </g>
    </svg>
    <div class="sun" aria-hidden="true"></div>

    <div class="wrap">
      <div class="copy">
        <h1>Serviços eletrônicos para a comunidade escolar</h1>
        <p class="lead">Estamos ajudando a conectar pais, alunos e professores. Crie sua conta e confira. Ensinar e aprender nunca foi tão moderno!</p>
        <a href="#ajuda">Ver recursos e ajuda</a>
      </div>

      <div class="sheet-wrapper">
        <% flash.each do |key, value| %>
      <% next if value.blank? %>
      <% css_class = (key.to_s == 'notice' || key.to_s == 'success') ? 'flash-notice' : 'flash-alert' %>
      <% Array(value).each do |msg| %>
        <div class="<%= css_class %>" role="alert"><%= sanitize(msg.to_s) %></div>
      <% end %>
    <% end %>

        <%= simple_form_for(resource, as: resource_name, url: unlock_path(resource_name), html: { method: :post, class: "sheet", id: "f" }) do |f| %>
          <h2>Reenviar instruções de desbloqueio</h2>
          <p class="hint">Informe seu e-mail. Vamos enviar as instruções para desbloquear sua conta.</p>

          <div class="field">
            <label for="email">E-mail</label>
            <%= f.input_field :email, id: 'email', autocomplete: 'email', required: true, autofocus: true %>
          </div>

          <div class="links">
            <%= render "devise/shared/links" %>
          </div>

          <%= f.button :submit, "Reenviar instruções de desbloqueio", class: "submit" %>
        <% end %>
      </div>
    </div>
  </div>

  <section class="help" id="ajuda">
    <div>
      <h2>Quais recursos estão disponíveis?</h2>
      <p>Este serviço disponibiliza recursos e informações para pais, alunos e professores. A disponibilidade destes depende exclusivamente da instituição.</p>
    </div>
    <div>
      <h2>Como obter ajuda?</h2>
      <p>Se você precisar de ajuda, poderá contatar por e-mail ou telefone a instituição que você está tentando obter acesso.</p>
    </div>
  </section>
</main>
EOF

# --- F) Tela Cadastro (Registrations/New) ---
cat << 'EOF' > "$TARGET_DIR/app/views/layouts/registration.html.erb"
<%= render template: 'layouts/devise' %>
EOF

mkdir -p "$TARGET_DIR/app/views/registrations"
cat << 'EOF' > "$TARGET_DIR/app/views/registrations/new.html.erb"
<main>
  <div class="hero hero-reg">
    <svg class="scene" viewBox="0 0 1440 300" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
      <path class="far" d="M0 170C180 130 360 150 560 140S940 110 1160 140 1360 146 1440 130V240H0Z"/>
      <path class="near" d="M0 200C200 175 420 190 640 182S1020 176 1220 190 1380 188 1440 182V250H0Z"/>
      <rect class="lagoon" y="224" width="1440" height="76"/>
      <g class="ripple"><path d="M80 250h120M300 276h150M520 246h90M720 280h190M1000 252h140M1160 286h120M120 288h100"/></g>
      <g transform="translate(1180 238)">
        <path fill="#d81b60" d="M0 6C30 32 160 32 190 6 170 42 20 42 0 6Z"/>
        <path d="M118-30L160 24" stroke="#f28c28" stroke-width="5" stroke-linecap="round"/>
      </g>
    </svg>
    <div class="sun" aria-hidden="true"></div>
    <div class="col"><h1>Crie sua conta</h1></div>
  </div>

  <div class="col sheetwrap">
    <% flash.each do |key, value| %>
      <% next if value.blank? %>
      <% css_class = (key.to_s == 'notice' || key.to_s == 'success') ? 'flash-notice' : 'flash-alert' %>
      <% Array(value).each do |msg| %>
        <div class="<%= css_class %>" role="alert"><%= sanitize(msg.to_s) %></div>
      <% end %>
    <% end %>

    <%= simple_form_for @signup, as: :signup, url: registrations_path, html: { class: "sheet", id: "f" } do |f| %>
      <h2>Dados pessoais</h2>
      <p class="note">Depois de criar sua conta você poderá acessar usando seu e-mail ou CPF.</p>

      <% if @signup.errors.any? %>
        <div class="flash-alert" role="alert">
          <%= @signup.errors.full_messages.to_sentence %>
        </div>
      <% end %>

      <div class="grid">
        <div class="field">
          <label for="nome">Nome</label>
          <%= f.input_field :first_name, id: "nome", placeholder: "Nome", required: true, autocomplete: "given-name" %>
        </div>

        <div class="field">
          <label for="sobrenome">Sobrenome</label>
          <%= f.input_field :last_name, id: "sobrenome", placeholder: "Sobrenome", required: true, autocomplete: "family-name" %>
        </div>

        <div class="field">
          <label for="email">E-mail</label>
          <%= f.input_field :email, id: "email", placeholder: "E-mail", required: true, autocomplete: "email" %>
        </div>

        <div class="field">
          <label for="cpf">CPF</label>
          <%= f.input_field :document, id: "cpf", placeholder: "000.000.000-00", required: true, maxlength: 14, autocomplete: "off", inputmode: "numeric" %>
        </div>

        <div class="field pw">
          <label for="senha">Senha</label>
          <%= f.input_field :password, id: "senha", required: true, autocomplete: "new-password" %>
          <button class="show" type="button" data-for="senha" aria-label="Mostrar senha">Mostrar</button>
        </div>

        <div class="field pw">
          <label for="confirma">Confirme a senha</label>
          <%= f.input_field :password_confirmation, id: "confirma", required: true, autocomplete: "new-password" %>
          <button class="show" type="button" data-for="confirma" aria-label="Mostrar confirmação da senha">Mostrar</button>
        </div>
      </div>

      <div class="type" style="margin-top: 36px; padding-top: 28px; border-top: 1px solid var(--line);">
        <h2 style="font-size: 1.3rem; margin-bottom: 14px;">Tipo de conta</h2>
        <label class="opt" style="display: flex; gap: 14px; align-items: flex-start; padding: 16px; border: 1.5px solid var(--field); border-radius: 6px; cursor: pointer; font-weight: 400; margin: 0;">
          <%= f.input_field :employee_role, as: :boolean, boolean_style: :inline, style: "flex: none; width: 22px; height: 22px; margin: 2px 0 0; accent-color: var(--primary);" %>
          <span>
            <b style="display: block; font-weight: 700;">Acesso servidores</b>
            <span style="color: var(--muted); font-size: 0.95rem;">Selecione esta opção se você é um servidor da rede de ensino e deseja cadastrar-se para acessar recursos como diário eletrônico e outras ferramentas administrativas exclusivas para servidores.</span>
          </span>
        </label>
      </div>

      <div class="actions">
        <%= link_to 'Voltar', root_path, class: "btn back" %>
        <%= f.button :submit, "Confirmar e acessar o sistema", class: "btn submit", data: { disable_with: "Enviando..." } %>
      </div>
    <% end %>
  </div>
</main>

<script>
  (function() {
    document.querySelectorAll('.show[data-for]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var input = document.getElementById(btn.getAttribute('data-for'));
        if (input) {
          var isPass = input.type === 'password';
          input.type = isPass ? 'text' : 'password';
          btn.textContent = isPass ? 'Ocultar' : 'Mostrar';
        }
      });
    });

    var cpf = document.getElementById('cpf');
    if (cpf) {
      cpf.addEventListener('input', function(e) {
        var v = e.target.value.replace(/\D/g, '');
        if (v.length > 11) v = v.slice(0, 11);
        v = v.replace(/(\d{3})(\d)/, '$1.$2');
        v = v.replace(/(\d{3})(\d)/, '$1.$2');
        v = v.replace(/(\d{3})(\d{1,2})$/, '$1-$2');
        e.target.value = v;
      });
    }
  })();
</script>
EOF

# Mantém também devise/registrations/new.html.erb para compatibilidade se invocado
mkdir -p "$TARGET_DIR/app/views/devise/registrations"
cp "$TARGET_DIR/app/views/registrations/new.html.erb" "$TARGET_DIR/app/views/devise/registrations/new.html.erb" 2>/dev/null || true

# --- G) Links Compartilhados (_links.erb) ---
cat << 'EOF' > "$TARGET_DIR/app/views/devise/shared/_links.erb"
<%- if controller_name != 'sessions' %>
  <%= link_to "Retornar e fazer login", new_session_path(resource_name) %>
<% end -%>

<%- if devise_mapping.recoverable? && controller_name != 'passwords' && controller_name != 'registrations' %>
  <%= link_to "Esqueceu sua senha?", new_password_path(resource_name) %>
<% end -%>

<%- if devise_mapping.confirmable? && controller_name != 'confirmations' %>
  <%= link_to "Reenviar instruções de confirmação", new_confirmation_path(resource_name) %>
<% end -%>

<%- if devise_mapping.lockable? && resource_class.unlock_strategy_enabled?(:email) && controller_name != 'unlocks' %>
  <%= link_to "Reenviar instruções de desbloqueio da conta", new_unlock_path(resource_name) %>
<% end -%>
EOF

# 4. Reiniciar serviços se aplicável
echo -e "${BLUE}ℹ Atualizando permissões e reiniciando aplicação...${NC}"
# Garantir que /favicon.ico exista na raiz pública
if [ -f "$TARGET_DIR/public/assets/favicon.ico" ]; then
  cp "$TARGET_DIR/public/assets/favicon.ico" "$TARGET_DIR/public/favicon.ico" 2>/dev/null || true
fi
mkdir -p "$TARGET_DIR/tmp"
touch "$TARGET_DIR/tmp/restart.txt" 2>/dev/null || true

if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet idiario-web 2>/dev/null; then
    systemctl restart idiario-web && echo -e "  systemctl restart idiario-web: OK"
  elif systemctl is-active --quiet i-diario 2>/dev/null; then
    systemctl restart i-diario && echo -e "  systemctl restart i-diario: OK"
  elif systemctl is-active --quiet puma 2>/dev/null; then
    systemctl restart puma && echo -e "  systemctl restart puma: OK"
  elif systemctl is-active --quiet passenger 2>/dev/null; then
    systemctl restart passenger && echo -e "  systemctl restart passenger: OK"
  fi
fi

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  ✔ SUCESSO! A nova tela de login do i-Diário foi instalada!    ${NC}"
echo -e "${GREEN}  Tema: Comunidade Escolar · Lagoa da Canoa                     ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "${BLUE}Caso utilize Nginx ou Apache com cache, você pode recarregar:${NC}"
echo -e "  sudo systemctl reload nginx   (ou apache2)"
echo -e "  touch $TARGET_DIR/tmp/restart.txt"
