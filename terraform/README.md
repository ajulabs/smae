# SMAE GCP Infrastructure with Terraform

This Terraform configuration deploys a secure, production-grade infrastructure for the SMAE application on Google Cloud Platform (GCP) with enterprise-level security features.

## Architecture Overview

```
Internet → Cloud Armor WAF → HTTPS Load Balancer → Private VM → Docker Services
           ↓                  ↓                      ↓
        OWASP Rules      SSL Certificate        No Public IP
        Rate Limiting    (smae.e-siri.com)      Localhost-only services
        DDoS Protection                          Cloud NAT for updates
```

## Security Features

### 🛡️ Multi-Layer Defense

1. **Cloud Armor WAF (Application Layer)**
   - OWASP Top 10 protection (SQLi, XSS, RCE, LFI, RFI, etc.)
   - Rate limiting: 100 req/min general, 20 req/min for login endpoints
   - Adaptive ML-based DDoS protection
   - Optional geo-filtering by country
   - Scanner and bot detection

2. **Network Isolation (Network Layer)**
   - VM has **no public IP address**
   - Only accessible via Load Balancer and IAP SSH
   - VPC with private subnet
   - Strict firewall rules (only LB and health check traffic allowed)
   - Cloud NAT for outbound-only internet access

3. **Service Isolation (Application Layer)**
   - All Docker services bind to `127.0.0.1` only
   - PostgreSQL, MinIO, and internal APIs not accessible from network
   - Only Nginx reverse proxy can access internal services
   - Defense-in-depth: even if VM is compromised, services remain isolated

4. **Monitoring & Logging**
   - Cloud Logging for all security events
   - Alert policies for anomalous traffic
   - Security dashboard with real-time metrics
   - 30-day log retention (configurable)

## Prerequisites

