# 🛡️ Automação de Backups: i-Educar & i-Diário -> MinIO

Sistema completo e automatizado para backup periódico do **i-Educar** e **i-Diário** (PostgreSQL + Arquivos de Uploads/Storage) com armazenamento seguro em instância **MinIO** (`minio.RELEASE.2025-09-07T16-13-09Z`), agendamento via **Cron (diariamente às 23:59)**, sincronização pré-backup e **política de retenção automática de 20 dias**.

---

## 🚀 Instalação Rápida e Central de Automação (Menu Interativo)

Para acessar o painel de ferramentas completo na sua VPS com apenas um comando, execute como `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/douglas14031999/ieducar-idiario-backup/main/install.sh | bash
```

Ao executar, o script abre uma **Central Interativa** no terminal, organizada na ordem cronológica recomendada de execução:
- `[1]` ⚡ **Configurar Memória SWAP (Desempenho da VPS)**
- `[2]` 🚀 **Instalar i-Educar (Gestão Escolar)**
- `[3]` 📓 **Instalar i-Diário (Diário do Professor)**
- `[4]` 🔒 **Configurar Domínios & Certificados SSL HTTPS**
- `[5]` 🛠️ **Corrigir Ativos HTTPS & Estilos CSS (i-Educar)**
- `[6]` 🧬 **Popular Banco de Dados (30 Seeders Censo 2026)**
- `[7]` 📦 **Instalar / Atualizar Pacote Educacenso (2024 a 2026)**
- `[8]` 📦 **Instalar Pacote Completo de Relatórios i-Educar (v2.11)**
- `[9]` 🛠️ **Correção Geral de Relatórios (136 Templates Jasper & Menus 404)**
- `[10]` 🔍 **Corrigir Busca Sem Acento, Notificações & PMD (i-Educar)**
- `[11]` 🗺️ **Migrar Mapas PMD (Pré-Matrícula OpenStreetMap)**
- `[12]` 🎨 **Configurar Atalhos Rápidos (Dashboard do i-Educar)**
- `[13]` 💡 **Instalar Widget Menu de Ajuda Oficial (i-Educar)**
- `[14]` 🖼️ **Aplicar Tema Moderno de Login (i-Educar - Canoa 2026)**
- `[15]` 📑 **Instalar Diário de Classe Unificado (i-Diário)**
- `[16]` 👤 **Corrigir Foto de Perfil & Menu (i-Diário)**
- `[17]` 🎨 **Aplicar Tema Moderno de Login (i-Diário - Canoa 2026)**
- `[18]` 🎯 **Instalar Gabarito OMR de Provas (Leitura Automática)**
- `[19]` 🛡️ **Configurar Backups Automáticos (MinIO S3 & Cron)**
- `[20]` 💾 **Executar Backup Manual Completo Agora**
- `[21]` 🔄 **Restaurar Backup do MinIO (Assistente / Recuperação)**
- `[0]` 🚪 **Sair**

> 💡 *Após cada ação concluída, o script retorna automaticamente à tela inicial para que você possa efetuar outras operações sem precisar reiniciá-lo.*

---

## 🔄 Como Atualizar a Instalação Existente

Se você já instalou e deseja atualizar os scripts para a versão mais recente sem perder suas credenciais (`.env` mantido intacto):

### Opção 1: Atualização Direta via Curl (Recomendado)
```bash
curl -fsSL https://raw.githubusercontent.com/douglas14031999/ieducar-idiario-backup/main/install.sh | bash
```

### Opção 2: Atualização Rápida via Git
```bash
cd /opt/ieducar-backup && git pull origin main
```

---

## ✨ Recursos

