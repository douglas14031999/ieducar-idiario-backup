# 🛡️ Automação de Backups: i-Educar & i-Diário -> MinIO

Sistema completo e automatizado para backup periódico do **i-Educar** e **i-Diário** (PostgreSQL + Arquivos de Uploads/Storage) com armazenamento seguro em instância **MinIO** (`minio.RELEASE.2025-09-07T16-13-09Z`), agendamento via **Cron (diariamente às 23:59)**, sincronização pré-backup e **política de retenção automática de 20 dias**.

---

## 🚀 Instalação Rápida e Central de Automação (Menu Interativo)

Para acessar o painel de ferramentas completo na sua VPS com apenas um comando, execute como `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/douglas14031999/ieducar-idiario-backup/main/install.sh | bash
```

Ao executar, o script abre uma **Central Interativa** no terminal, permitindo escolher facilmente o que deseja configurar:
- `[1]` 🛡️ **Configurar Backups Automáticos** (MinIO, Cron 23:59, Retenção)
- `[2]` 🧬 **Popular Banco de Dados** (24 Seeders essenciais do Educacenso)
- `[3]` 🎨 **Configurar Tela de Atalhos Rápidos** (Dashboard moderno no i-Educar)
- `[4]` ⚡ **Configurar / Otimizar Memória SWAP** (4GB + swappiness=10)
- `[5]` 🔄 **Restaurar um Backup do MinIO** (Assistente de Restauração)
- `[6]` 📦 **Executar Backup Manual Completo Agora**
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
- 🔄 **Assistente de Restauração (Disaster Recovery):** Utilitário prático para baixar e restaurar bancos e arquivos do MinIO em caso de emergência (`ieducar-restore`).
- 🎨 **Painel de Atalhos Rápidos (Opcional):** Transforma a tela inicial do i-Educar com 5 cards modernos de navegação direta (Alunos, Servidores, Relatórios por Turma, Boletim e Histórico Escolar). Perguntado na instalação ou ativável via comando `ieducar-dashboard`.
- 🧬 **Povoamento Inicial do Banco (Opcional):** Conjunto de 24 seeders essenciais (Deficiências, Raças, Escolaridade Educacenso, Funções, Módulos, Regimes, Níveis de Ensino, Situações de Matrícula, etc.). Perguntado na instalação ou via comando `ieducar-seed`.
- 🔔 **Notificações:** Suporte a webhooks de alerta no Discord e Telegram.

---

## 📂 Estrutura do Repositório

```text
├── install.sh                  # Instalador one-liner e atualizador para a VPS
├── backup-automation.md        # Planejamento e checklist do projeto
├── config/
│   └── backup.env.example      # Modelo completo de variáveis de ambiente
├── scripts/
│   ├── backup.sh               # Script principal executado pelo cron (dumps, sync e MinIO)
│   ├── restore.sh              # Utilitário interativo de restauração
│   ├── setup-dashboard.sh      # Configurador automático da tela de atalhos rápidos do i-Educar
│   ├── seed-database.sh        # Povoamento inicial automatizado do banco de dados (24 seeders)
│   ├── setup-swap.sh           # Configurador e otimizador de memória SWAP (4GB + swappiness)
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

### 2. Restaurar um Backup do MinIO
Para listar os backups disponíveis no MinIO e restaurar um banco de dados ou arquivos:
```bash
ieducar-restore
```

### 3. Verificar Logs
```bash
tail -f /var/log/ieducar-backup.log
```

### 4. Gerenciar o Serviço MinIO
```bash
systemctl status minio.service
systemctl restart minio.service
```

### 5. Configurar Painel de Atalhos Rápidos (i-Educar)
Caso não tenha instalado durante o setup inicial ou deseje reconfigurar a tela inicial com os 5 cards modernos:
```bash
ieducar-dashboard
```

### 6. Executar Povoamento Inicial do Banco (Seeders)
Para popular ou atualizar tabelas e registros essenciais do Educacenso e do i-Educar:
```bash
ieducar-seed
```

### 7. Configurar / Otimizar Memória SWAP
Para criar ou redefinir 4GB de SWAP com `vm.swappiness=10`:
```bash
ieducar-swap
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
