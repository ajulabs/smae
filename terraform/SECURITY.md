# SMAE Security Architecture

This document explains the multi-layer security architecture implemented in this Terraform configuration.

## Security Philosophy

**Defense in Depth**: Multiple independent security layers ensure that if one layer is compromised, others continue to protect the application.

## Security Layers

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Cloud Armor WAF (Application Layer)            │
│ - OWASP Top 10 protection                               │
│ - Rate limiting & DDoS protection                       │
│ - Geo-filtering                                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Load Balancer (Transport Layer)                │
│ - SSL/TLS termination                                   │
│ - HTTP to HTTPS redirect                                │
│ - Health checking                                       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Network Isolation (Network Layer)              │
│ - Private VPC                                           │
│ - No public IP on VM                                    │
│ - Strict firewall rules                                 │
│ - Cloud NAT (outbound only)                             │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 4: VM Access Control (Host Layer)                 │
│ - SSH via IAP only (requires Google auth)               │
│ - OS-level firewall                                     │
│ - Nginx reverse proxy                                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 5: Service Isolation (Application Layer)          │
│ - Services bind to 127.0.0.1 only                       │
│ - No direct external access to databases                │
│ - Docker network isolation                              │
└─────────────────────────────────────────────────────────┘
```

## Layer 1: Cloud Armor WAF

### What It Does
Cloud Armor acts as a Web Application Firewall (WAF) that inspects every HTTP/HTTPS request **before** it reaches your infrastructure.

### Protections Enabled

#### OWASP Top 10 Protection
- **SQL Injection (SQLi)**: Blocks attempts like `' OR '1'='1`
- **Cross-Site Scripting (XSS)**: Blocks `<script>` tags and malicious JavaScript
- **Local File Inclusion (LFI)**: Prevents access to system files
- **Remote Code Execution (RCE)**: Blocks command injection attempts
- **Remote File Inclusion (RFI)**: Prevents loading remote malicious files
- **PHP Injection**: Blocks PHP-specific attacks
- **Session Fixation**: Prevents session hijacking
- **Protocol Attacks**: Blocks HTTP protocol violations
- **Scanner Detection**: Blocks security scanners and automated bots
- **Method Enforcement**: Only allows valid HTTP methods

#### Rate Limiting
- **General Traffic**: 100 requests per minute per IP
- **Login Endpoints**: 20 requests per minute per IP (stricter)
- **Automatic Banning**: IPs exceeding limits are banned for 10-30 minutes

#### Advanced Features
- **Adaptive Protection**: ML-based detection of DDoS attacks
- **Geo-Filtering**: Optional country-level blocking
- **CVE Protection**: Blocks known CVE exploitation attempts

### Why This Matters
Even if your application has vulnerabilities, Cloud Armor blocks exploitation attempts **before** they reach your code.

## Layer 2: Load Balancer Security

### SSL/TLS Termination
- **Managed SSL Certificate**: Google automatically provisions and renews SSL certificates
- **TLS 1.2+**: Only secure TLS versions allowed
- **Perfect Forward Secrecy**: Each session uses unique encryption keys

### HTTP to HTTPS Redirect
- All HTTP traffic automatically redirected to HTTPS
- Prevents man-in-the-middle attacks
- Ensures all data transmitted is encrypted

### Health Checking
- Continuously monitors application availability
- Automatically stops sending traffic to unhealthy instances
- Prevents cascading failures

## Layer 3: Network Isolation

### Private VPC
Your VM runs in an isolated Virtual Private Cloud with:
- Custom IP ranges (10.0.1.0/24)
- No default internet access
- Complete network separation from other GCP resources

### No Public IP
**Critical Security Feature**: The VM has **no external IP address**

**This means**:
- VM is invisible to internet scanners
- Cannot be directly accessed from internet
- Port scanning attacks are impossible
- Direct SSH attacks are impossible

### Firewall Rules

Only 3 types of traffic are allowed:

1. **Load Balancer Traffic** (sources: 35.191.0.0/16, 130.211.0.0/22)
   - Port 80 for HTTP
   - Only from Google's Load Balancer IP ranges

2. **Health Check Traffic** (sources: 35.191.0.0/16, 130.211.0.0/22)
   - Health check probes
   - Only from Google's health check IP ranges

3. **SSH via IAP** (source: 35.235.240.0/20)
   - SSH access only through Google IAP
   - Requires Google authentication
   - All other SSH attempts blocked

**Everything else is DENIED by default.**

### Cloud NAT
- VM can make **outbound** connections (Docker Hub, apt repositories)
- Internet **cannot** initiate connections to VM
- One-way communication only

## Layer 4: VM Access Control

### SSH via Identity-Aware Proxy (IAP)

Traditional SSH problems:
- ❌ Requires public IP
- ❌ Exposed to brute force attacks
- ❌ Requires managing SSH keys
- ❌ Difficult to audit access

IAP Solution:
- ✅ No public IP needed
- ✅ Authentication via Google credentials
- ✅ MFA enforced (if enabled in Google Workspace)
- ✅ Complete audit trail of all access
- ✅ Can restrict by user/group

**To SSH**: Must have Google account with IAM permission `roles/iap.tunnelResourceAccessor`

### Nginx Reverse Proxy

All external traffic goes through Nginx, which:
- Routes requests to correct Docker service
- Adds security headers
- Can implement additional rate limiting
- Logs all access
- Can block/allow specific paths

## Layer 5: Service Isolation

### Critical Configuration: `BIND_INTERFACE="127.0.0.1:"`

**This is THE most important application-level security setting.**

#### Without This Setting (INSECURE)
```
BIND_INTERFACE=""  ← Services bind to 0.0.0.0
```
- PostgreSQL listens on `0.0.0.0:25432` (accessible from network)
- MinIO listens on `0.0.0.0:45900` (accessible from network)
- If someone compromises the network, they can access all services

#### With This Setting (SECURE)
```
BIND_INTERFACE="127.0.0.1:"  ← Services bind to localhost
```
- PostgreSQL listens on `127.0.0.1:25432` (only accessible from same VM)
- MinIO listens on `127.0.0.1:45900` (only accessible from same VM)
- Even if network is compromised, services remain isolated

### Service Breakdown

| Service | Port | Binding | Accessible From |
|---------|------|---------|-----------------|
| PostgreSQL | 25432 | 127.0.0.1 | Same VM only |
| MinIO S3 | 45900 | 127.0.0.1 | Same VM only |
| MinIO Console | 45901 | 127.0.0.1 | Same VM only |
| Metabase | 45903 | 127.0.0.1 | Same VM only |
| API | 45000 | 127.0.0.1 | Same VM only |
| Frontend | 45902 | 127.0.0.1 | Same VM only |
| Nginx | 80 | 0.0.0.0 | Load Balancer only (firewall enforced) |

**Only Nginx on port 80** accepts network traffic, and that's restricted to Load Balancer by firewall.

## Monitoring & Detection

### What's Logged
- Every request to Load Balancer
- Every Cloud Armor block/allow decision
- Firewall allow/deny decisions
- VM system logs
- SSH access attempts

### Alert Policies
- High volume of blocked requests (potential attack)
- Health check failures (service disruption)
- Unusual traffic patterns (anomaly detection)

### Security Dashboard
Real-time visibility into:
- Request rates and patterns
- Cloud Armor actions
- Backend latency
- VM resource usage

## Attack Scenarios & Defenses

### Scenario 1: DDoS Attack
**Attack**: Attacker floods application with millions of requests

**Defense**:
1. Cloud Armor's Adaptive Protection detects unusual traffic
2. Rate limiting kicks in after 100 req/min per IP
3. IPs are automatically banned
4. Legitimate traffic continues unaffected

### Scenario 2: SQL Injection Attempt
**Attack**: Attacker tries `https://smae.e-siri.com/api/users?id=1' OR '1'='1`

