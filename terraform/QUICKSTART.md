# SMAE Terraform - Quick Start Guide

Fast deployment guide for experienced users. See [README.md](README.md) for detailed documentation.

## Prerequisites Checklist

- [ ] GCP account with billing enabled
- [ ] Terraform >= 1.5 installed
- [ ] gcloud CLI installed and configured
- [ ] Domain name ready (smae.e-siri.com)
- [ ] GCP APIs enabled (compute, iap, logging, monitoring)

## Deployment Steps

### 1. Authenticate (2 min)

```bash
gcloud auth login
gcloud config set project stoked-coder-451819-v9
gcloud auth application-default login
```

### 2. Configure Terraform (3 min)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed (defaults are set for your project)
```

### 3. Deploy Infrastructure (5 min + 30-60 min for SSL)

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

**Save outputs:**
```bash
terraform output > ../deployment-outputs.txt
```

### 4. Configure DNS (5 min)

Get Load Balancer IP:
```bash
terraform output load_balancer_ip
```

Create 3 DNS A records (all pointing to the same IP):
- Host: `smae.e-siri.com` → Type: `A` → Value: `<load_balancer_ip>` → TTL: `300`
- Host: `api.smae.e-siri.com` → Type: `A` → Value: `<load_balancer_ip>` → TTL: `300`
- Host: `metadb.smae.e-siri.com` → Type: `A` → Value: `<load_balancer_ip>` → TTL: `300`

### 5. Setup VM (20 min)

```bash
# SSH into VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Install dependencies (NO NGINX NEEDED!)
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER
sudo mkdir -p /data/smae && sudo chown $USER:$USER /data/smae

# Logout and login again
exit
```

### 6. Configure Application (5 min)

```bash
# SSH back in
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Clone and configure
git clone https://github.com/AppCivico/smae.git
cd smae
cp .env.production.example .env

# CRITICAL: Edit .env and change ALL passwords and secrets
nano .env
```

**Must change in .env:**
- `BIND_INTERFACE=""` (public services bind to all interfaces)
- `POSTGRES_PASSWORD`
- `MB_DB_PASS`
- `MINIO_ROOT_PASSWORD`
- `SESSION_JWT_SECRET`
- `PRISMA_FIELD_ENCRYPTION_KEY`
- `S3_ACCESS_KEY` / `S3_SECRET_KEY`
- `MINIO_ROOT_USER`
- `API_HOST_NAME="api.smae.e-siri.com"`
- `VITE_API_URL="https://api.smae.e-siri.com"`
- `MB_SITE_URL="https://metadb.smae.e-siri.com"`

### 7. Start Application (5 min - No Nginx Needed!)

```bash
cd ~/smae
docker compose --profile fullStack up -d
docker compose logs -f
```

### 8. Verify Deployment (After SSL provisions)

Wait 30-60 minutes, then:

```bash
# Check SSL certificate
gcloud compute ssl-certificates describe siris-ssl-cert --global

# Test all services
curl https://smae.e-siri.com  # Frontend
curl https://api.smae.e-siri.com/api/ping  # API
curl https://metadb.smae.e-siri.com/api/health  # Metabase
```

## Post-Deployment

### Setup MinIO

```bash
# Create SSH tunnel
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9 -- -L 45901:127.0.0.1:45901
```

Open browser: `http://localhost:45901`
- Login with MINIO_ROOT_USER / MINIO_ROOT_PASSWORD from .env
- Create bucket matching S3_BUCKET
- Create access key matching S3_ACCESS_KEY / S3_SECRET_KEY

### Restore Database (if needed)

```bash
# Copy backup
gcloud compute scp backup.sql siris:/tmp/backup.sql --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Restore
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
docker exec -i smae_postgres psql -U smae -d smae_production < /tmp/backup.sql
```

## Monitoring

### View Logs

```bash
# Load Balancer logs
gcloud logging read "resource.type=http_load_balancer" --limit 50

# Cloud Armor events
gcloud logging read 'jsonPayload.enforcedSecurityPolicy.name="siris-security-policy"' --limit 50

# Application logs
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
docker compose logs -f
```

### Security Dashboard

Open: Cloud Console → Monitoring → Dashboards → "siris Security Dashboard"

## Common Issues

**SSL Certificate not provisioning?**
- Check DNS with `nslookup smae.e-siri.com`
- Wait up to 60 minutes after DNS is correct

**Can't access application?**
- Check Docker: `docker compose ps`
- Test locally: `curl http://localhost:45902` (Frontend), `curl http://localhost:45000/api/ping` (API)
- Verify DNS: `nslookup api.smae.e-siri.com`

**Health check failures?**
- Check logs: `docker compose logs smae_api`
- Test ports: `netstat -tlnp | grep -E '45000|45902|45903'`

## Updates

```bash
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
cd ~/smae
git pull
docker compose --profile fullStack up -d --build
```

## Destroy Infrastructure

```bash
terraform destroy
```

## Security Reminder

✅ **MUST DO**:
- Set `BIND_INTERFACE=""` for public services (frontend, api, metabase)
- Keep PostgreSQL and MinIO on `127.0.0.1:` (already in .env.production.example)
- Change ALL default passwords
- Update all subdomain URLs in .env
- Never commit .env to git
- Rotate credentials quarterly
- Enable automated backups

## Architecture Benefits

✨ **No Nginx = Simpler & Faster**
- Load Balancer routes directly to correct port based on hostname
- One less component to configure and maintain
- Better performance (no additional proxy layer)
- Easier to debug and monitor

---

**Estimated Total Time**: ~60-90 minutes (including SSL certificate provisioning)

See [README.md](README.md) for detailed documentation.
