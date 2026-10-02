#!/usr/bin/env bash
# ==============================================================================
# Script: setup-pmd-leaflet.sh
# Objetivo: Migração completa do Google Maps para Leaflet + OpenStreetMap
#           no módulo de Pré-Matrícula Digital (PMD) do i-Educar.
# Município: Lagoa da Canoa - AL | IBGE: 2704104
# ==============================================================================

set -euo pipefail

# Cores para terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}  Instalação e Atualização Completa do PMD (Leaflet + OpenStreetMap)  ${NC}"
echo -e "${BLUE}  Município: Lagoa da Canoa - AL | IBGE: 2704104                      ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Localização 100% Automática do Diretório do i-Educar
detect_ieducar_dir() {
    # Estratégia A: Variável IEDUCAR_STORAGE_PATH no /etc/ieducar-backup/.env se existir
    if [[ -f /etc/ieducar-backup/.env ]]; then
        local env_storage
        env_storage=$(grep -E "^IEDUCAR_STORAGE_PATH=" /etc/ieducar-backup/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        if [[ -n "$env_storage" && -d "$env_storage" ]]; then
            local cand
            cand=$(dirname "$env_storage")
            if [[ -f "$cand/artisan" || -d "$cand/packages" ]]; then
                echo "$cand"
                return 0
            fi
        fi
    fi

    # Estratégia B: Caminhos padrão mais comuns
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
        if [[ -f "$p/artisan" && -d "$p/packages" ]]; then
            echo "$p"
            return 0
        fi
    done

    # Estratégia C: Busca rápida por artisan
    local fast_file
    fast_file=$(find /var/www /srv /opt /home /root -maxdepth 4 -type f -name "artisan" 2>/dev/null | head -n 1 || true)
    if [[ -n "$fast_file" ]]; then
        local cand
        cand=$(dirname "$fast_file")
        if [[ -d "$cand/packages" ]]; then
            echo "$cand"
            return 0
        fi
    fi

    return 1
}

echo -e "${BLUE}Localizando instalação do i-Educar...${NC}"
IEDUCAR_DIR=$(detect_ieducar_dir || true)
IEDUCAR_DIR="${IEDUCAR_DIR:-/var/www/ieducar}"

if [[ ! -d "$IEDUCAR_DIR" ]]; then
    echo -e "${RED}[ERRO] Diretório do i-Educar não encontrado em ${IEDUCAR_DIR}.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ i-Educar localizado em: ${IEDUCAR_DIR}${NC}"

PMD_DIR="${IEDUCAR_DIR}/packages/portabilis/pre-matricula-digital"

# 2. Verificar se o módulo do PMD está instalado
if [[ ! -d "$PMD_DIR" ]]; then
    echo ""
    echo -e "${YELLOW}======================================================================${NC}"
    echo -e "${YELLOW}   AVISO: MÓDULO DE PRÉ-MATRÍCULA DIGITAL (PMD) NÃO ENCONTRADO        ${NC}"
    echo -e "${YELLOW}======================================================================${NC}"
    echo -e "O diretório do PMD não foi localizado em:"
    echo -e " ${RED}${PMD_DIR}${NC}"
    echo ""
    echo -e "Esta ação só pode ser executada em servidores onde o módulo PMD"
    echo -e "estiver devidamente instalado e presente na pasta packages."
    echo -e "Nenhuma alteração foi realizada no sistema."
    echo ""
    exit 0
fi

echo -e "${GREEN}✓ Módulo PMD encontrado em: ${PMD_DIR}${NC}"

# Detectar proprietário web
WEB_USER=$(stat -c '%U' "$IEDUCAR_DIR" 2>/dev/null || echo "www-data")
WEB_GROUP=$(stat -c '%G' "$IEDUCAR_DIR" 2>/dev/null || echo "$WEB_USER")
if [[ "$WEB_USER" == "root" ]] && id -u "www-data" &>/dev/null; then
    WEB_USER="www-data"
    WEB_GROUP="www-data"
fi

# Verificar Node.js e NPM
if ! command -v npm &>/dev/null; then
    echo -e "${YELLOW}Node.js / NPM não encontrado no sistema. Tentando instalar...${NC}"
    if command -v apt-get &>/dev/null; then
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y nodejs npm >/dev/null 2>&1 || true
    fi
    if ! command -v npm &>/dev/null; then
        echo -e "${RED}[ERRO] NPM é obrigatório para compilar o frontend do PMD com Vite.${NC}"
        echo "Por favor, instale o Node.js e NPM no servidor antes de continuar."
        exit 1
    fi
fi

# 3. Configurar o .env do PMD
echo -e "${YELLOW}[1/10] Configurando .env do PMD (VITE_BASE)...${NC}"
cd "$PMD_DIR"
touch .env
sed -i '/VITE_BASE=/d' .env
echo "VITE_BASE=/pre-matricula-digital/" >> .env

# 4. Configurar o .env principal do i-Educar com Lagoa da Canoa (IBGE 2704104)
echo -e "${YELLOW}[2/10] Configurando .env principal do i-Educar...${NC}"
cd "$IEDUCAR_DIR"
touch .env
sed -i '/PREMATRICULA_/d' .env
cat << 'ENV_EOF' >> .env

# Configurações da Pré-Matrícula Digital
PREMATRICULA_CITY="Lagoa da Canoa"
PREMATRICULA_STATE="AL"
PREMATRICULA_IBGE_CODES="2704104"
PREMATRICULA_LOGO="/storage/ieducar/brasao-lagoa-da-canoa.png"
PREMATRICULA_MAP_LAT=-9.8294
PREMATRICULA_MAP_LNG=-36.7867
PREMATRICULA_MAP_ZOOM=14
ENV_EOF

# 5. Atualizar arquivos de configuração PHP (config/prematricula.php)
echo -e "${YELLOW}[3/10] Atualizando config/prematricula.php com suporte ao .env...${NC}"
mkdir -p "$PMD_DIR/config" "$IEDUCAR_DIR/config"

cat << 'PHP_CONF' > "$PMD_DIR/config/prematricula.php"
<?php

return [
    'active' => env('PMD_ACTIVE', true),
    'token' => env('PMD_TOKEN'),
    'allow_optional_address' => true,
    'show_how_to_do_video' => true,
    'video_intro_url' => null,
    'ibge_codes' => env('PREMATRICULA_IBGE_CODES', '2704104'),
    'city' => env('PREMATRICULA_CITY', 'Lagoa da Canoa'),
    'state' => env('PREMATRICULA_STATE', 'AL'),
    'map' => [
        'lat' => (float) env('PREMATRICULA_MAP_LAT', -9.8294),
        'lng' => (float) env('PREMATRICULA_MAP_LNG', -36.7867),
        'zoom' => (int) env('PREMATRICULA_MAP_ZOOM', 14),
    ],
    'logo' => env('PREMATRICULA_LOGO', '/storage/ieducar/brasao-lagoa-da-canoa.png'),
    'slogan' => env('PREMATRICULA_SLOGAN', 'Prefeitura Municipal de '),
    'standalone' => !env('PMD_LEGACY', true),
    'legacy' => true,
    'link_to_restrict_area' => null,
    'features' => [
        'allow_preregistration_data_update' => true,
        'allow_external_system_data_update' => true,
        'allow_transfer_registration' => false,
        'transfer_description' => 'Transferência Pré-matrícula Digital',
        'allow_vacancy_certificate' => false,
    ],
    'minha_vaga_na_creche' => [
        'url' => env('PMD_MINHA_VAGA_NA_CRECHE_URL'),
        'token' => env('PMD_MINHA_VAGA_NA_CRECHE_TOKEN'),
    ],
    'user' => env('PMD_USER', 1),
];
PHP_CONF

cp "$PMD_DIR/config/prematricula.php" "$IEDUCAR_DIR/config/prematricula.php"

# 6. Atualizar configurações no Banco de Dados (App\Setting)
echo -e "${YELLOW}[4/10] Atualizando configurações no Banco de Dados (App\Setting)...${NC}"
if [[ -f "$IEDUCAR_DIR/artisan" ]]; then
    php "$IEDUCAR_DIR/artisan" tinker --execute="
    try {
        App\Setting::updateOrCreate(['key' => 'prematricula.map.lat'], ['value' => '-9.8294']);
        App\Setting::updateOrCreate(['key' => 'prematricula.map.lng'], ['value' => '-36.7867']);
        App\Setting::updateOrCreate(['key' => 'prematricula.map.zoom'], ['value' => '14']);
        App\Setting::updateOrCreate(['key' => 'prematricula.city'], ['value' => 'Lagoa da Canoa']);
        App\Setting::updateOrCreate(['key' => 'prematricula.state'], ['value' => 'AL']);
        App\Setting::updateOrCreate(['key' => 'prematricula.ibge_codes'], ['value' => '2704104']);
        App\Setting::updateOrCreate(['key' => 'prematricula.logo'], ['value' => '/storage/ieducar/brasao-lagoa-da-canoa.png']);
    } catch (\Throwable \$e) {}
    " >/dev/null 2>&1 || true
fi

# 7. Instalar o Leaflet via NPM
echo -e "${YELLOW}[5/10] Instalando Leaflet no frontend...${NC}"
cd "$PMD_DIR"
npm install leaflet --save --legacy-peer-deps || npm install leaflet --save
npm install @types/leaflet --save-dev --legacy-peer-deps || npm install @types/leaflet --save-dev || true

# 8. Atualizar index.html (Remover Google Maps / Injetar Leaflet CSS)
echo -e "${YELLOW}[6/10] Atualizando index.html...${NC}"
if [[ -f "index.html" ]]; then
    sed -i '/maps.googleapis.com/d' index.html
    if ! grep -q "leaflet.css" index.html; then
        sed -i '/<\/head>/i \    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="" />' index.html
    fi
fi

# 9. Atualizar componentes Vue
echo -e "${YELLOW}[7/10] Atualizando componentes Vue (InputPostalCode, AddressFields, Maps, Markers)...${NC}"
mkdir -p resources/ts/components/maps resources/ts/components/form

# 9.1 InputPostalCode.vue (ViaCEP + BrasilAPI + fallback)
cat << 'VUE_CEP' > resources/ts/components/form/InputPostalCode.vue
<template>
  <div class="input-group">
    <input
      v-mask="mask"
      v-bind="$attrs"
      :autocomplete="unique"
      class="form-control"
      type="tel"
      placeholder="00000-000"
      @keydown.enter.prevent.stop="search"
    />
    <div class="input-group-append">
      <x-btn
        label="Buscar"
        color="primary"
        class="flex-row"
        style="border-top-left-radius: 0px; border-bottom-left-radius: 0px"
        no-caps
        no-wrap
        :loading="loading"
        loading-normal
        @click="search"
      />
    </div>
  </div>
</template>

<script lang="ts">
import { PropType, computed, defineComponent, ref } from 'vue';
import XBtn from '@/components/elements/buttons/XBtn.vue';
import axios from 'axios';
import { mask } from 'vue-the-mask';
import { useGeneralStore } from '@/store/general';

export default defineComponent({
  components: {
    XBtn,
  },
  directives: {
    mask,
  },
  props: {
    unique: {
      type: String as PropType<string>,
      default: null,
    },
  },
  emits: ['change:address', 'notFound'],
  setup(props, { attrs, emit }) {
    const store = useGeneralStore();
    const mask = ref('#####-###');
    const loading = ref(false);

    const onlyNumbers = computed(() => {
      const rawCep = (attrs.cep as string) || '';
      return rawCep.replace(/\D/g, '');
    });

    const search = async () => {
      const cep = onlyNumbers.value;
      if (cep.length < 8) return;

      loading.value = true;

      try {
        const res = await axios.get(`https://viacep.com.br/ws/${cep}/json/`);
        if (!res.data.erro) {
          emit('change:address', res.data);
          loading.value = false;
          return;
        }
      } catch (e) {}

      try {
        const resBrasil = await axios.get(`https://brasilapi.com.br/api/cep/v1/${cep}`);
        if (resBrasil.data) {
          emit('change:address', {
            logradouro: resBrasil.data.street || '',
            complemento: '',
            bairro: resBrasil.data.neighborhood || '',
            localidade: resBrasil.data.city || store.entity.city,
            uf: resBrasil.data.state || store.entity.state,
            ibge: '2704104',
          });
          loading.value = false;
          return;
        }
      } catch (e) {}

      emit('change:address', {
        logradouro: '',
        complemento: '',
        bairro: '',
        localidade: store.entity.city || 'Lagoa da Canoa',
        uf: store.entity.state || 'AL',
        ibge: '2704104',
      });

      loading.value = false;
    };

    return {
      mask,
      loading,
      search,
      onlyNumbers,
    };
  },
});
</script>
VUE_CEP

# 9.2 AddressFields.vue (Nominatim + Coordenadas padrão)
cat << 'VUE_ADDR' > resources/ts/components/form/AddressFields.vue
<template>
  <div class="row">
    <x-field
      ref="cityPostalCode"
      v-model="modelData.postalCode"
      rules="required|postal_code"
      container-class="form-group col-sm-6"
      label="CEP"
      :name="`${name}.postalCode`"
      type="CEP"
      :errors="checkError('postalCode')"
      @change:address="updateAddress"
    />
    <x-field
      v-model="modelData.address"
      rules="required"
      container-class="form-group col-sm-9"
      label="Endereço"
      :name="`${name}.address`"
      type="TEXT"
      :errors="checkError('address')"
      :disabled="!canEditAddress"
      @blur="updateLatLng"
    />
    <x-field
      ref="addressNumber"
      v-model="modelData.number"
      rules="required"
      container-class="form-group col-sm-3"
      label="Número"
      :name="`${name}.number`"
      type="TEXT"
      :errors="checkError('number')"
      :disabled="!canEditAddress"
      :loading="modelFetchingAddressLatLng"
      @blur="updateLatLng"
    />
    <x-field
      v-model="modelData.complement"
      container-class="form-group col-sm-6"
      label="Complemento"
      :name="`${name}.complement`"
      type="TEXT"
      :errors="checkError('complement')"
      :disabled="!canEditAddress"
    />
    <x-field
      v-model="modelData.neighborhood"
      rules="required"
      container-class="form-group col-sm-6"
      label="Bairro"
      :name="`${name}.neighborhood`"
      type="TEXT"
      :errors="checkError('neighborhood')"
      :disabled="!canEditAddress"
    />
  </div>
</template>

<script setup lang="ts">
import { Address } from '@/types';
import { computed, ref } from 'vue';
import XField from '@/components/x-form/XField.vue';
import { useGeneralStore } from '@/store/general';
import { useVModel } from '@vueuse/core';

defineEmits<{
  (action: 'update:fetchingAddressLatLng', payload: boolean): void;
  (action: 'update:fetchingPrimaryAddressLatLng', payload: boolean): void;
}>();

const props = withDefaults(
  defineProps<{
    data: Address;
    name: string;
    setFieldValue: (name: string, value: number | string) => void;
    errors: { [key: string]: boolean };
    fetchingAddressLatLng: boolean;
  }>(),
  {
    data: () => ({} as Address),
    name: '',
    errors: () => ({}),
    fetchingAddressLatLng: false,
  }
);

const store = useGeneralStore();
const cityPostalCode = ref();
const lastAddress = ref<string>();
const lastNumber = ref<string>();

const modelData = useVModel(props, 'data');
const modelFetchingAddressLatLng = useVModel(props, 'fetchingAddressLatLng');

const getDefaultLat = () => Number(window.config?.map?.lat) || -9.8294;
const getDefaultLng = () => Number(window.config?.map?.lng) || -36.7867;

const isCityPostalCode = () => {
  const codes = store.entity.ibgeCodes;
  if (codes.length === 0) return true;
  return codes.includes(modelData.value.cityIbgeCode) || modelData.value.city === window.config.city;
};

const canEditAddress = computed(() => modelData.value.city && isCityPostalCode());

const updateAddress = (data: any) => {
  modelData.value.address = data.logradouro || '';
  modelData.value.complement = data.complemento || '';
  modelData.value.neighborhood = data.bairro || '';
  modelData.value.city = data.localidade || store.entity.city;
  modelData.value.stateAbbreviation = data.uf || store.entity.state;
  modelData.value.cityIbgeCode = Number(data.ibge) || 2704104;

  props.setFieldValue(`${props.name}.city`, modelData.value.city);
  props.setFieldValue(`${props.name}.stateAbbreviation`, modelData.value.stateAbbreviation);
  props.setFieldValue(`${props.name}.cityIbgeCode`, modelData.value.cityIbgeCode);

  if (!modelData.value.lat || !modelData.value.lng) {
    modelData.value.lat = getDefaultLat();
    modelData.value.lng = getDefaultLng();
    props.setFieldValue(`${props.name}.lat`, modelData.value.lat);
    props.setFieldValue(`${props.name}.lng`, modelData.value.lng);
  }

  if (!isCityPostalCode() && cityPostalCode.value) {
    cityPostalCode.value.$refs.validator.setErrors(['O CEP deve ser do município']);
  } else {
    setTimeout(() => {
      const inputs = document.getElementsByName(`${props.name}.number`);
      if (inputs.length > 0) inputs[inputs.length - 1].focus();
    }, 100);
  }
};

const intervalLatLng = ref();
const updateLatLng = () => {
  clearInterval(intervalLatLng.value);
  if (modelData.value.address === lastAddress.value && modelData.value.number === lastNumber.value) return;

  intervalLatLng.value = setTimeout(async () => {
    if (!modelData.value.address || !modelData.value.city) return;
    modelFetchingAddressLatLng.value = true;

    try {
      const query = encodeURIComponent(
        `${modelData.value.address}, ${modelData.value.number || ''}, ${modelData.value.neighborhood || ''}, ${modelData.value.city}, ${modelData.value.stateAbbreviation || ''}, Brasil`
      );
      const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${query}&limit=1`);
      const data = await res.json();
      if (data && data.length > 0) {
        modelData.value.lat = parseFloat(data[0].lat);
        modelData.value.lng = parseFloat(data[0].lon);
      } else {
        modelData.value.lat = getDefaultLat();
        modelData.value.lng = getDefaultLng();
      }
    } catch {
      modelData.value.lat = getDefaultLat();
      modelData.value.lng = getDefaultLng();
    }

    props.setFieldValue(`${props.name}.lat`, modelData.value.lat as number);
    props.setFieldValue(`${props.name}.lng`, modelData.value.lng as number);
    lastAddress.value = modelData.value.address;
    lastNumber.value = modelData.value.number;
    modelFetchingAddressLatLng.value = false;
  }, 500);
};

const checkError = (name: string) => Boolean(props.errors[`${name}.postalCode` as keyof typeof props.errors]);
</script>
VUE_ADDR

# 9.3 GoogleMaps.vue (Leaflet)
cat << 'VUE_MAP' > resources/ts/components/maps/GoogleMaps.vue
<template>
  <div class="google-map">
    <div ref="mapContainer" class="google-map-container" style="width: 100%; height: 100%; min-height: 350px;"></div>
    <slot v-if="mapInstance" :map="mapInstance"></slot>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, toRefs, onBeforeUnmount } from 'vue';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

const props = withDefaults(
  defineProps<{
    lat?: number;
    lng?: number;
    zoom?: number;
    config?: Record<string, any>;
  }>(),
  {
    lat: -9.8294,
    lng: -36.7867,
    zoom: 14,
    config: () => ({}),
  }
);

const { lat, lng, zoom } = toRefs(props);
const mapContainer = ref<HTMLElement | null>(null);
const mapInstance = ref<L.Map | null>(null);

const initMap = () => {
  if (!mapContainer.value) return;
  const validLat = Number(lat.value) || -9.8294;
  const validLng = Number(lng.value) || -36.7867;

  mapInstance.value = L.map(mapContainer.value, {
    center: [validLat, validLng],
    zoom: zoom.value || 14,
  });

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors',
    maxZoom: 19,
  }).addTo(mapInstance.value);
};

watch([lat, lng], ([newLat, newLng]) => {
  if (mapInstance.value && newLat && newLng) {
    mapInstance.value.setView([Number(newLat), Number(newLng)], zoom.value);
  }
});

onMounted(() => {
  initMap();
  setTimeout(() => {
    mapInstance.value?.invalidateSize();
  }, 200);
});

onBeforeUnmount(() => {
  mapInstance.value?.remove();
});
</script>

<style scoped>
.google-map, .google-map-container {
  width: 100%;
  height: 100%;
  min-height: 350px;
  border-radius: 8px;
}
</style>
VUE_MAP

# 9.4 GoogleMapsMarker.vue (Leaflet + Popup com Nome e Telefone da Escola)
cat << 'VUE_MARKER' > resources/ts/components/maps/GoogleMapsMarker.vue
<template>
  <div ref="popupContent" style="display: none;">
    <slot></slot>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onBeforeUnmount, watch, ref, nextTick } from 'vue';
import L from 'leaflet';

const props = withDefaults(
  defineProps<{
    map: L.Map;
    marker: {
      id?: string | number;
      name?: string;
      position?: { lat: number; lng: number };
      title?: string;
      config?: Record<string, any>;
    };
    draggable?: boolean;
  }>(),
  {
    draggable: false,
  }
);

const emit = defineEmits<{
  (e: 'new-position', position: { lat: number; lng: number }): void;
  (e: 'click', marker: any): void;
}>();

const markerInstance = ref<L.Marker | null>(null);
const popupContent = ref<HTMLElement | null>(null);

const setVisible = (visible: boolean) => {
  if (markerInstance.value) {
    markerInstance.value.setOpacity(visible ? 1 : 0);
  }
};

const setPosition = (pos: { lat: number; lng: number }) => {
  if (markerInstance.value && pos?.lat && pos?.lng) {
    markerInstance.value.setLatLng([Number(pos.lat), Number(pos.lng)]);
  }
};

onMounted(async () => {
  if (!props.map || !props.marker?.position) return;
  const { lat, lng } = props.marker.position;
  if (!lat || !lng) return;

  const icon = L.icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png',
    shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34],
    shadowSize: [41, 41],
  });

  markerInstance.value = L.marker([Number(lat), Number(lng)], {
    draggable: props.draggable,
    icon,
  }).addTo(props.map);

  await nextTick();

  if (popupContent.value && popupContent.value.innerHTML.trim().length > 0) {
    markerInstance.value.bindPopup(popupContent.value.innerHTML);
  } else if (props.marker.name || props.marker.title) {
    markerInstance.value.bindPopup(`<b>${props.marker.name || props.marker.title}</b>`);
  }

  markerInstance.value.on('dragend', () => {
    if (markerInstance.value) {
      const pos = markerInstance.value.getLatLng();
      emit('new-position', { lat: pos.lat, lng: pos.lng });
    }
  });

  markerInstance.value.on('click', () => {
    emit('click', props.marker);
  });

  if (props.draggable) {
    props.map.on('click', (e: L.LeafletMouseEvent) => {
      markerInstance.value?.setLatLng(e.latlng);
      emit('new-position', { lat: e.latlng.lat, lng: e.latlng.lng });
    });
  }
});

watch(
  () => props.marker?.position,
  (newPos) => {
    if (newPos?.lat && newPos?.lng) {
      setPosition(newPos);
    }
  },
  { deep: true }
);

onBeforeUnmount(() => {
  if (markerInstance.value && props.map) {
    props.map.removeLayer(markerInstance.value);
  }
});

defineExpose({
  internalMarker: {
    setVisible,
    setPosition,
  },
  marker: props.marker,
});
</script>
VUE_MARKER

# 10. Compilar Frontend com Vite
echo -e "${YELLOW}[8/10] Compilando assets do frontend (npm run build)...${NC}"
npm run build

# 11. Links Simbólicos, Permissões e Cache
echo -e "${YELLOW}[9/10] Ajustando links simbólicos e permissões...${NC}"
mkdir -p "$IEDUCAR_DIR/public"
ln -sfn "$PMD_DIR/dist" "$IEDUCAR_DIR/public/pre-matricula-digital"
ln -sfn "$PMD_DIR/dist/assets" "$IEDUCAR_DIR/public/assets"

chown -R "${WEB_USER}:${WEB_GROUP}" "$PMD_DIR/dist"
chmod -R 755 "$PMD_DIR/dist"
chown -h "${WEB_USER}:${WEB_GROUP}" "$IEDUCAR_DIR/public/pre-matricula-digital"
chown -h "${WEB_USER}:${WEB_GROUP}" "$IEDUCAR_DIR/public/assets"

echo -e "${YELLOW}[10/10] Limpando caches do Laravel e reiniciando PHP-FPM...${NC}"
cd "$IEDUCAR_DIR"
if [[ -f "$IEDUCAR_DIR/artisan" ]]; then
    php artisan view:clear >/dev/null 2>&1 || true
    php artisan route:clear >/dev/null 2>&1 || true
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan cache:clear >/dev/null 2>&1 || true
fi

systemctl restart php*-fpm 2>/dev/null || service php*-fpm restart 2>/dev/null || true

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}  MIGRAÇÃO E CONFIGURAÇÃO DO PMD CONCLUÍDAS COM SUCESSO!             ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "Conferindo configuração ativa do mapa:"
curl -s http://127.0.0.1/config/prematricula.js | grep -o '"map":{[^}]*}' || true
echo ""