**Defense**:
1. Cloud Armor's SQLi rule detects the pattern
2. Request blocked with 403 Forbidden
3. Attack logged for security review
4. Attacker's IP may be banned
5. Application never sees the malicious request

### Scenario 3: Port Scanning
**Attack**: Attacker scans for open ports

**Defense**:
1. VM has no public IP - not visible to scanners
2. Only Load Balancer IP is visible
3. Cloud Armor blocks scanner user agents
4. All ports except 80/443 on LB are closed
5. Scanner learns nothing about infrastructure

### Scenario 4: Direct Database Access Attempt
**Attack**: Attacker discovers PostgreSQL uses port 25432 and tries to connect

**Defense**:
1. Firewall blocks all traffic except from LB and IAP
2. PostgreSQL binds to 127.0.0.1 - not accessible from network
3. Even if attacker is inside the VM's network, localhost binding prevents access
4. Attacker needs to compromise the VM itself to access database

### Scenario 5: SSH Brute Force
**Attack**: Attacker tries to brute force SSH password

**Defense**:
1. VM has no public IP - SSH port not exposed
2. SSH only via IAP which requires Google authentication
3. Can enforce MFA via Google Workspace
4. No password authentication possible via IAP
5. All access attempts logged and audited

### Scenario 6: Application Vulnerability Exploit
**Attack**: Zero-day vulnerability discovered in SMAE application

**Defense**:
1. Cloud Armor may block if exploit matches OWASP patterns
2. Rate limiting prevents rapid exploitation attempts
3. Services isolated - compromising API doesn't give database access
4. No public IP - attacker can't pivot to other internal resources
5. Monitoring detects unusual patterns
6. VM can be quickly replaced via Terraform

