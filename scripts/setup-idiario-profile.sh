#!/usr/bin/env bash
# ==============================================================================
# Script: setup-idiario-profile.sh
# Objetivo: Correção automática da Foto de Perfil, Cropper e Menu no i-Diário
#           (Configuração de secrets.yml, ImageMagick, JavaScript e assets)
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}   CORREÇÃO AUTOMÁTICA: FOTO DE PERFIL & MENU DO I-DIÁRIO             ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Localizar o diretório do i-Diário
detect_idiario_dir() {
    # Estratégia A: .env do backup
    if [[ -f /etc/ieducar-backup/.env ]]; then
        local env_path
        env_path=$(grep -E "^IDIARIO_APP_DIR=" /etc/ieducar-backup/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        if [[ -n "$env_path" && -d "$env_path/app" ]]; then
            echo "$env_path"
            return 0
        fi
    fi

    # Estratégia B: Caminhos padrão
    local common_paths=(
        "/root/i-diario"
        "/var/www/idiario"
        "/var/www/i-diario"
        "/home/deploy/i-diario"
        "/opt/idiario"
    )
    for p in "${common_paths[@]}"; do
        if [[ -d "$p/app" && -f "$p/Gemfile" ]]; then
            echo "$p"
            return 0
        fi
    done

    # Estratégia C: Busca por Gemfile com idiario
    local fast_file
    fast_file=$(find /root /var/www /home /opt -maxdepth 3 -type f -name "Gemfile" 2>/dev/null | grep -i "diario" | head -n 1 || true)
    if [[ -n "$fast_file" ]]; then
        echo "$(dirname "$fast_file")"
        return 0
    fi

    return 1
}

echo -e "${BLUE}Localizando diretório da aplicação i-Diário...${NC}"
APP_DIR=$(detect_idiario_dir || true)
APP_DIR="${APP_DIR:-/root/i-diario}"

if [[ ! -d "$APP_DIR" || ! -f "$APP_DIR/Gemfile" ]]; then
    echo ""
    echo -e "${YELLOW}======================================================================${NC}"
    echo -e "${YELLOW}       AVISO: DIRETÓRIO DO I-DIÁRIO NÃO ENCONTRADO NO SERVIDOR        ${NC}"
    echo -e "${YELLOW}======================================================================${NC}"
    echo -e "O i-Diário não foi localizado em: ${RED}${APP_DIR}${NC}"
    echo -e "Esta correção destina-se a servidores que possuem a aplicação i-Diário."
    echo -e "Nenhuma alteração foi realizada no sistema."
    echo ""
    exit 0
fi

echo -e "${GREEN}✓ i-Diário localizado em: ${APP_DIR}${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$APP_DIR/backups/perfil_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

# Garantir ambiente rbenv / rvm se presente
export PATH="/root/.rbenv/shims:/root/.rbenv/bin:/root/.rvm/bin:/usr/local/bin:$PATH"

# 2. Instalar ImageMagick se necessário
echo -e "${YELLOW}[1/6] Verificando dependência do sistema (imagemagick)...${NC}"
if ! command -v convert &> /dev/null; then
    echo -e "${BLUE} -> Instalando imagemagick...${NC}"
    if command -v apt-get &>/dev/null; then
        apt-get update -qq >/dev/null 2>&1 || true
        apt-get install -y imagemagick >/dev/null 2>&1 || true
    elif command -v yum &>/dev/null; then
        yum install -y ImageMagick >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN} -> ImageMagick instalado com sucesso!${NC}"
else
    echo -e "${GREEN} -> ImageMagick já está instalado.${NC}"
fi

# 3. Diretórios de upload e permissões
echo -e "${YELLOW}[2/6] Configurando diretórios de upload e permissões...${NC}"
mkdir -p "$APP_DIR/public/uploads"
chmod -R 777 "$APP_DIR/public/uploads" 2>/dev/null || true
chmod o+x /root 2>/dev/null || true
chmod o+x "$APP_DIR" 2>/dev/null || true
chmod -R o+rX "$APP_DIR/public" 2>/dev/null || true

# 4. Atualizar config/secrets.yml
echo -e "${YELLOW}[3/6] Atualizando config/secrets.yml...${NC}"
SECRETS_FILE="$APP_DIR/config/secrets.yml"

if [[ -f "$SECRETS_FILE" ]]; then
    cp "$SECRETS_FILE" "$BACKUP_DIR/secrets.yml.bak"

    # Garante shortcuts_enabled: true
    if ! grep -q "shortcuts_enabled:" "$SECRETS_FILE"; then
        sed -i '/production:/a \  shortcuts_enabled: true' "$SECRETS_FILE"
        echo -e "${GREEN} -> shortcuts_enabled: true adicionado.${NC}"
    else
        sed -i 's/shortcuts_enabled:.*/shortcuts_enabled: true/' "$SECRETS_FILE"
        echo -e "${GREEN} -> shortcuts_enabled atualizado para true.${NC}"
    fi

    # Garante new_update_profile_enabled: true
    if ! grep -q "new_update_profile_enabled:" "$SECRETS_FILE"; then
        sed -i '/production:/a \  new_update_profile_enabled: true' "$SECRETS_FILE"
        echo -e "${GREEN} -> new_update_profile_enabled: true adicionado.${NC}"
    else
        sed -i 's/new_update_profile_enabled:.*/new_update_profile_enabled: true/' "$SECRETS_FILE"
        echo -e "${GREEN} -> new_update_profile_enabled atualizado para true.${NC}"
    fi
else
    echo -e "${YELLOW} -> Aviso: $SECRETS_FILE não encontrado. Pulando secrets.${NC}"
fi

