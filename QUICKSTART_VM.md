# Quick Start - Deploy na VM

Guia rápido para fazer o primeiro deploy.

## Pré-requisitos

- [x] Terraform aplicado (infraestrutura criada)
- [x] DNS configurado (3 registros A apontando para Load Balancer)
- [ ] VM configurada
- [ ] .env criado na VM
- [ ] Auto-deploy habilitado

## Passo 1: SSH na VM

```bash
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
```

## Passo 2: Instalar Docker

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER
sudo mkdir -p /data/smae
sudo chown $USER:$USER /data/smae

# Logout e login novamente
exit
```

## Passo 3: SSH de Volta e Clonar Repo

```bash
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

git clone https://github.com/ajulabs/smae.git ~/smae
cd ~/smae
```

## Passo 4: Criar .env

```bash
cp .env.production.example .env
nano .env
```

**Valores CRÍTICOS para atualizar**:

```bash
# URLs dos subdomínios (OBRIGATÓRIO!)
API_HOST_NAME="api.smae.e-siri.com"
VITE_API_URL="https://api.smae.e-siri.com"
MB_SITE_URL="https://metadb.smae.e-siri.com"
URL_LOGIN_SMAE="https://smae.e-siri.com/login"

# Binding (sem Nginx!)
BIND_INTERFACE=""

# Senhas fortes (gerar com: openssl rand -base64 32)
POSTGRES_PASSWORD="<senha-forte-aqui>"
MB_DB_PASS="<senha-forte-aqui>"
MINIO_ROOT_PASSWORD="<senha-forte-aqui>"
SESSION_JWT_SECRET="<secret-forte-aqui>"
S3_ACCESS_KEY="$(openssl rand -hex 20)"
S3_SECRET_KEY="$(openssl rand -base64 32)"

# Chave de criptografia (manter a do exemplo ou gerar nova)
PRISMA_FIELD_ENCRYPTION_KEY="k1.aesgcm256.MPBhYm__Oq37S3kzmQeh0kRuKrF0WRveaQ_aSMbhQbE="

# Database
POSTGRES_USER="smae"
POSTGRES_DB="smae_production"

# MinIO
MINIO_ROOT_USER="admin_prod"

# Path
DATA_PATH="/data/smae"
```

Salvar e sair (Ctrl+X, Y, Enter).

## Passo 5: Fazer Deploy Manual (Primeira Vez)

```bash
cd ~/smae

# Deploy inicial (vai buildar as imagens - demora 15-20 min)
bash scripts/deploy.sh

# Acompanhar logs
docker compose -f docker-compose.production.yml logs -f
```

## Passo 6: Habilitar Auto-Deploy

```bash
cd ~/smae

# Configurar cron job (polling a cada 5 minutos)
bash scripts/setup-auto-deploy.sh
```

## Passo 7: Testar Auto-Deploy

```bash
# Na sua máquina local, fazer uma mudança qualquer
echo "# Test" >> README.md
git commit -am "Test auto-deploy"
git push origin master

# Na VM, monitorar logs
tail -f ~/smae/auto-deploy.log

# Em até 5 minutos, você verá:
# [timestamp] NEW COMMITS DETECTED
# [timestamp] Starting deployment...
# [timestamp] ✅ DEPLOYMENT SUCCESSFUL
```

## Verificar Aplicação

Após SSL certificate estar ACTIVE (30-60 min após DNS):

```bash
curl https://smae.e-siri.com
curl https://api.smae.e-siri.com/api/ping
curl https://metadb.smae.e-siri.com/api/health
```

## Comandos Úteis

```bash
# Ver logs de deployment
tail -f ~/smae/auto-deploy.log

# Ver containers
docker ps

# Restart um serviço
docker compose -f ~/smae/docker-compose.production.yml restart smae_api

# Deploy manual
cd ~/smae && bash scripts/deploy.sh

# Health check
bash ~/smae/scripts/health-check.sh

# Ver cron job
crontab -l

# Desabilitar auto-deploy temporariamente
crontab -e  # Comentar a linha do check-and-deploy.sh
```

## Atualizar .env

```bash
# SSH na VM
cd ~/smae
nano .env

# Após salvar, restart os serviços
docker compose -f docker-compose.production.yml restart
```

## Troubleshooting

### Build falha por falta de espaço

```bash
# Limpar imagens antigas
docker system prune -a -f

# Ver uso de disco
df -h
docker system df
```

### Deployment não está rodando

```bash
# Verificar cron
crontab -l

# Ver logs
tail -100 ~/smae/auto-deploy.log

# Testar manualmente
bash ~/smae/scripts/check-and-deploy.sh
```

### Serviço não inicia

```bash
# Ver logs do serviço
docker compose -f ~/smae/docker-compose.production.yml logs smae_api

# Verificar .env
cat ~/smae/.env | grep -E "DATABASE_URL|API_HOST_NAME"

# Restart
docker compose -f ~/smae/docker-compose.production.yml restart
```

---

**Tempo total de setup**: ~30-40 minutos

**Deploy automático**: Habilitado! ✅