1. **GCP Account** with billing enabled
2. **Terraform** >= 1.5 installed ([Download](https://www.terraform.io/downloads))
3. **Google Cloud SDK** (gcloud CLI) installed ([Install](https://cloud.google.com/sdk/docs/install))
4. **Domain Name** with access to DNS configuration
5. **GCP Project** created

### Required GCP APIs

Enable the following APIs in your GCP project:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable iap.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
```

## Quick Start

### 1. Authenticate with GCP

```bash
gcloud auth login
gcloud config set project stoked-coder-451819-v9
gcloud auth application-default login
```

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Update the following values in `terraform.tfvars`:
- `project_id`: Your GCP project ID
- `domain_name`: Your domain (e.g., smae.e-siri.com)
- Other values as needed

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply
```

**Note**: The initial deployment takes **30-60 minutes** for the SSL certificate to provision.

### 4. Get Output Values

```bash
terraform output
```

Important outputs:
- `load_balancer_ip`: IP address for DNS A record
- `ssh_command`: Command to access VM via SSH
- `application_url`: Your application URL

### 5. Configure DNS

Create an A record in your DNS provider:

```
Host: smae.e-siri.com
Type: A
Value: <load_balancer_ip from terraform output>
TTL: 300
```

Wait 5-15 minutes for DNS propagation.

## VM Configuration

After infrastructure is deployed, configure the VM:

### 1. SSH into VM

```bash
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
```

### 2. Install Docker and Dependencies

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker (No Nginx needed!)
sudo apt-get install -y docker.io docker-compose-v2 git

# Add user to docker group
sudo usermod -aG docker $USER

# Create data directory
sudo mkdir -p /data/smae
sudo chown $USER:$USER /data/smae

# Logout and login again for group changes to take effect
exit
```

### 3. Clone Repository and Configure

```bash
# SSH back in
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Clone repository
git clone https://github.com/AppCivico/smae.git
cd smae

# Copy production environment template
cp .env.production.example .env

# Edit environment file
nano .env
```

### 4. **CRITICAL**: Update Security Settings in `.env`

**YOU MUST CHANGE THESE VALUES**:

```bash
# 1. PUBLIC services - bind to all interfaces (Load Balancer will access)
BIND_INTERFACE=""
SMAE_API_LISTEN=45000
SMAE_WEB_LISTEN=45902
METADB_LISTEN=45903

# 2. PRIVATE services - bind to localhost only
# (Add "127.0.0.1:" prefix in docker-compose for these)
PG_DB_LISTEN=25432
MINIO_S3_LISTEN=45900
MINIO_CONSOLE_LISTEN=45901

# 3. Generate strong passwords (use: openssl rand -base64 32)
POSTGRES_PASSWORD="<strong-random-password>"
MB_DB_PASS="<strong-random-password>"
MINIO_ROOT_PASSWORD="<strong-random-password>"
SESSION_JWT_SECRET="<strong-random-secret>"

# 4. Generate encryption key (use: npx @47ng/cloak-cli generate)
PRISMA_FIELD_ENCRYPTION_KEY="k1.aesgcm256.<base64-key>"

# 5. Update S3 credentials
S3_ACCESS_KEY="<strong-random-key>"
S3_SECRET_KEY="<strong-random-secret>"
MINIO_ROOT_USER="<strong-random-user>"

# 6. Update subdomains (IMPORTANT!)
URL_LOGIN_SMAE="https://smae.e-siri.com/login"
API_HOST_NAME="api.smae.e-siri.com"
VITE_API_URL="https://api.smae.e-siri.com"
MB_SITE_URL="https://metadb.smae.e-siri.com"

# 7. Set data path
DATA_PATH="/data/smae"
```

### 5. Start Application (No Nginx Configuration Needed!)

```bash
cd ~/smae

# Start all services
docker compose --profile fullStack up -d

# Check logs
docker compose logs -f
```

### 6. Verify Deployment

Wait 30-60 minutes for SSL certificate to provision, then:

```bash
# Check SSL certificate status
gcloud compute ssl-certificates describe siris-ssl-cert --global

# Test all services
curl https://smae.e-siri.com  # Frontend
curl https://api.smae.e-siri.com/api/ping  # API
curl https://metadb.smae.e-siri.com/api/health  # Metabase
```

## Architecture Notes

### ✨ No Nginx Required!

This infrastructure uses **subdomain-based routing** at the Load Balancer level:

- `smae.e-siri.com` → Frontend (port 45902)
- `api.smae.e-siri.com` → API (port 45000)
- `metadb.smae.e-siri.com` → Metabase (port 45903)

**Benefits:**
- ✅ Simpler deployment (no reverse proxy to configure)
- ✅ Better performance (one less hop)
- ✅ Easier CORS configuration
- ✅ Clear service isolation

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for detailed explanation.

## Post-Deployment Configuration

### MinIO Setup

1. Access MinIO console (via SSH tunnel):
   ```bash
   gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9 -- -L 45901:127.0.0.1:45901
   ```

2. Open browser: `http://localhost:45901`

3. Login with credentials from `.env` (MINIO_ROOT_USER / MINIO_ROOT_PASSWORD)

4. Create bucket named as per S3_BUCKET in `.env`

5. Create access key matching S3_ACCESS_KEY and S3_SECRET_KEY

### Database Restore (if applicable)

If restoring from backup:

```bash
# Copy backup to VM
gcloud compute scp backup.sql siris:/tmp/backup.sql --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# SSH into VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Restore database
docker exec -i smae_postgres psql -U smae -d smae_production < /tmp/backup.sql

# Clean up
rm /tmp/backup.sql
```

**IMPORTANT**: If restoring from backup, `PRISMA_FIELD_ENCRYPTION_KEY` must match the original key.

## Monitoring and Maintenance

### View Security Dashboard

```bash
# Open Cloud Console
gcloud console

# Navigate to: Monitoring > Dashboards > "siris Security Dashboard"
```

### View Logs

```bash
# Load Balancer logs
gcloud logging read "resource.type=http_load_balancer" --limit 50 --format json

# Cloud Armor security events
gcloud logging read 'jsonPayload.enforcedSecurityPolicy.name="siris-security-policy"' --limit 50

# VM logs
gcloud logging read "resource.type=gce_instance resource.labels.instance_id=<instance-id>" --limit 50
```

### Check Cloud Armor Statistics

```bash
# View blocked requests
gcloud logging read 'jsonPayload.enforcedSecurityPolicy.outcome="DENY"' --limit 100 --format json
```

### Update Application

```bash
# SSH into VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

cd ~/smae
git pull
docker compose --profile fullStack up -d --build
```

## Security Best Practices

### ✅ Implemented

- [x] No public IP on VM
- [x] Cloud Armor WAF with OWASP rules
- [x] Rate limiting and DDoS protection
- [x] Services bind to localhost only
- [x] Strict firewall rules
- [x] SSH via IAP only
- [x] HTTPS with managed SSL certificate
- [x] HTTP to HTTPS redirect
- [x] Security monitoring and logging
- [x] VPC flow logs enabled

### ⚠️ Additional Recommendations

1. **Secrets Management**
   - Rotate passwords quarterly
   - Use strong, unique passwords for each service
   - Never commit `.env` to version control
   - Consider using GCP Secret Manager for production

2. **Database Security**
   - Enable PostgreSQL SSL connections
   - Implement regular automated backups
   - Test backup restoration periodically
   - Encrypt data at rest (enabled by default on GCP)

3. **Application Security**
   - Keep Docker images updated
   - Run `docker scan` on images
   - Review application code for vulnerabilities
   - Implement application-level rate limiting

4. **Access Control**
   - Use separate GCP service accounts with minimal permissions
   - Enable MFA for all GCP users
   - Regularly audit IAM permissions
   - Implement least-privilege principle

5. **Monitoring**
   - Set up notification channels for alerts
   - Review security logs weekly
   - Monitor for unusual traffic patterns
   - Set up uptime checks

6. **Backups**
   - Implement automated daily backups
   - Store backups in separate region
   - Test restoration procedure
   - Document backup/restore process

## Cost Optimization

### Estimated Monthly Costs (São Paulo region)

| Resource | Cost |
|----------|------|
| n2-standard-4 VM | ~$140 |
| 100GB SSD | ~$17 |
| HTTPS Load Balancer | ~$25 |
| Cloud NAT | ~$45 |
| Cloud Armor | ~$15 |
| Cloud Logging | ~$5-10 |
| **Total** | **~$247-252/month** |

### Cost-Saving Tips

1. **Right-size VM**: Monitor CPU/memory usage and adjust machine type if needed
2. **Scheduled shutdown**: Stop VM during non-business hours (development/staging)
3. **Log retention**: Reduce from 30 days to 7 days if acceptable
4. **Committed use discounts**: Get 37% discount with 1-year commitment

## Troubleshooting

### SSL Certificate Stuck in PROVISIONING

**Cause**: DNS not configured or not propagated

**Solution**:
```bash
# Check DNS
nslookup smae.e-siri.com

# Check certificate status
gcloud compute ssl-certificates describe siris-ssl-cert --global

# Wait up to 60 minutes after DNS is correctly configured
```

### Cannot Access Application

**Checklist**:
1. DNS A record pointing to Load Balancer IP?
2. SSL certificate status is ACTIVE?
3. Nginx running on VM? (`sudo systemctl status nginx`)
4. Docker services running? (`docker compose ps`)
5. Health check passing? (`curl http://127.0.0.1/api/ping` from VM)

### Health Check Failures

```bash
# SSH into VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Check Nginx
sudo systemctl status nginx
sudo nginx -t

# Check Docker services
docker compose ps
docker compose logs smae_api

# Test health endpoint locally
curl http://127.0.0.1/api/ping
```

### High Cloud Armor Blocks

If legitimate traffic is being blocked:

1. Review Cloud Armor logs to identify pattern
2. Adjust rate limits in `variables.tf`
3. Add trusted IPs to allowlist (requires custom rule)
4. Re-apply Terraform: `terraform apply`

### Cannot SSH to VM

```bash
# Ensure IAP is enabled
gcloud services enable iap.googleapis.com

# Check firewall rules
gcloud compute firewall-rules list --filter="name~siris"

# Use full command with project
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
```

## Destroying Infrastructure

**WARNING**: This will permanently delete all resources!

```bash
cd terraform

# Preview what will be deleted
terraform plan -destroy

# Destroy all resources
terraform destroy
```

To preserve data:
1. Backup PostgreSQL database first
2. Download files from MinIO
3. Export logs if needed

## Support and Documentation

- [GCP Documentation](https://cloud.google.com/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Armor Documentation](https://cloud.google.com/armor/docs)
- [SMAE Repository](https://github.com/AppCivico/smae)

## License

Same as SMAE project: AGPL-3.0