# 5. Corrigir JavaScript de edição de perfil
echo -e "${YELLOW}[4/6] Corrigindo JavaScript de edição de perfil...${NC}"
JS_FILE="$APP_DIR/app/assets/javascripts/views/accounts/edit.js"
mkdir -p "$(dirname "$JS_FILE")"

if [[ -f "$JS_FILE" ]]; then
    cp "$JS_FILE" "$BACKUP_DIR/edit.js.bak"
fi

cat << 'JS' > "$JS_FILE"
$(function() {
  'use strict';

  var toggleUserReceiveNewsOptions = function(){
    if($("#user_receive_news").prop("checked")){
      $(".receive_news_options").show();
    }else{
      $(".receive_news_options").hide();
    }
  }
  $("#user_receive_news").on("change", toggleUserReceiveNewsOptions);
  toggleUserReceiveNewsOptions();

  var avatar = $('#profile-picture-prev')[0];
  var menu_avatar = $('#menu_avatar')[0];
  var image = $('#profile-image')[0];
  var input = $('#profile-picture-input')[0];

  var $alert = $('.profile-picture-alert');
  var $modal = $('#profile-picture-modal');
  var cropper;
  var fileName;

  $('#profile-picture-input').on('change', function (e) {
    var files = e.target.files;
    var done = function (url) {
      input.value = '';
      image.src = url;
      $alert.hide();
      $modal.modal('show');
    };
    var reader;
    var file;
    var url;

    if (files && files.length > 0) {
      file = files[0];
      fileName = file.name;

      if (window.URL) {
        done(window.URL.createObjectURL(file));
      } else if (window.FileReader) {
        reader = new FileReader();
        reader.onload = function (e) {
          done(reader.result);
        };
        reader.readAsDataURL(file);
      }
    }
  });

  $modal.on('shown.bs.modal', function () {
    cropper = new Cropper(image, {
      aspectRatio: 1,
      viewMode: 3,
    });
  }).on('hidden.bs.modal', function () {
    if (cropper) {
      cropper.destroy();
      cropper = null;
    }
  });

  $('#crop-profile-picture').on('click', function () {
    var initialAvatarURL;
    var canvas;

    $modal.modal('hide');

    if (cropper) {
      canvas = cropper.getCroppedCanvas({
        width: 160,
        height: 160,
      });

      if (canvas) {
        initialAvatarURL = avatar.src;
        avatar.src = canvas.toDataURL();
        if (menu_avatar) menu_avatar.src = canvas.toDataURL();

        $alert.removeClass('alert-success alert-warning');
        canvas.toBlob(function (blob) {
          var formData = new FormData();
          var userId = $('#user_id').val();

          formData.append('profile_picture', blob, fileName);
          formData.append('locale', 'pt-BR');
          formData.append('id', userId);

          $.ajax({
            url: Routes.profile_picture_users_pt_br_path(),
            method: 'POST',
            data: formData,
            processData: false,
            contentType: false,
            dataType: 'json',
            success: function (data) {
              $('#profile-picture-alert-span').text('Foto de perfil atualizada com sucesso');
              $alert.show().addClass('alert-success');
              avatar.src = data.url;
              var topAvatar = $('#menu_avatar')[0];
              if (topAvatar) topAvatar.src = data.url;
            },
            error: function (data) {
              avatar.src = initialAvatarURL;
              if (menu_avatar) menu_avatar.src = initialAvatarURL;
              var errorMsg = (data.responseJSON && data.responseJSON.users && data.responseJSON.users[0]) || 'Erro ao enviar foto.';
              $('#profile-picture-alert-span').text(errorMsg);
              $alert.show().addClass('alert-warning');
            },
          });
        });
      } else {
        $('#profile-picture-alert-span').text('Formato desconhecido');
        $alert.show().addClass('alert-warning');
      }
    }
  });
});
JS

# 6. Recompilar assets para produção
echo -e "${YELLOW}[5/6] Recompilando assets para produção (assets:precompile)...${NC}"
cd "$APP_DIR"
if command -v bundle &>/dev/null; then
    RAILS_ENV=production bundle exec rake assets:precompile || true
else
    echo -e "${YELLOW} -> Comando 'bundle' não encontrado no PATH atual. Pulando pré-compilação.${NC}"
fi

# 7. Reiniciar serviços do i-Diário
echo -e "${YELLOW}[6/6] Reiniciando serviços do i-Diário...${NC}"
SERVICES=(
    "idiario-web"
    "idiario-sidekiq"
    "idiario-sync"
    "idiario-sync-worker"
    "idiario-exam-posting"
)

for s in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${s}.service"; then
        systemctl restart "$s" >/dev/null 2>&1 || true
    fi
done

echo ""
echo -e "${CYAN}==========================================================${NC}"
echo -e "${CYAN}          STATUS DOS SERVIÇOS DO I-DIÁRIO                 ${NC}"
echo -e "${CYAN}==========================================================${NC}"
for s in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "^${s}.service"; then
        local_status=$(systemctl is-active "$s" 2>/dev/null || echo "inativo")
        if [[ "$local_status" == "active" ]]; then
            printf "%-25s: ${GREEN}%s${NC}\n" "$s" "$local_status"
        else
            printf "%-25s: ${YELLOW}%s${NC}\n" "$s" "$local_status"
        fi
    fi
done

echo ""
echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN} [OK] Atualização do perfil concluída com sucesso!        ${NC}"
echo -e "${GREEN} Backups salvos em: ${BACKUP_DIR}                         ${NC}"
echo -e "${GREEN} Pressione Ctrl + F5 no navegador para limpar o cache.    ${NC}"
echo -e "${GREEN}==========================================================${NC}"
