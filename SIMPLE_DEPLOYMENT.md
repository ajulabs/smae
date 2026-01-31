# Simple Polling-Based Deployment

## Overview

Simplified deployment approach:
- Manual .env file management on VM
- Git polling every 5 minutes for new commits
- Local Docker builds on VM
- No Secret Manager, no GitHub Actions
- Perfect for forked repositories

## How It Works

```
Every 5 minutes:
  1. Cron job checks GitHub for new commits
  2. If found: git pull, build, deploy
  3. If not: skip
  
.env file:
  - Created manually on VM
  - Not managed by scripts
  - Edit directly when needed
```

## Initial Setup

### Step 1: SSH to VM

```bash
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
```

### Step 2: Install Prerequisites

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER
sudo mkdir -p /data/smae
sudo chown $USER:$USER /data/smae
exit

# SSH back
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
```

### Step 3: Clone Repository

```bash
git clone https://github.com/ajulabs/smae.git ~/smae
cd ~/smae
```

### Step 4: Create .env File

```bash
# Copy from example
cp .env.production.example .env

# Edit with production values
nano .env
```

**CRITICAL VALUES TO UPDATE**:

```bash
# Subdomain URLs (required!)
URL_LOGIN_SMAE="https://smae.e-siri.com/login"
API_HOST_NAME="api.smae.e-siri.com"
VITE_API_URL="https://api.smae.e-siri.com"
MB_SITE_URL="https://metadb.smae.e-siri.com"

# Port binding (no Nginx!)
BIND_INTERFACE=""

# Generate strong passwords
POSTGRES_PASSWORD="$(openssl rand -base64 32)"
MB_DB_PASS="$(openssl rand -base64 32)"
MINIO_ROOT_PASSWORD="$(openssl rand -base64 32)"
SESSION_JWT_SECRET="$(openssl rand -base64 32)"

# Generate encryption key
# Install cloak: npm install -g @47ng/cloak-cli
# Then: cloak generate
PRISMA_FIELD_ENCRYPTION_KEY="k1.aesgcm256.<your-key-here>"

# Database
POSTGRES_USER="smae"
POSTGRES_DB="smae_production"
DATABASE_URL="postgresql://smae:<POSTGRES_PASSWORD>@db:5432/smae_production?schema=public&connection_limit=40"

# MinIO
MINIO_ROOT_USER="admin_prod"
S3_ACCESS_KEY="$(openssl rand -hex 20)"
S3_SECRET_KEY="$(openssl rand -base64 32)"
S3_BUCKET="smae-storage"

# Data path
DATA_PATH="/data/smae"
```

**Save and secure the file**:
```bash
chmod 600 .env
```

### Step 5: Setup Auto-Deploy

```bash
cd ~/smae
bash scripts/setup-auto-deploy.sh
```

This installs a cron job that checks for updates every 5 minutes.

### Step 6: Test Deployment

```bash
# Run manual deployment first
bash scripts/deploy.sh

# Watch progress
docker ps
bash scripts/health-check.sh
```

## Daily Usage

### Deploy New Changes

```bash
# On your local machine
git add .
git commit -m "Your changes"
git push origin master

# On VM (or wait up to 5 minutes)
tail -f ~/smae/auto-deploy.log
```

Deployment happens automatically within 5-20 minutes.

### Update Environment Variables

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

# Edit .env
cd ~/smae
nano .env

# Restart services to pick up changes
docker compose -f docker-compose.production.yml restart
```

### Monitor Deployments

```bash
# Watch deployment logs
tail -f ~/smae/auto-deploy.log

# View container status
docker ps

# Run health checks
bash scripts/health-check.sh

# View cron job
crontab -l
```

### Rollback

```bash
# SSH to VM
cd ~/smae

# Find previous commit
git log --oneline -10

# Rollback
bash scripts/rollback.sh <commit-sha>
```

## Deployment Timeline

**From push to deployed**:
- 0-5 minutes: Wait for cron poll
- 10-15 minutes: Build images
- 2-3 minutes: Rolling restart
- **Total**: 12-23 minutes

**Subsequent builds faster** (with Docker cache): 7-12 minutes

## Troubleshooting

### Check if Auto-Deploy is Running

```bash
# View cron job
crontab -l | grep check-and-deploy

# Check logs
tail -50 ~/smae/auto-deploy.log

# Test manually
bash ~/smae/scripts/check-and-deploy.sh
```

### Deployment Not Triggering

```bash
# Verify git fetch works
cd ~/smae
git fetch origin master

# Check if commits are different
git log HEAD..origin/master

# Run deployment manually
bash scripts/deploy.sh
```

### Build Failures

```bash
# Check build logs
docker compose -f docker-compose.production.yml build 2>&1 | tee build.log

# Check disk space
df -h
docker system df

# Clean up if needed
docker system prune -a -f
```

### Out of Memory During Build

```bash
# Build services one at a time instead of parallel
docker compose -f docker-compose.production.yml build --no-parallel
```

## Security Notes

### .env File Security

- **Never commit to git** - Already in .gitignore
- **Permissions 600** - Only owner can read
- **Backup securely** - Keep encrypted copy offline
- **Rotate passwords** - Update .env and restart services

### No Secrets in GitHub

- Fork limitation becomes a security feature!
- No credentials exposed in GitHub
- All secrets stay on VM only
- No service account keys anywhere

## Updating Secrets

To change passwords or API keys:

```bash
# SSH to VM
cd ~/smae
nano .env

# Update value(s)
# Save and exit

# Restart affected services
docker compose -f docker-compose.production.yml restart smae_api

# Or restart all
docker compose -f docker-compose.production.yml restart
```

## Disable/Enable Auto-Deploy

### Temporarily Disable

```bash
# SSH to VM
crontab -e

# Comment out the line:
# */5 * * * * /home/ubuntu/smae/scripts/check-and-deploy.sh
```

### Re-Enable

```bash
crontab -e

# Remove the # to uncomment:
*/5 * * * * /home/ubuntu/smae/scripts/check-and-deploy.sh
```

## Advantages of This Approach

1. **Simple**: No Secret Manager, no GitHub Actions
2. **Secure**: Secrets stay on VM only
3. **Works with forks**: No GitHub secrets needed
4. **Fully automated**: Push to deploy
5. **No external dependencies**: Everything on VM
6. **Easy to understand**: Just bash scripts
7. **No additional cost**: Uses existing VM
8. **Full control**: Direct access to all configs

## File Structure

```
~/smae/
├── .env                          # Your production config (manual)
├── .env.production.example       # Template with subdomain URLs
├── docker-compose.production.yml # Builds locally
├── auto-deploy.log              # Deployment history
├── scripts/
│   ├── check-and-deploy.sh      # Polling logic (runs every 5 min)
│   ├── setup-auto-deploy.sh     # One-time cron setup
│   ├── deploy.sh                # Build + deploy
│   ├── rollback.sh              # Quick rollback
│   └── health-check.sh          # Verify services
```

## Quick Reference

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# View logs
tail -f ~/smae/auto-deploy.log

# Manual deploy
cd ~/smae && bash scripts/deploy.sh

# Rollback
cd ~/smae && bash scripts/rollback.sh <sha>

# Edit config
nano ~/smae/.env

# Restart services
docker compose -f ~/smae/docker-compose.production.yml restart

# Health check
bash ~/smae/scripts/health-check.sh
```

---

**Your deployment is now fully automated with maximum simplicity!**
