# CI/CD Pipeline Documentation

## Overview

Automated CI/CD pipeline that builds Docker images, stores them in GCP Artifact Registry, manages secrets in Secret Manager, and deploys to the VM with rolling updates.

## Architecture

### Build & Deploy Flow

```
Developer Push → GitHub Actions → Build Images → Artifact Registry
                                      ↓
                              Deploy to VM via SSH/IAP
                                      ↓
                         VM fetches secrets & images
                                      ↓
                            Rolling restart services
```

### Services Built

1. **frontend** - Vue.js web application
2. **backend** - NestJS API
3. **backend-geoloc** - Geolocation service
4. **backend-orcamento** - Budget/SOF integration
5. **backend-sei** - SEI integration
6. **backend-transferegov** - Transfer.gov integration
7. **backend-transferegov-transferencias** - Transfers service
8. **gotenberg** - PDF generation
9. **email-service** - Email processing

External images: postgres, metabase, minio, smtp4dev (pulled directly)

## Initial Setup

### 1. Apply Terraform

First, apply the Terraform configuration to create:
- Artifact Registry repository
- Secret Manager secrets (empty)
- Workload Identity Federation for GitHub Actions
- IAM permissions

```bash
cd terraform
terraform apply
```

### 2. Populate Secrets

Create production environment file and upload secrets:

```bash
# Create production environment file
cp .env.production.example .env.production

# Edit with real values
nano .env.production

# CRITICAL: Update subdomain URLs
URL_LOGIN_SMAE="https://smae.e-siri.com/login"
API_HOST_NAME="api.smae.e-siri.com"
VITE_API_URL="https://api.smae.e-siri.com"
MB_SITE_URL="https://metadb.smae.e-siri.com"

# CRITICAL: Set binding (no Nginx)
BIND_INTERFACE=""

# Generate strong passwords
POSTGRES_PASSWORD="$(openssl rand -base64 32)"
SESSION_JWT_SECRET="$(openssl rand -base64 32)"
# ... etc

# Upload all secrets to Secret Manager
./scripts/populate-secrets.sh .env.production
```

This creates 11 secrets in Secret Manager with "smae-" prefix:
- `smae-postgres-password`
- `smae-mb-db-pass`
- `smae-minio-root-user`
- `smae-minio-root-password`
- `smae-s3-access-key`
- `smae-s3-secret-key`
- `smae-session-jwt-secret`
- `smae-prisma-encryption-key`
- `smae-sof-api-token`
- `smae-sei-api-token`
- `smae-azure-key`

### 3. Verify Secrets

```bash
# List all secrets
gcloud secrets list --filter="name:smae-" --project=stoked-coder-451819-v9

# View a specific secret (masked)
gcloud secrets describe smae-postgres-password --project=stoked-coder-451819-v9
```

### 4. Configure GitHub Actions

No GitHub secrets needed! Workload Identity Federation uses GitHub's OIDC token.

The workflow is triggered automatically on push to master.

## GitHub Actions Workflow

Location: `.github/workflows/deploy.yml`

### Jobs

**1. build-and-push (parallel)**
- Matrix strategy builds all 9 services simultaneously
- Each image tagged with:
  - `latest` - for production deployments
  - `<commit-sha>` - for rollbacks
- Pushed to: `southamerica-east1-docker.pkg.dev/stoked-coder-451819-v9/smae/<service>:tag`

**2. deploy (sequential)**
- Waits for all builds to complete
- SSH to VM via IAP
- Copies deployment scripts to VM
- Runs deployment script
- Verifies services are healthy

### Workflow Triggers

- Push to `master` branch (automatic)
- Manual trigger via GitHub Actions UI (workflow_dispatch)

### Build Time

- First build: 15-20 minutes (no cache)
- Subsequent builds: 5-10 minutes (with cache)

## Deployment Process

When you push to master:

### 1. Build Phase (parallel)

```bash
# GitHub Actions builds all services
frontend          → 2-3 minutes
backend           → 4-5 minutes
backend-geoloc    → 2-3 minutes
backend-orcamento → 2-3 minutes
backend-sei       → 2-3 minutes
backend-transferegov → 2-3 minutes
backend-transferegov-transferencias → 2-3 minutes
gotenberg         → 2-3 minutes
email-service     → 3-4 minutes

Total (parallel): ~5-7 minutes
```

### 2. Deploy Phase (sequential)

```bash
1. SSH to VM via IAP
2. Fetch latest secrets from Secret Manager
3. Generate .env file
4. Pull new images from Artifact Registry
5. Rolling restart:
   - smae_orcamento      (10s)
   - smae_geoloc         (10s)
   - smae_sei            (10s)
   - smae_transferegov   (10s)
   - smae_transferegov_transferencias (10s)
   - email_service       (10s)
   - gotenberg           (10s)
   - smae_api            (10s)
   - web                 (10s)

Total: ~2-3 minutes
```

### 3. Verification

```bash
# Health checks run automatically
# Deployment fails if any service doesn't start
```

## Manual Deployment

To deploy manually (without Git push):

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Run deployment
cd ~/smae
IMAGE_TAG=latest bash scripts/deploy.sh
```

## Rollback

### Quick Rollback to Previous Version

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Find previous commit SHA
cd ~/smae
git log --oneline -10

# Rollback to specific commit
bash scripts/rollback.sh <commit-sha>

# Example
bash scripts/rollback.sh abc123def456
```

### Emergency Rollback

If something is seriously broken:

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

cd ~/smae

# Stop everything
docker compose -f docker-compose.production.yml down

# Set to previous version
export IMAGE_TAG=<previous-commit-sha>

