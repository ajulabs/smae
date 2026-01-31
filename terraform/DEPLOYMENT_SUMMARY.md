# SMAE Infrastructure & CI/CD - Complete Summary

## What Was Created

### Terraform Infrastructure (18 files)

**Core Infrastructure:**
- `versions.tf` - Terraform and provider versions
- `variables.tf` - Input variables (42 variables)
- `main.tf` - VPC, VM, Load Balancer, SSL certificate
- `firewall.tf` - Network security rules
- `security.tf` - Cloud Armor WAF with OWASP rules
- `monitoring.tf` - Cloud Logging and alerts
- `outputs.tf` - Deployment information outputs

**New: CI/CD Infrastructure:**
- `secrets.tf` - Secret Manager for 11 sensitive values
- `artifact_registry.tf` - Docker image registry
- `github_actions.tf` - Workload Identity Federation

**Configuration:**
- `terraform.tfvars` - Your specific values
- `terraform.tfvars.example` - Template
- `.gitignore` - Prevent committing secrets

**Documentation:**
- `README.md` - Complete deployment guide
- `QUICKSTART.md` - Fast deployment guide
- `ARCHITECTURE.md` - Subdomain architecture (no Nginx!)
- `SECURITY.md` - Security features explained
- `CI_CD.md` - CI/CD pipeline documentation
- `DEPLOYMENT_CHECKLIST.md` - Step-by-step checklist

### Application Files

**CI/CD:**
- `.github/workflows/deploy.yml` - Automated build and deploy
- `docker-compose.production.yml` - Production compose with registry images
- `CI_CD_SETUP.md` - Complete CI/CD setup guide

**Scripts:**
- `scripts/populate-secrets.sh` - Upload secrets to GCP (run locally)
- `scripts/fetch-secrets.sh` - Generate .env from secrets (runs on VM)
- `scripts/deploy.sh` - Rolling deployment script
- `scripts/rollback.sh` - Quick rollback script
- `scripts/health-check.sh` - Health verification

**Configuration:**
- `.env.template` - Non-sensitive config template
- `.env.production.example` - Production config example (with subdomain URLs)

## Architecture Overview

### Subdomain-Based (No Nginx Required)

```
Internet → Cloud Armor → Load Balancer → VM
                              ↓
                    smae.e-siri.com → Port 45902 (Frontend)
                    api.smae.e-siri.com → Port 45000 (API)
                    metadb.smae.e-siri.com → Port 45903 (Metabase)
```

### Security Layers

1. **Cloud Armor WAF** - OWASP Top 10, rate limiting, DDoS
2. **Load Balancer** - SSL termination, HTTP→HTTPS redirect
3. **Network Isolation** - No public IP, private VPC
4. **Service Isolation** - DB & MinIO on localhost only
5. **Secret Manager** - Encrypted secrets, audit logs

### CI/CD Pipeline

```
Push to master → GitHub Actions → Build 9 images → Artifact Registry
                       ↓
                Deploy to VM → Fetch secrets → Pull images → Rolling restart
```

## Configuration Summary

### Project: stoked-coder-451819-v9
### Region: southamerica-east1
### VM: siris (n2-standard-4, 100GB SSD, no public IP)

### Subdomains (all point to same Load Balancer IP):
- `smae.e-siri.com` - Frontend
- `api.smae.e-siri.com` - API
- `metadb.smae.e-siri.com` - Metabase

### Repository: ajulabs/smae

## Quick Start

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### 2. Configure DNS

Get Load Balancer IP:
```bash
terraform output load_balancer_ip
```

Create 3 DNS A records (all same IP):
- `smae.e-siri.com` → `<lb-ip>`
- `api.smae.e-siri.com` → `<lb-ip>`
- `metadb.smae.e-siri.com` → `<lb-ip>`

### 3. Upload Secrets

```bash
# Create production .env
cp .env.production.example .env.production
nano .env.production  # Update all values

# Upload to Secret Manager
./scripts/populate-secrets.sh .env.production
```

### 4. Initial VM Setup

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER
exit

# SSH back
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

# Clone repo
git clone git@github.com:ajulabs/smae.git
cd smae

# Deploy manually first time
bash scripts/fetch-secrets.sh > .env
chmod 600 .env
docker compose -f docker-compose.production.yml --profile fullStack up -d
```

### 5. Wait for SSL (30-60 min)

```bash
# Check certificate status
gcloud compute ssl-certificates describe siris-ssl-cert-v2 --global
```

### 6. Verify

```bash
curl https://smae.e-siri.com
curl https://api.smae.e-siri.com/api/ping
curl https://metadb.smae.e-siri.com/api/health
```

### 7. Enable Automated Deployments

Done! Push to master triggers automatic deployment.

## Resources Created

**GCP Resources (28 total):**
- 1 VPC network
- 1 Subnet
- 1 Cloud Router + NAT
- 1 VM instance (siris)
- 1 Instance group
- 5 Firewall rules
- 1 Static IP
- 1 SSL certificate (3 domains)
- 3 Backend services (frontend, API, metabase)
- 3 Health checks
- 2 URL maps
- 2 Target proxies
- 2 Forwarding rules
- 1 Cloud Armor security policy (14 rules)
- 1 Artifact Registry repository
- 11 Secret Manager secrets
- 1 Workload Identity Pool + Provider
- 2 Service accounts

**Total Monthly Cost: ~$255/month**
- VM: $140
- SSD: $17
- Load Balancer: $25
- Cloud NAT: $45
- Cloud Armor: $15
- Artifact Registry: $0.50
- Secret Manager: $3.50
- Logging: $5-10

## Key Features

### Infrastructure
- No public IP on VM
- HTTPS with auto-renewed SSL
- Multi-subdomain support
- Health checks and auto-scaling ready

### Security
- Cloud Armor WAF (OWASP Top 10)
- Rate limiting (100 req/min, 20 req/min login)
- ML-based DDoS protection
- Secret Manager (encrypted, audited)
- Workload Identity (no service account keys)
- SSH via IAP only

### CI/CD
- Automated builds on push to master
- Parallel image building (9 services)
- Artifact Registry for images
- Rolling deployments (minimal downtime)
- One-command rollback
- Health check verification

## Documentation

Comprehensive documentation in 10+ files:
- Infrastructure setup
- Security architecture
- CI/CD pipeline
- Deployment procedures
- Troubleshooting guides
- Quick reference guides

## Next Steps

1. Apply Terraform infrastructure
2. Configure DNS records
3. Upload secrets to Secret Manager
4. Configure VM
5. Push to master to trigger first deployment
6. Monitor and optimize

See individual documentation files for detailed instructions.