- 📦 **Suporte Híbrido:** Detecta automaticamente se o banco de dados está rodando em **Docker** (containers) ou de forma **Bare-metal** (instalado diretamente no sistema operacional).
- 🗄️ **MinIO Server 2025 Dedicado:** Instala e configura a versão oficial `RELEASE.2025-09-07T16-13-09Z` gerenciada como serviço `systemd`, com API na porta `9000` e Console Web na porta `9001`.
- 🔄 **Sincronização Pré-Backup:** Dispara a sincronização entre **i-Diário** e **i-Educar** (`rake ieducar_api:synchronize`) antes dos dumps, garantindo que os diários de classe e notas mais recentes estejam consolidados.
- ⚡ **Otimização de SWAP Inteligente:** Detecta automaticamente se o servidor possui swap e oferece a criação de 4GB com `vm.swappiness=10`, evitando travamentos por esgotamento de memória no PostgreSQL e Rails.
- ⏰ **Agendamento no Cron:** Configurado para rodar todos os dias às **23:59** sem interrupção dos serviços letivos.
- 🧹 **Retenção Automática de 20 Dias:** Remove arquivos temporários e expurga backups antigos (> 20 dias) do MinIO e do disco local automaticamente.
- 🔐 **Repositório 100% Seguro para GitHub Público:** Nenhuma senha ou segredo fica gravado no código. A configuração é gerada em `/etc/ieducar-backup/.env` com permissão estrita `chmod 600`.
- 🚀 **Instalador Completo i-Educar + Todos os Módulos:** Instalação automatizada fim a fim do Core 2.10, PostgreSQL, Composer, Nginx, PHP 8.4, JasperStarter/Relatórios, Biblioteca, Educacenso, Transporte Escolar e Pré-Matrícula Digital (`ieducar-install`).
- 📓 **Instalador Completo i-Diário (Rails):** Instalação automatizada do i-Diário com Ruby 2.6.6 compilado via rbenv + OpenSSL 1.1.1 dedicado, PostgreSQL, Redis, Sidekiq e serviços Systemd (`idiario-install`).
- 🔄 **Assistente de Restauração (Disaster Recovery):** Utilitário prático para baixar e restaurar bancos e arquivos do MinIO em caso de emergência (`ieducar-restore`).
- 🎨 **Painel de Atalhos Rápidos (Opcional):** Transforma a tela inicial do i-Educar com 5 cards modernos de navegação direta (Alunos, Servidores, Relatórios por Turma, Boletim e Histórico Escolar). Perguntado na instalação ou ativável via comando `ieducar-dashboard`.
- 🧬 **Povoamento Inicial do Banco (Opcional):** Conjunto de 24 seeders essenciais (Deficiências, Raças, Escolaridade Educacenso, Funções, Módulos, Regimes, Níveis de Ensino, Situações de Matrícula, etc.). Perguntado na instalação ou via comando `ieducar-seed`.
- 🗺️ **Migração PMD Leaflet (Opcional):** Migra a Pré-Matrícula Digital do Google Maps para Leaflet + OpenStreetMap sem custo de API (`ieducar-pmd`).
- 👤 **Correção de Foto & Menu no i-Diário (Opcional):** Corrige o envio/corte de foto de perfil (Cropper JS), ImageMagick, rotas de upload e ativa atalhos no secrets.yml (`idiario-perfil`).
- 📑 **Diário de Classe Escolar Unificado (i-Diário):** Emite em um único PDF mesclado a Capa Oficial, Frequência, Notas, Avaliações Descritivas/Pareceres, Conteúdos, Observações e 2ª assinatura (`idiario-diario-unificado`).
- 🎯 **Gabarito OMR & Elaborador de Provas (BNCC):** Sistema autohospedável para elaboração de avaliações, geração de folhas de respostas em PDF e correção instantânea por visão computacional via smartphone (`omr-install`).
- 🔒 **Configuração Automática de Domínio & SSL HTTPS (Let's Encrypt):** Permite informar apenas os domínios apontados para a VPS. O script configura automaticamente os blocos do Nginx, emite certificados SSL com renovação automática (Certbot) e, no **i-Diário**, substitui automaticamente o IP na tabela `entities` do PostgreSQL pelo novo domínio (`ieducar-ssl`).
- 📦 **Módulo Educacenso 2024 / 2025 / 2026 (Douglas):** Instalação e atualização inteligente com suporte aos Censos 2024, 2025 e 2026, correções de integridade de dados (vínculo de servidores, turnos e alocações), auto-descoberta no Composer, migrations e menu de importação (`ieducar-educacenso`).
- 🖼️ **Tema de Login Moderno (i-Educar Canoa 2026):** Redesign completo da tela de login com Glassmorphism, ondas orgânicas, paleta oficial da Prefeitura de Lagoa da Canoa, preservando 100% dos dados dinâmicos, tokens de autenticação, CSRF, GTM e reCAPTCHA (`ieducar-login-theme`).
- 🔍 **Busca Sem Acento (unaccent), Notificações & PMD (i-Educar):** Habilita extensão unaccent no PostgreSQL, resolve busca do menu, zera falso contador de notificações e elimina tela branca na Pré-Matrícula Digital (`ieducar-fix-search`).
- 🛠️ **Correção Geral de Relatórios & Menus (Douglas 2.11):** Compila e repara todos os 136 templates Jasper, remove menus 404 quebrados, instala dependências (Java JRE e Headless Chrome) e ajusta permissões (`ieducar-reports-all`).
- 📦 **Instalador Completo do Pacote de Relatórios (v2.11):** Substitui o pacote padrão, executa composer, compila templates e publica assets oficiais (`ieducar-reports-install`).
- 💡 **Widget Menu de Ajuda Oficial (i-Educar):** Central interativa de documentação, manual do usuário com 76 telas oficiais, atalhos rápidos e suporte contextual integrado diretamente ao layout Blade do i-Educar (`ieducar-help-widget`).
- 🎨 **Tema Moderno de Login para o i-Diário (Canoa 2026):** Redesign completo da autenticação do i-Diário com identidade visual de Lagoa da Canoa, SVG animado e compatibilidade com Devise (`idiario-login`).
- 🔔 **Notificações:** Suporte a webhooks de alerta no Discord e Telegram.

---

### ⚡ Scripts de Correção Rápida & Pacote de Relatórios (Branch 2.11)

| Script | Finalidade Principal | Tempo Médio | Atalho Global | Comando Direto via Curl |
|---|---|---|---|---|
| `fix_search_and_notifications.sh` | Busca sem acento (unaccent) + Notificações corrigidas + PMD (tela branca resolvida) | ~5 segundos | `ieducar-fix-search` | `curl -fsSL https://raw.githubusercontent.com/douglas14031999/i-educar-reports-package/2.11/fix_search_and_notifications.sh \| bash` |
| `fix_all.sh` | Correção Geral Completa: busca, notificações, 136 relatórios compilados, limpeza de menus 404, realocação de módulos e permissões | ~45 segundos | `ieducar-reports-all` | `curl -fsSL https://raw.githubusercontent.com/douglas14031999/i-educar-reports-package/2.11/fix_all.sh \| bash` |
| `install.sh` | Instalador Completo do Pacote: substitui pacote padrão, roda composer, compila templates e publica assets | ~60 segundos | `ieducar-reports-install` | `curl -fsSL https://raw.githubusercontent.com/douglas14031999/i-educar-reports-package/2.11/install.sh \| bash` |
| `deploy_help_widget.sh` | Central e Widget Menu de Ajuda Oficial com 76 telas e manual interativo integrado ao i-Educar | ~15 segundos | `ieducar-help-widget` | `curl -fsSL https://raw.githubusercontent.com/douglas14031999/i-educar-reports-package/2.11/deploy_help_widget.sh \| bash` |
| `deploy_login_vps.sh` | Novo Design da Tela de Login/Autenticação do i-Diário (Lagoa da Canoa) | ~10 segundos | `idiario-login` | `curl -fsSL https://raw.githubusercontent.com/douglas14031999/i-educar-reports-package/2.11/deploy_login_vps.sh \| bash` |

---

## 📂 Estrutura do Repositório

```text
├── install.sh                  # Instalador one-liner e atualizador para a VPS
├── backup-automation.md        # Planejamento e checklist do projeto
├── config/
│   └── backup.env.example      # Modelo completo de variáveis de ambiente
├── scripts/
│   ├── install-ieducar.sh      # Instalador completo automatizado do i-Educar e todos os módulos
│   ├── install-idiario.sh      # Instalador completo automatizado do i-Diário (Rails/Ruby 2.6)
│   ├── setup-idiario-class-diary.sh # Diário de Classe Escolar Unificado para o i-Diário
│   ├── setup-idiario-login-theme.sh # Aplicador do tema moderno de login do i-Diário (Canoa 2026)
│   ├── install-omr.sh          # Instalador do Gabarito OMR & Elaborador de Provas (BNCC)
│   ├── setup-domain-ssl.sh     # Automação de Nginx, SSL Certbot e migração de entidades do i-Diário
│   ├── install-educacenso.sh   # Instalador e atualizador inteligente do pacote Educacenso (2024-2026)
│   ├── fix-ieducar-https.sh    # Correção de CSS, JS e ativos HTTPS (Mixed Content) no i-Educar
│   ├── setup-login-theme.sh    # Aplicador do tema moderno de login (i-Educar Canoa 2026)
│   ├── fix-search-and-notifications.sh # Correção de busca unaccent, notificações e PMD
│   ├── fix-reports-all.sh      # Correção completa de 136 relatórios, menus e dependências
│   ├── install-reports-package.sh # Instalador do pacote completo de relatórios v2.11
│   ├── setup-help-widget.sh    # Instalador do Widget Menu de Ajuda Oficial (76 telas) no i-Educar
│   ├── backup.sh               # Script principal executado pelo cron (dumps, sync e MinIO)
│   ├── restore.sh              # Utilitário interativo de restauração
│   ├── setup-dashboard.sh      # Configurador automático da tela de atalhos rápidos do i-Educar
│   ├── seed-database-2026.sh   # Povoamento completo atualizado para o Censo 2026 (30 seeders)
│   ├── seed-database.sh        # Povoamento inicial básico do banco de dados (24 seeders)
│   ├── setup-swap.sh           # Configurador e otimizador de memória SWAP (4GB + swappiness)
│   ├── setup-pmd-leaflet.sh    # Migração do Google Maps para Leaflet + OpenStreetMap (PMD)
│   ├── setup-idiario-profile.sh # Correção de foto de perfil, cropper e menu no i-Diário
│   ├── install-minio.sh        # Instalador e configurador do MinIO Server 2025 e mc
│   └── common.sh               # Funções de logging, checagem e notificações
├── .gitignore                  # Impede upload acidental de .env, logs e backups
└── README.md                   # Documentação completa
```

---

## ⚙️ Configuração Pós-Instalação (`.env`)

O instalador cria o arquivo de configuração seguro em:
```bash
nano /etc/ieducar-backup/.env
```

Principais parâmetros:
| Parâmetro | Padrão | Descrição |
|---|---|---|
| `MINIO_ENDPOINT` | `http://127.0.0.1:9000` | Endpoint da API do MinIO |
| `MINIO_ACCESS_KEY` | `admin` | Usuário administrador do MinIO |
| `MINIO_SECRET_KEY` | `********` | Senha de acesso do MinIO |
| `MINIO_BUCKET` | `ieducar-backups` | Nome do bucket no MinIO |
| `RETENTION_DAYS` | `20` | Dias de retenção antes de expirar |
| `CRON_SCHEDULE` | `59 23 * * *` | Expressão cron de agendamento |
| `SYNC_BEFORE_BACKUP` | `true` | Executa sincronização i-Diário <-> i-Educar antes do backup |
| `IDIARIO_APP_DIR` | `/root/i-diario` | Diretório da aplicação i-Diário (Rails) |
| `IEDUCAR_MODE` | `auto` | `auto`, `docker` ou `baremetal` |
| `IEDUCAR_STORAGE_PATH` | `/var/www/ieducar/storage` | Pasta de uploads do i-Educar |
| `IDIARIO_MODE` | `auto` | `auto`, `docker` ou `baremetal` |
| `IDIARIO_DB_NAME` | `idiario_production` | Nome do banco do i-Diário |
| `IDIARIO_STORAGE_PATH` | `/var/www/idiario/public/system` | Pasta de uploads do i-Diário |

---

## 🛠️ Comandos Globais Disponíveis

Após a instalação, os seguintes comandos globais ficam disponíveis em qualquer lugar do terminal:

### 1. Central de Ferramentas e Menu Interativo
Para abrir o menu principal interativo a qualquer momento:
```bash
ieducar-menu
```

### 2. Executar Backup Manual Imediato
Para forçar a execução do backup a qualquer momento e acompanhar o log em tempo real:
```bash
ieducar-backup
```

### 3. Restaurar um Backup do MinIO
Para listar os backups disponíveis no MinIO e restaurar um banco de dados ou arquivos:
```bash
ieducar-restore
```

### 4. Verificar Logs
```bash
tail -f /var/log/ieducar-backup.log
```

### 5. Gerenciar o Serviço MinIO
```bash
systemctl status minio.service
systemctl restart minio.service
```

### 6. Configurar Painel de Atalhos Rápidos (i-Educar)
Caso não tenha instalado durante o setup inicial ou deseje reconfigurar a tela inicial com os 5 cards modernos:
```bash
ieducar-dashboard
```

### 7. Executar Povoamento Inicial do Banco (Seeders)
Para popular ou atualizar tabelas e registros essenciais do Educacenso e do i-Educar:
```bash
ieducar-seed
```

### 8. Configurar / Otimizar Memória SWAP
Para criar ou redefinir 4GB de SWAP com `vm.swappiness=10`:
```bash
ieducar-swap
```

### 9. Migrar PMD para Leaflet / OpenStreetMap
Para migrar o módulo de Pré-Matrícula Digital (se instalado) para mapas livres sem API Key do Google:
```bash
ieducar-pmd
```

### 10. Corrigir Foto de Perfil & Menu no i-Diário
Para corrigir envio de fotos de perfil, dependências do ImageMagick, rotas de upload e ativar atalhos no secrets.yml:
```bash
idiario-perfil
```

### 11. Instalar i-Educar Completo + Todos os Módulos
Para rodar a instalação do zero do Core do i-Educar com Relatórios, Biblioteca, Educacenso, Transporte e Pré-Matrícula Digital:
```bash
ieducar-install
```

### 12. Instalar i-Diário Completo (Rails)
Para instalar do zero o i-Diário com Ruby 2.6.6 compilado, PostgreSQL, Redis, Sidekiq e serviços no systemd:
```bash
idiario-install
```

### 13. Instalar Diário de Classe Escolar Unificado (i-Diário)
Para instalar o módulo de Diário de Classe Unificado com Capa Oficial, mesclagem de PDFs (qpdf), relatórios descritivos, menus e rotas:
```bash
idiario-diario-unificado
```

### 14. Instalar Gabarito OMR & Elaborador de Provas (BNCC)
Para implantar o sistema open-source de elaboração de provas, geração de folhas de respostas e correção por visão computacional (FastAPI, OpenCV, PostgreSQL e Nginx):
```bash
omr-install
```

### 15. Configurar Domínios & SSL HTTPS (i-Educar & i-Diário)
Permite vincular domínios próprios ao i-Educar e ao i-Diário com emissão automática de certificados SSL gratuitos via Let's Encrypt (Certbot), renovação automática e atualização da entidade no PostgreSQL do i-Diário:
```bash
ieducar-ssl
```

#### 📋 Guia de Apontamento de DNS Prévio:
Antes de executar o comando ou a opção `[11]` do menu, crie os registros do **Tipo A** no painel onde seu domínio é gerenciado (Cloudflare, Registro.br, Hostinger, GoDaddy, Route 53, etc.):

| Aplicação | Tipo | Host / Subdomínio | Destino (IP da VPS) |
|---|---|---|---|
| **i-Educar** | `A` | `ieducar` (ou seu subdomínio) | `<IP_PUBLICO_DA_SUA_VPS>` |
| **i-Diário** | `A` | `idiario` (ou seu subdomínio) | `<IP_PUBLICO_DA_SUA_VPS>` |

> ⚠️ **Dicas Críticas:**
> 1. **Cloudflare:** Deixe o proxy desativado (**Nuvem Cinza / DNS Only**) durante a emissão inicial para não bloquear o desafio HTTP do Certbot. Após emitir o certificado, você pode reativar a nuvem laranja com o SSL em modo *Full (Strict)*.
> 2. **Portas 80 e 443:** Devem estar abertas no firewall do servidor (UFW) e no Security Group da nuvem (AWS, Oracle Cloud, Hetzner, etc.).
> 3. **i-Diário (Banco de Dados):** O script substitui automaticamente o IP gravado na tabela `entities` do PostgreSQL pelo novo domínio HTTPS, evitando problemas de redirecionamento ou carregamento de ativos no Rails.

---

### 16. Instalar / Atualizar Módulo Educacenso (Censos 2024, 2025 e 2026 - Douglas)
Módulo desacoplado do Educacenso para o [i-Educar](https://github.com/portabilis/i-educar), com suporte aos Censos **2024**, **2025** e **2026** e correções de integridade de dados (vínculo de servidores, turnos e alocações):

```bash
ieducar-educacenso
```

Você também pode instalar ou atualizar diretamente na sua VPS com o comando one-liner:
```bash
curl -fsSL https://raw.githubusercontent.com/douglas14031999/i-educar-educacenso-package/2.12/install.sh | bash
```

**🤖 O que este script faz automaticamente:**
- **Detecção Inteligente:**
  - Se o pacote não estiver instalado: clona e configura o repositório em `packages/portabilis/i-educar-educacenso-package` (branch `2.12`).
  - Se já for o seu repositório (`douglas14031999`): realiza o `fetch`, `checkout 2.12` e `reset --hard` para a versão mais recente com atualização instantânea.
  - Se for o repositório da Portabilis ou versão legada: cria um backup de segurança (`.bak.<timestamp>`), remove a versão antiga e instala o novo repositório limpo.
- **Permissões de Arquivos:** Ajusta donos e permissões para `www-data:www-data` e `775`.
- **Autoload do Composer:** Executa `composer dump-autoload --optimize` com descoberta automática do pacote no i-Educar.
- **Banco e Menus:** Executa `php artisan migrate --force` e registra/ativa o menu **Importações -> Importação educacenso** no sistema.
- **Limpeza de Caches:** Limpa todos os caches da aplicação (`optimize:clear`, `config:clear`, `cache:clear`, `view:clear`).

---

### 17. Corrigir Carregamento HTTPS / Mixed Content (i-Educar)
Se o i-Educar carregar sem estilos (tela branca / CSS e JS bloqueados por Mixed Content) após habilitar o HTTPS:
```bash
ieducar-fix-https
```

---

### 18. Aplicar Tema Moderno de Login (Sistema Canoa 2026)
Aplica o novo design moderno com Glassmorphism, ondas orgânicas e paleta oficial da Prefeitura de Lagoa da Canoa na tela de login do i-Educar, mantendo intactos todos os recursos de autenticação do Laravel (rotas, tokens CSRF, GTM, ReCAPTCHA v3 e bloqueio contra ataques de força bruta):
```bash
ieducar-login-theme
```

---

## 🌐 Acesso ao Console Web do MinIO

Abra o seu navegador e acesse:
```text
http://<IP_DA_SUA_VPS>:9001
```
- **Access Key:** `admin` (ou a definida no instalador)
- **Secret Key:** A senha definida na instalação
- **API S3 Endpoint:** `http://<IP_DA_SUA_VPS>:9000`

> 💡 *Nota:* Certifique-se de liberar as portas **9000** e **9001** no painel de Firewall/Security Group da sua VPS caso acesse de fora da rede local.

---

## 📄 Licença

Distribuído sob a licença MIT. Consulte `LICENSE` para mais informações.
