# Plano de Implementação - Automação de Backups i-Educar & i-Diário com MinIO

> **Data:** 2026-10-01  
> **Objetivo:** Criar um repositório público completo com scripts e instalador via `curl` para backup automatizado (diário às 23:59, retenção de 20 dias) do i-Educar e i-Diário, com envio para o MinIO (`RELEASE.2021-04-22T15-44-28Z`) na VPS.

---

## 📋 Lista de Tarefas

### Fase 1: Arquitetura e Configuração Segura
- [x] **Tarefa 1.1:** Criar `.gitignore` rigoroso (ignorando `.env`, arquivos de dump `.sql`, `.gz`, logs, etc.) para garantir segurança em repositório público.
- [x] **Tarefa 1.2:** Criar template `config/backup.env.example` com todas as variáveis parametrizadas (MinIO, PostgreSQL, caminhos de uploads, horário do cron, dias de retenção, Discord/Telegram webhook opcional).

### Fase 2: Instalação e Configuração do MinIO
- [x] **Tarefa 2.1:** Criar `scripts/install-minio.sh` que faz o download da versão binária `minio.RELEASE.2021-04-22T15-44-28Z`, instala o MinIO Client (`mc`), cria o usuário de sistema `minio-user`, configura a escuta em `0.0.0.0:9000`, e habilita o serviço no `systemd`.

### Fase 3: Script Central de Backup e Retenção
- [x] **Tarefa 3.1:** Criar `scripts/common.sh` com funções auxiliares de log colorido, leitura segura do `.env` e checagem de integridade de disco/ferramentas.
- [x] **Tarefa 3.2:** Criar `scripts/backup.sh` com suporte híbrido (Docker e Bare-metal):
  - Dumps gzipados do PostgreSQL (i-Educar e i-Diário).
  - Compactação de arquivos estáticos/uploads.
  - Upload para o bucket do MinIO via `mc`.
  - Limpeza de arquivos temporários e expiração de backups antigos (> 20 dias) no MinIO e localmente.
  - Notificação de status/erro.

### Fase 4: Script de Restauração (Disaster Recovery)
- [x] **Tarefa 4.1:** Criar `scripts/restore.sh` para facilitar o download do backup do MinIO e restauração de emergência dos bancos e arquivos.

### Fase 5: Instalador Automatizado (One-Liner via Curl) e Documentação
- [x] **Tarefa 5.1:** Criar `install.sh` que pode ser executado via `curl -fsSL <url> | bash`, configurando dependências, diretórios, serviço MinIO, crontab em `/etc/cron.d/` e prompt amigável para preencher o `.env`.
- [x] **Tarefa 5.2:** Criar `README.md` completo em Markdown com instruções claras de instalação em comando único, personalização, restauração e comandos úteis.

### Fase 6: Verificação e Validação
- [x] **Tarefa 6.1:** Validar sintaxe dos scripts Shell (`bash -n`), permissões de execução e consistência das variáveis.