# Start
docker compose -f docker-compose.production.yml --profile fullStack up -d
```

## Secrets Management

### Updating Secrets

To update a secret:

```bash
# Option 1: Via gcloud directly
echo "new-secret-value" | gcloud secrets versions add smae-postgres-password \
  --project=stoked-coder-451819-v9 \
  --data-file=-

# Option 2: Update .env.production and re-run populate script
nano .env.production
./scripts/populate-secrets.sh .env.production
```

### Viewing Secrets

```bash
# List all SMAE secrets
gcloud secrets list --filter="name:smae-" --project=stoked-coder-451819-v9

# View secret metadata (NOT the value)
gcloud secrets describe smae-postgres-password --project=stoked-coder-451819-v9

# Access secret value (requires secretAccessor role)
gcloud secrets versions access latest --secret=smae-postgres-password --project=stoked-coder-451819-v9
```

### Secret Rotation

1. Update secret in Secret Manager
2. Redeploy application (or wait for next deployment)
3. Application automatically picks up new secret

No VM access needed!

## Monitoring Deployments

### GitHub Actions

View build and deployment logs:
- Go to: https://github.com/ajulabs/smae/actions
- Click on latest workflow run
- View job logs

### VM Logs

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# View docker logs
cd ~/smae
docker compose -f docker-compose.production.yml logs -f

# View specific service
docker compose -f docker-compose.production.yml logs -f smae_api
```

### Cloud Logging

```bash
# View all deployments
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_id=<instance-id>" --limit=50

# View secret access logs
gcloud logging read "protoPayload.serviceName=secretmanager.googleapis.com" --limit=50
```

## Troubleshooting

### Build Failures

**Issue**: Docker build fails in GitHub Actions

**Check**:
```bash
# View GitHub Actions logs
# Check for missing dependencies, syntax errors, etc.
```

**Fix**:
- Fix code issues
- Push again
- Build will retry automatically

### Deployment Failures

**Issue**: Deployment script fails on VM

**Check**:
```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

# Check deployment logs
cd ~/smae
docker compose -f docker-compose.production.yml logs --tail=100

# Check disk space
df -h

# Check docker status
docker ps -a
```

**Fix**:
```bash
# Rollback to previous version
bash scripts/rollback.sh <previous-commit-sha>

# Or restart manually
docker compose -f docker-compose.production.yml restart
```

### Secret Access Denied

**Issue**: VM cannot access secrets

**Check**:
```bash
# Verify VM service account has permissions
gcloud secrets get-iam-policy smae-postgres-password --project=stoked-coder-451819-v9

# Test secret access from VM
gcloud secrets versions access latest --secret=smae-postgres-password --project=stoked-coder-451819-v9
```

**Fix**:
```bash
# Re-apply Terraform to fix IAM bindings
cd terraform
terraform apply
```

### Image Pull Failures

**Issue**: VM cannot pull images from Artifact Registry

**Check**:
```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

# Test docker authentication
gcloud auth configure-docker southamerica-east1-docker.pkg.dev

# Try pulling manually
docker pull southamerica-east1-docker.pkg.dev/stoked-coder-451819-v9/smae/backend:latest
```

**Fix**:
```bash
# Verify VM service account has artifactregistry.reader role
# Re-apply Terraform if needed
```

## Performance Optimization

### Build Cache

GitHub Actions uses build cache to speed up subsequent builds:
- Layer caching with `cache-from: type=gha`
- Only changed layers are rebuilt
- Saves 50-70% build time

### Image Size Optimization

Tips to reduce image sizes:
- Use multi-stage builds
- Remove dev dependencies in production builds
- Use .dockerignore files
- Clean up package caches

### Parallel Builds

All 9 services build in parallel using matrix strategy.
Total build time = longest individual build (not sum of all builds).

## Security

### Workload Identity Federation

- No service account keys in GitHub
- Short-lived OAuth tokens (1 hour expiration)
- Only `ajulabs/smae` repository can authenticate
- Full audit trail in Cloud Logging

### Secret Manager

- Secrets encrypted at rest
- Access logged in Cloud Audit Logs
- Version management (can rollback secrets)
- Fine-grained IAM per secret
- No plain text secrets on VM

### Image Security

- Private Artifact Registry (not public)
- Only authorized service accounts can pull
- Images scanned for vulnerabilities (optional)
- Immutable tags using commit SHA

## Cost Breakdown

**Artifact Registry:**
- Storage: ~$0.10/GB/month
- 9 images × ~500MB avg = ~4.5GB
- Cost: ~$0.45/month

**Secret Manager:**
- 11 secrets × $0.30/month = $3.30/month
- Access operations: ~$0.10/month

**GitHub Actions:**
- Free tier: 2000 minutes/month
- Typical usage: ~300 minutes/month
- Cost: $0 (within free tier)

**Total: ~$3.85/month**

## Best Practices

1. **Always review deployment logs** after pushing to master
2. **Test in development** before pushing to master
3. **Keep .env.production local** - never commit it
4. **Rotate secrets quarterly** using Secret Manager
5. **Monitor build times** and optimize slow builds
6. **Tag releases** for easy rollback (optional)
7. **Use health checks** to verify deployments
8. **Keep docker-compose.production.yml in sync** with docker-compose.fixed-path.yml

## Quick Commands

```bash
# View latest deployment
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap -- docker ps

# Rollback to previous version
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap -- "cd ~/smae && bash scripts/rollback.sh <sha>"

# View logs
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap -- "cd ~/smae && docker compose -f docker-compose.production.yml logs -f"

# Health check
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap -- "bash ~/smae/scripts/health-check.sh"

# Update a secret
echo "new-value" | gcloud secrets versions add smae-postgres-password --data-file=-

# List images in registry
gcloud artifacts docker images list southamerica-east1-docker.pkg.dev/stoked-coder-451819-v9/smae
```
