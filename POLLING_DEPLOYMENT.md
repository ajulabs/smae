# Polling-Based Auto-Deployment Guide

## Overview

SMAE uses **git polling** for automatic deployments. A cron job checks GitHub every 5 minutes for new commits and automatically deploys them.

## Why Polling Instead of GitHub Actions?

**GitHub forks cannot access organization or repository secrets**, making GitHub Actions CI/CD impossible. Polling solves this elegantly:

- Works perfectly with forked repositories
- No secrets needed in GitHub
- Maintains no-public-IP security model
- Simple and reliable
- Zero additional cost

## How It Works

```
Every 5 minutes:
  1. Cron job executes check-and-deploy.sh
  2. Script fetches latest commit from GitHub
  3. Compares with local commit
  
  If commits differ (new push detected):
    4. git pull latest code
    5. Fetch secrets from GCP Secret Manager
    6. Generate .env file
    7. Build Docker images locally (~10-15 min)
    8. Rolling restart services (~2-3 min)
    9. Log deployment result
    
  If commits same:
    Exit (no deployment needed)
```

## Deployment Timeline

**From push to deployed**:
- Maximum 5 minutes: Wait for next poll
- 10-15 minutes: Build images (first time)
- 2-3 minutes: Deploy services
- **Total**: 17-23 minutes

**Subsequent deployments** (with cache): 10-15 minutes

## Initial Setup on VM

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

# Logout and login for docker group
exit
```

### Step 3: Clone Repository

```bash
# SSH back
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap --project=stoked-coder-451819-v9

# Clone repo
git clone https://github.com/ajulabs/smae.git ~/smae
cd ~/smae

# Verify scripts exist
ls -la scripts/
```

### Step 4: Configure Auto-Deploy

```bash
cd ~/smae

# Run setup script
bash scripts/setup-auto-deploy.sh
```

This script will:
- Verify git access
- Test Secret Manager access
- Install cron job (runs every 5 minutes)
- Run test deployment
- Create log file

### Step 5: Monitor First Deployment

```bash
# Watch deployment logs in real-time
tail -f ~/smae/auto-deploy.log
```

## Manual Deployment

To deploy manually (without waiting for poll):

```bash
# SSH to VM
gcloud compute ssh siris --zone=southamerica-east1-a --tunnel-through-iap

cd ~/smae
bash scripts/deploy.sh
```

## Monitoring

### View Deployment Logs

```bash
# Real-time logs
tail -f ~/smae/auto-deploy.log

# Last 100 lines
tail -100 ~/smae/auto-deploy.log

# Search for deployments
grep "DEPLOYMENT" ~/smae/auto-deploy.log

# View today's activity
grep "$(date +%Y-%m-%d)" ~/smae/auto-deploy.log
```

### Check Cron Status

```bash
# View cron jobs
crontab -l

# Check if cron is running check-and-deploy
ps aux | grep check-and-deploy
```

### Check Deployment Lock

```bash
# If deployment is running, lock file exists
ls -la /tmp/smae-deploy.lock

# If stuck, remove lock (only if safe!)
rm /tmp/smae-deploy.lock
```

### View Container Status

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
```

## Adjusting Polling Interval

### Change to Every Minute (More Responsive)

```bash
crontab -e

# Change from:
*/5 * * * * /home/ubuntu/smae/scripts/check-and-deploy.sh

# To:
* * * * * /home/ubuntu/smae/scripts/check-and-deploy.sh
```

### Change to Every 10 Minutes (Less Overhead)

```bash
crontab -e

# Change to:
*/10 * * * * /home/ubuntu/smae/scripts/check-and-deploy.sh
```

## Disabling Auto-Deploy

To temporarily disable automatic deployments:

```bash
# Comment out cron job
crontab -e

# Add # at the beginning of the line:
# */5 * * * * /home/ubuntu/smae/scripts/check-and-deploy.sh
```

To re-enable, remove the `#`.

## Troubleshooting

### Deployments Not Running

**Check cron is installed:**
```bash
crontab -l | grep check-and-deploy
```

**Check logs for errors:**
```bash
tail -50 ~/smae/auto-deploy.log
grep "Error" ~/smae/auto-deploy.log
```

**Test script manually:**
```bash
cd ~/smae
bash scripts/check-and-deploy.sh
```

### Deployment Stuck

**Symptoms**: Lock file exists for > 30 minutes

**Solution**:
```bash
# Check if deployment is really running
ps aux | grep -E "deploy.sh|docker"

# If nothing running, remove lock
rm /tmp/smae-deploy.lock

# Next poll will retry
```

