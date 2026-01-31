# VM Setup - Now Simplified!

## What Changed

**Removed complexity**:
- ❌ Secret Manager (not needed)
- ❌ GitHub Actions (doesn't work with forks)
- ❌ Artifact Registry (not needed for local builds)
- ❌ Workload Identity (not needed)

**Simplified to**:
- ✅ Manual .env file on VM
- ✅ Git polling every 5 minutes
- ✅ Local Docker builds
- ✅ Rolling deployments

## Current Status

**Infrastructure**: ✅ Deployed
- Load Balancer IP: `34.120.94.14`
- VM: `siris` (no public IP)
- Cloud Armor: Active
- SSL Certificate: Ready for 3 domains

**Secrets**: Deleted from Secret Manager

**Deployment**: Git polling (cron-based)

## Setup on VM

### Quick Setup

```bash
# 1. SSH
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# 2. Install Docker
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER
exit

# 3. SSH back, clone repo
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9
git clone https://github.com/ajulabs/smae.git ~/smae
cd ~/smae

# 4. Create .env
cp .env.production.example .env
nano .env
# UPDATE: API_HOST_NAME, VITE_API_URL, MB_SITE_URL, passwords

# 5. Deploy
bash scripts/deploy.sh

# 6. Enable auto-deploy
bash scripts/setup-auto-deploy.sh
```

## DNS Configuration

Create 3 A records pointing to `34.120.94.14`:

```
smae.e-siri.com         A    34.120.94.14
api.smae.e-siri.com     A    34.120.94.14
metadb.smae.e-siri.com  A    34.120.94.14
```

## After Setup

**Push to master = Auto-deploy!**

```bash
git push origin master

# Check logs on VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap -- "tail -f ~/smae/auto-deploy.log"
```

**Timeline**: Push to deployed in 20-25 minutes max

## Files You Need

**Setup Guide**: [`SIMPLE_DEPLOYMENT.md`](SIMPLE_DEPLOYMENT.md)

**Quick Reference**: [`QUICKSTART_VM.md`](QUICKSTART_VM.md)

**Infrastructure**: [`terraform/README.md`](terraform/README.md)

**Architecture**: [`terraform/ARCHITECTURE.md`](terraform/ARCHITECTURE.md)

## Cost

**Total**: ~$250/month
- No Secret Manager cost
- No Artifact Registry cost (optional)
- No GitHub Actions cost

## Benefits of Simplified Approach

1. **Easier to understand** - No complex secret management
2. **Easier to debug** - .env file right there on VM
3. **Works with forks** - No GitHub limitations
4. **No external dependencies** - Everything on VM
5. **Direct control** - Edit .env anytime
6. **Still automated** - Polling handles deployments
7. **Still secure** - VM has no public IP, Cloud Armor active

---

**Ready to go! Just setup the VM and start pushing code.** 🚀
