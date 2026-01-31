# Auto-Deployment Setup Guide

Complete guide for setting up automated deployments with git polling.

## How It Works

**Polling-based deployment** - No GitHub Actions needed (works with forks!)

```
Every 5 minutes → Check GitHub for new commits → If found: Pull, Build, Deploy
```

## Prerequisites

- [x] Terraform infrastructure deployed
- [x] DNS configured (3 A records)
- [x] SSL certificate active
- [x] Secrets uploaded to Secret Manager
- [ ] VM configured with Docker
- [ ] Auto-deploy cron job enabled

## Step-by-Step Setup

### Step 1: Apply Terraform (if not done)

```bash
cd terraform
terraform apply
```

This creates:
- Artifact Registry repository
- Secret Manager secrets (empty)
- Workload Identity Federation for GitHub
- Service accounts and IAM permissions

### Step 2: Prepare Production Environment

```bash
# Create production .env
cp .env.production.example .env.production
nano .env.production
```

**Critical values to set:**

```bash
# Database
POSTGRES_PASSWORD="$(openssl rand -base64 32)"
POSTGRES_USER="smae"
POSTGRES_DB="smae_production"

# Metabase
MB_DB_PASS="$(openssl rand -base64 32)"

# MinIO
MINIO_ROOT_USER="admin$(openssl rand -hex 4)"
MINIO_ROOT_PASSWORD="$(openssl rand -base64 32)"
S3_ACCESS_KEY="$(openssl rand -hex 20)"
S3_SECRET_KEY="$(openssl rand -base64 32)"

# Session & Encryption
SESSION_JWT_SECRET="$(openssl rand -base64 32)"
PRISMA_FIELD_ENCRYPTION_KEY="$(npx @47ng/cloak-cli generate)"

# External APIs (get from your providers)
SOF_API_TOKEN="your-sof-token"
SEI_API_TOKEN="your-sei-token"
AZURE_KEY="your-azure-key-or-placeholder"

# Subdomain URLs (CRITICAL!)
URL_LOGIN_SMAE="https://smae.e-siri.com/login"
API_HOST_NAME="api.smae.e-siri.com"
VITE_API_URL="https://api.smae.e-siri.com"
MB_SITE_URL="https://metadb.smae.e-siri.com"

# Port binding (NO Nginx!)
BIND_INTERFACE=""
```

### Step 3: Upload Secrets to Secret Manager

```bash
# Upload all secrets
./scripts/populate-secrets.sh .env.production
```

Output:
```
Creating/updating secret: smae-postgres-password
✓ Created new secret: smae-postgres-password
Creating/updating secret: smae-mb-db-pass
✓ Created new secret: smae-mb-db-pass
...
✅ All secrets uploaded successfully!
```

### Step 4: Verify Secrets

```bash
# List secrets
gcloud secrets list --filter="name:smae-" --project=stoked-coder-451819-v9

# Should show 11 secrets:
# smae-postgres-password
# smae-mb-db-pass
# smae-minio-root-user
# smae-minio-root-password
# smae-s3-access-key
# smae-s3-secret-key
# smae-session-jwt-secret
# smae-prisma-encryption-key
# smae-sof-api-token
# smae-sei-api-token
# smae-azure-key
```

### Step 5: Test Secret Access from VM

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Test fetching secrets
cd ~/smae
bash scripts/fetch-secrets.sh > .env.test
cat .env.test | grep -E "POSTGRES_PASSWORD|SESSION_JWT_SECRET"

# Should show actual values (not placeholders)
# Clean up test file
rm .env.test
```

### Step 6: Initial VM Setup

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Clone repository (if not done)
git clone git@github.com:ajulabs/smae.git
cd smae

# Create necessary directories
sudo mkdir -p /data/smae
sudo chown $USER:$USER /data/smae

# Install Docker (if not done)
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER

# Logout and login again
exit
```

### Step 7: Manual First Deployment (Recommended)

Before enabling automated deployments, do a manual deployment to verify everything works:

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

cd ~/smae

# Copy necessary files
git pull origin master

# Make scripts executable
chmod +x scripts/*.sh

# Fetch secrets and deploy
bash scripts/fetch-secrets.sh > .env
chmod 600 .env

# Start services
docker compose -f docker-compose.production.yml --profile fullStack up -d

# Check status
docker ps
bash scripts/health-check.sh
```

### Step 8: Test Application

```bash
# Wait a few minutes for services to start
sleep 60

# Test endpoints
curl https://smae.e-siri.com
curl https://api.smae.e-siri.com/api/ping
curl https://metadb.smae.e-siri.com/api/health
```

### Step 9: Enable Automated Deployments

Once manual deployment works, automated deployments will work on every push to master!

```bash
# Make a change
echo "# Test" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin master

# Watch GitHub Actions
# https://github.com/ajulabs/smae/actions
```

## Deployment Workflow

### Normal Deployment (Push to Master)

1. Developer commits and pushes to master
2. GitHub Actions triggered automatically
3. All 9 services build in parallel (~5-10 minutes)
4. Images pushed to Artifact Registry
5. Deploy job SSHs to VM
6. Fresh secrets fetched
7. New images pulled
8. Rolling restart (~2-3 minutes)
9. Health checks verify
10. Deployment complete

**Total time**: ~7-13 minutes

### Manual Deployment (SSH to VM)

```bash
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

cd ~/smae
git pull origin master
IMAGE_TAG=latest bash scripts/deploy.sh
```

## Troubleshooting

### "Permission denied" in GitHub Actions

**Solution**: Terraform creates Workload Identity automatically. If you see this error:
1. Verify Terraform applied successfully
2. Check GitHub Actions settings allow id-token permissions
3. Verify repository matches `ajulabs/smae`

### "Cannot pull image" on VM

**Solution**:
```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

# Configure Docker
gcloud auth configure-docker southamerica-east1-docker.pkg.dev

# Test pull
docker pull southamerica-east1-docker.pkg.dev/stoked-coder-451819-v9/smae/backend:latest
```

### "Secret not found"

**Solution**:
```bash
# Re-run populate script
./scripts/populate-secrets.sh .env.production

# Verify
gcloud secrets list --filter="name:smae-"
```

### Deployment hangs

**Solution**:
```bash
# SSH to VM and check logs
docker compose -f docker-compose.production.yml logs -f

# Check specific service
docker compose -f docker-compose.production.yml logs smae_api
```

## Security Notes

1. **Never commit .env.production** - it contains real secrets
2. **Secrets are in Secret Manager** - VM fetches them dynamically
3. **No service account keys** - Workload Identity handles authentication
4. **All access logged** - Cloud Audit Logs track secret access
5. **Rotate secrets quarterly** - use Secret Manager versioning

## Next Steps

After setup is complete:
- [ ] Set up monitoring alerts
- [ ] Configure backup automation
- [ ] Document rollback procedures
- [ ] Set up secret rotation schedule
- [ ] Enable vulnerability scanning (optional)

See [`terraform/CI_CD.md`](terraform/CI_CD.md) for detailed CI/CD documentation.