### Git Fetch Fails

**Error**: "git fetch failed" in logs

**Solution**:
```bash
# Test git access
cd ~/smae
git fetch origin master

# If fails, configure credentials
git config --global credential.helper store
git pull  # Enter credentials when prompted
```

### Out of Disk Space

**Error**: Docker build fails with "no space left"

**Solution**:
```bash
# Clean up old images
docker system prune -a -f

# Check disk space
df -h

# View large Docker objects
docker system df
```

### Build Takes Too Long

**Symptoms**: Build > 20 minutes

**Solution**:
```bash
# Check build logs
tail -200 ~/smae/auto-deploy.log | grep "Building"

# Build manually to see progress
cd ~/smae
docker compose -f docker-compose.production.yml build --progress=plain
```

## Deployment Workflow

### Normal Flow

```bash
# Developer pushes to master
git push origin master

# Within 5 minutes, VM polls and detects change
# Deployment starts automatically
# Logs written to ~/smae/auto-deploy.log

# After 15-20 minutes, deployment complete
# Services are live with new code
```

### Failed Deployment

If deployment fails:
1. Check logs: `tail -100 ~/smae/auto-deploy.log`
2. Fix the issue in code
3. Push fix to master
4. Next poll (within 5 min) will retry
5. Or deploy manually: `bash ~/smae/scripts/deploy.sh`

### Rollback

```bash
# SSH to VM
cd ~/smae

# Find previous commit
git log --oneline -10

# Rollback to specific commit
bash scripts/rollback.sh <commit-sha>
```

## Log Management

### Log Rotation

Logs automatically cleaned weekly (configured in cron):

```cron
# Keep logs for 28 days
0 0 * * 0 find /home/ubuntu/smae -name "*.log" -mtime +28 -delete
```

### Manual Log Cleanup

```bash
# Archive old logs
tar -czf ~/smae/auto-deploy-$(date +%Y%m%d).log.tar.gz ~/smae/auto-deploy.log

# Truncate current log
> ~/smae/auto-deploy.log
```

## Performance Considerations

### Build Resource Usage

During build (10-15 minutes):
- **CPU**: High (all 4 vCPUs utilized)
- **Memory**: 6-8 GB
- **Disk I/O**: Moderate
- **Network**: Docker pulls base images

**Services continue running** during build (no downtime).

### Polling Overhead

Minimal:
- Runs every 5 minutes
- Takes <1 second if no changes
- Network: ~10 KB per fetch
- CPU: Negligible

## Advanced Configuration

### Custom Polling Script Location

If you move the project:

```bash
# Update cron job
crontab -e

# Change path to match new location
*/5 * * * * /path/to/new/location/scripts/check-and-deploy.sh
```

### Email Notifications on Deployment

Add to check-and-deploy.sh:

```bash
# After deployment success/failure
echo "Deployment result" | mail -s "SMAE Deployment" your@email.com
```

### Slack Notifications

```bash
# After deployment
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"SMAE deployed successfully"}' \
  YOUR_SLACK_WEBHOOK_URL
```

## Comparison with GitHub Actions

| Feature | GitHub Actions | Polling |
|---------|----------------|---------|
| Works with forks | ❌ No | ✅ Yes |
| Deployment speed | Fast (~5-10 min) | Slower (~20-25 min) |
| Secrets in GitHub | ✅ Required | ❌ Not needed |
| Build location | GitHub servers | Your VM |
| Cost | Free tier limited | $0 extra |
| Security | Exposes secrets to GitHub | Secrets stay in GCP |
| Complexity | Medium | Low |
| Debugging | GitHub UI | SSH + logs |

## Best Practices

1. **Monitor logs regularly**: `tail -f ~/smae/auto-deploy.log`
2. **Test deployments locally** before pushing to master
3. **Keep builds fast**: Optimize Dockerfiles
4. **Check disk space**: Run `docker system prune` periodically
5. **Verify cron is running**: Check logs daily
6. **Document changes**: Use descriptive commit messages
7. **Test rollback procedure**: Practice before you need it

## Security

### Git Access

- Uses HTTPS (no SSH keys in cron)
- Credentials stored in git credential helper
- Only reads from GitHub (no write access needed)

### Secrets

- Fetched from Secret Manager on every deployment
- Never stored permanently on disk
- .env file regenerated each deployment
- Permissions 600 (readable only by owner)

### Deployment Lock

- Prevents concurrent deployments
- Automatic cleanup on script exit
- Safe to remove manually if stuck

---

**Your auto-deployment is now active!** Push to master and check logs in ~5-20 minutes.
