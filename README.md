# 🛡️ Automação de Backups: i-Educar & i-Diário -> MinIO

Sistema completo e automatizado para backup periódico do **i-Educar** e **i-Diário** (PostgreSQL + Arquivos de Uploads/Storage) com armazenamento seguro em instância **MinIO** (`minio.RELEASE.2025-09-07T16-13-09Z`), agendamento via **Cron (diariamente às 23:59)**, sincronização pré-backup e **política de retenção automática de 20 dias**.

---

## 🚀 Instalação Rápida (Comando Único via Curl)

Para instalar e configurar todo o ambiente na sua VPS com apenas um comando, acesse o terminal como `root` e execute:

```bash
curl -fsSL https://raw.githubusercontent.com/douglas14031999/ieducar-idiario-backup/main/install.sh | bash
```

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

### 1. Executar Backup Manual Imediato
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