## Security Best Practices

### Implemented ✅
- Multi-layer defense in depth
- Zero trust architecture (no public IP)
- Principle of least privilege (strict firewall)
- Security monitoring and logging
- Automated SSL certificate management
- Rate limiting and DDoS protection
- Service isolation via localhost binding

### Recommended ⚠️
1. **Rotate Credentials Quarterly**
   - Database passwords
   - API keys
   - Session secrets
   - MinIO credentials

2. **Regular Updates**
   ```bash
   # Weekly: Update Docker images
   docker compose pull
   docker compose up -d
   
   # Monthly: Update OS packages
   sudo apt-get update && sudo apt-get upgrade
   ```

3. **Backup Strategy**
   - Automated daily backups of PostgreSQL
   - Store backups in different region
   - Test restoration monthly
   - Keep 30 days of daily backups

4. **Access Control**
   - Use separate GCP service accounts per service
   - Enable MFA for all users
   - Review IAM permissions monthly
   - Use least-privilege principle

5. **Security Scanning**
   ```bash
   # Scan Docker images for vulnerabilities
   docker scan smae_api:latest
   ```

6. **Application Security**
   - Keep SMAE application updated
   - Review code for vulnerabilities
   - Implement input validation
   - Use parameterized queries

## Compliance Considerations

This architecture helps with:
- **GDPR**: Data encryption in transit (TLS) and at rest (GCP default)
- **PCI DSS**: Network segmentation and access controls
- **SOC 2**: Logging, monitoring, and audit trails
- **LGPD** (Brazil): Data protection and security controls

**Note**: This infrastructure alone doesn't guarantee compliance. Application-level controls and policies are also required.

## Cost of Security

| Security Feature | Monthly Cost |
|------------------|--------------|
| Cloud Armor | ~$15 |
| Load Balancer | ~$25 |
| Cloud Logging | ~$5-10 |
| Monitoring | Included |
| Managed SSL | Free |
| VPC | Free |
| IAP | Free |
| **Total Security Cost** | **~$45-50/month** |

**Value**: Protection against attacks that could cause downtime, data breaches, or reputational damage.

## Security Incident Response

If you suspect a security incident:

1. **Immediate Actions**
   ```bash
   # Check Cloud Armor logs
   gcloud logging read 'jsonPayload.enforcedSecurityPolicy.outcome="DENY"' --limit 100
   
   # Check access logs
   gcloud logging read "resource.type=http_load_balancer" --limit 100
   
   # Check VM logs
   docker compose logs --tail=1000
   ```

2. **Investigation**
   - Review security dashboard for anomalies
   - Check for unusual traffic patterns
   - Review recent configuration changes
   - Check for unauthorized access

3. **Containment**
   ```bash
   # Block suspicious IPs via Cloud Armor
   # Rotate credentials if compromised
   # Scale down or stop affected services
   ```

4. **Recovery**
   - Restore from backup if needed
   - Apply security patches
   - Update firewall rules
   - Deploy fresh infrastructure via Terraform

## Questions & Answers

**Q: Can someone hack the database directly?**
A: No. Database binds to localhost only and VM has no public IP. To access database, attacker would need to: (1) compromise Load Balancer (impossible), (2) bypass Cloud Armor (very difficult), (3) exploit application vulnerability to get code execution, (4) only then could access localhost database.

**Q: What if Cloud Armor is bypassed?**
A: Traffic would still hit firewall, which only allows LB sources. Then would hit Nginx on VM. Services still isolated via localhost binding. Multiple layers still protect.

**Q: Is this more secure than a public VM with firewall rules?**
A: Yes, significantly. Public IP exposes VM to automated scanning, zero-day exploits, and various attacks. No public IP = not visible = cannot be directly attacked.

**Q: Can we make it even more secure?**
A: Yes:
- Use GCP Secret Manager for credentials
- Enable VPC Service Controls
- Use private Google Access
- Implement application-level encryption
- Enable audit logging for data access
- Use Workload Identity for service accounts

**Q: What's the weakest point?**
A: Application vulnerabilities. Cloud Armor protects against known attacks, but zero-day vulnerabilities in SMAE code itself could be exploited. Keep application updated and follow secure coding practices.

## Summary

This infrastructure implements **enterprise-grade security** using Google Cloud Platform's best practices and security features. The combination of Cloud Armor, network isolation, service binding, and comprehensive monitoring creates a robust defense against most attack vectors.

**Key Takeaway**: Multiple independent security layers ensure that compromising one layer doesn't grant access to your data or services.

---

**Last Updated**: 2026-01-31
**Security Level**: Enterprise Grade
**Threat Model**: Internet-facing web application with sensitive data
