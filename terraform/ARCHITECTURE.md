# SMAE Architecture - Subdomain Based (No Nginx Required)

## Overview

This infrastructure uses **subdomain-based routing** at the Load Balancer level, eliminating the need for Nginx reverse proxy on the VM.

## Architecture Diagram

```
                    Internet
                       |
                       | HTTPS (443)
                       v
            ┌──────────────────────┐
            │  Cloud Armor WAF     │
            │  - OWASP Protection  │
            │  - Rate Limiting     │
            │  - DDoS Protection   │
            └──────────────────────┘
                       |
                       v
            ┌──────────────────────┐
            │   Load Balancer      │
            │   - SSL Termination  │
            │   - Host Routing     │
            │   IP: 35.x.x.x       │
            └──────────────────────┘
                       |
         ┌─────────────┼─────────────┐
         |             |             |
    smae.e-siri.com    |      metadb.smae.e-siri.com
         |             |             |
         v             v             v
    Frontend      api.smae       Metabase
    Backend    .e-siri.com       Backend
         |             |             |
         v             v             v
    ┌────────────────────────────────────┐
    │  Private VM (No Public IP)         │
    │  ┌──────────────────────────────┐  │
    │  │  Docker Services              │  │
    │  │  - Frontend:  0.0.0.0:45902  │  │
    │  │  - API:       0.0.0.0:45000  │  │
    │  │  - Metabase:  0.0.0.0:45903  │  │
    │  │  - PostgreSQL: 127.0.0.1:25432│ │
    │  │  - MinIO:     127.0.0.1:45900│  │
    │  └──────────────────────────────┘  │
    └────────────────────────────────────┘
```

## Routing Rules

The Load Balancer routes requests based on the `Host` header:

| Hostname | Backend Service | VM Port | Docker Service |
|----------|----------------|---------|----------------|
| `smae.e-siri.com` | frontend-backend | 45902 | Frontend (Nginx/Vue) |
| `api.smae.e-siri.com` | api-backend | 45000 | NestJS API |
| `metadb.smae.e-siri.com` | metabase-backend | 45903 | Metabase |

## Key Benefits

### ✅ No Nginx Required on VM
- **Simpler deployment**: One less component to configure
- **Better performance**: No additional proxy layer
- **Direct routing**: Load Balancer sends traffic directly to correct port
- **Easier debugging**: Fewer layers to troubleshoot

### ✅ Better Isolation
- Each service has its own subdomain
- Can apply different security policies per service if needed
- Clear separation of concerns

### ✅ CORS Simplified
- Frontend (`smae.e-siri.com`) and API (`api.smae.e-siri.com`) are on different origins
- Easier to configure CORS policies
- More secure credential handling

### ✅ All Traffic Protected
- Cloud Armor protects all subdomains
- Rate limiting applies across all services
- Single SSL certificate covers all domains

## DNS Configuration

All subdomains point to the **same Load Balancer IP**:

```
smae.e-siri.com         A    35.x.x.x
api.smae.e-siri.com     A    35.x.x.x
metadb.smae.e-siri.com  A    35.x.x.x
```

## Port Binding

### Public Ports (Accessible via Load Balancer)
```bash
# Frontend - Bind to all interfaces
BIND_INTERFACE=""
SMAE_WEB_LISTEN=45902

# API - Bind to all interfaces  
SMAE_API_LISTEN=45000

# Metabase - Bind to all interfaces
METADB_LISTEN=45903
```

### Private Ports (Localhost Only)
```bash
# PostgreSQL - localhost only
BIND_INTERFACE="127.0.0.1:"
PG_DB_LISTEN=25432

# MinIO S3 - localhost only
MINIO_S3_LISTEN=45900
MINIO_CONSOLE_LISTEN=45901
```

## Security

### Network Level
- VM has **no public IP**
- Firewall allows **only Load Balancer** to reach ports 45000, 45902, 45903
- SSH only via **IAP** (Identity-Aware Proxy)

### Application Level
- **Cloud Armor** protects all subdomains
- Rate limiting: 100 req/min general, 20 req/min for login
- OWASP Top 10 protection
- DDoS mitigation

### Service Level
- Database and MinIO bind to **localhost only**
- No direct external access to sensitive services
- Docker network isolation

## Health Checks

Each backend service has its own health check:

| Service | Port | Path | Interval |
|---------|------|------|----------|
| Frontend | 45902 | `/` | 10s |
| API | 45000 | `/api/ping` | 10s |
| Metabase | 45903 | `/api/health` | 10s |

## Environment Variables

### Frontend (.env)
```bash
VITE_API_URL="https://api.smae.e-siri.com"
```

### Backend (.env)
```bash
URL_LOGIN_SMAE="https://smae.e-siri.com/login"
API_HOST_NAME="api.smae.e-siri.com"
MB_SITE_URL="https://metadb.smae.e-siri.com"
```

## Deployment Steps

1. **Apply Terraform**
   ```bash
   terraform apply
   ```

2. **Configure DNS** (all point to same IP)
   ```bash
   # Get Load Balancer IP
   terraform output load_balancer_ip
   
   # Create 3 DNS A records
   smae.e-siri.com         → 35.x.x.x
   api.smae.e-siri.com     → 35.x.x.x
   metadb.smae.e-siri.com  → 35.x.x.x
   ```

3. **Wait for SSL** (30-60 minutes)
   ```bash
   gcloud compute ssl-certificates describe siris-ssl-cert --global
   ```

4. **Configure VM**
   - SSH into VM via IAP
   - Install Docker & Docker Compose
   - Clone repository
   - Configure `.env` with correct subdomains
   - Start services: `docker compose --profile fullStack up -d`

5. **No Nginx Configuration Needed!**
   - Docker services bind directly to ports
   - Load Balancer routes to correct port based on hostname
   - Everything just works!

## Testing

```bash
# Test Frontend
curl -I https://smae.e-siri.com

# Test API
curl -I https://api.smae.e-siri.com/api/ping

# Test Metabase
curl -I https://metadb.smae.e-siri.com/api/health
```

## Troubleshooting

### Health Check Failing
```bash
# SSH into VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

# Test services locally
curl http://localhost:45902  # Frontend
curl http://localhost:45000/api/ping  # API
curl http://localhost:45903/api/health  # Metabase

# Check Docker services
docker compose ps
docker compose logs -f
```

### SSL Certificate Not Provisioning
```bash
# Check certificate status
gcloud compute ssl-certificates describe siris-ssl-cert --global

# Verify DNS
nslookup smae.e-siri.com
nslookup api.smae.e-siri.com
nslookup metadb.smae.e-siri.com

# All should return the same Load Balancer IP
```

### CORS Issues
Update API CORS configuration to allow frontend domain:
```typescript
// In NestJS app
app.enableCors({
  origin: ['https://smae.e-siri.com'],
  credentials: true,
});
```

## Migration from Path-Based to Subdomain

If migrating from path-based routing (`/api/`, `/metadb/`):

1. Update frontend API calls to use full URL
2. Update CORS configuration
3. Update `VITE_API_URL` in frontend `.env`
4. Update `MB_SITE_URL` for Metabase
5. No Nginx changes needed - remove Nginx entirely!

## Cost Comparison

**With Subdomain Architecture (No Nginx):**
- Same cost as path-based
- Actually slightly better performance (one less hop)

**Additional Benefits:**
- Easier to scale (can move services to separate VMs if needed)
- Better monitoring (separate backend services)
- Clearer logs (per-service metrics)
