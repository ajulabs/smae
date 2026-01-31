#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "SMAE Auto-Deploy Setup"
echo "=========================================="
echo ""

PROJECT_DIR="$HOME/smae"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ Error: Project directory $PROJECT_DIR not found"
  echo "Please clone the repository first:"
  echo "  git clone git@github.com:ajulabs/smae.git ~/smae"
  exit 1
fi

cd "$PROJECT_DIR"

echo "Step 1: Verifying scripts are executable..."
chmod +x scripts/*.sh
echo "✓ Scripts are executable"
echo ""

echo "Step 2: Testing git fetch..."
if git fetch origin master --quiet 2>/dev/null; then
  echo "✓ Git fetch works"
else
  echo "❌ Git fetch failed. Please configure git credentials:"
  echo "  git config --global credential.helper store"
  echo "  git pull  # Enter credentials when prompted"
  exit 1
fi
echo ""

echo "Step 3: Testing Secret Manager access..."
if gcloud secrets versions access latest --secret="smae-postgres-password" --project=stoked-coder-451819-v9 >/dev/null 2>&1; then
  echo "✓ Can access secrets"
else
  echo "❌ Cannot access Secret Manager"
  echo "Ensure VM service account has secretAccessor role"
  exit 1
fi
echo ""

echo "Step 4: Creating log file..."
touch "$PROJECT_DIR/auto-deploy.log"
echo "[$(date)] Auto-deploy setup initiated" >> "$PROJECT_DIR/auto-deploy.log"
echo "✓ Log file created: $PROJECT_DIR/auto-deploy.log"
echo ""

echo "Step 5: Installing cron job..."
CRON_JOB="*/5 * * * * $PROJECT_DIR/scripts/check-and-deploy.sh"

(crontab -l 2>/dev/null | grep -v "check-and-deploy.sh"; echo "$CRON_JOB") | crontab -

if crontab -l | grep -q "check-and-deploy.sh"; then
  echo "✓ Cron job installed"
  echo ""
  echo "Cron schedule:"
  crontab -l | grep "check-and-deploy.sh"
else
  echo "❌ Failed to install cron job"
  exit 1
fi
echo ""

echo "Step 6: Testing deployment script..."
echo "This will test the deployment process (may take 15-20 minutes)..."
echo "Press Ctrl+C within 5 seconds to skip..."
sleep 5

if bash "$PROJECT_DIR/scripts/check-and-deploy.sh"; then
  echo "✓ Test deployment successful"
else
  echo "⚠️  Test deployment had issues. Check logs:"
  echo "  tail -100 $PROJECT_DIR/auto-deploy.log"
fi
echo ""

echo "=========================================="
echo "✅ Auto-Deploy Setup Complete!"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  - Polling interval: Every 5 minutes"
echo "  - Log file: $PROJECT_DIR/auto-deploy.log"
echo "  - Lock file: /tmp/smae-deploy.lock"
echo ""
echo "Monitoring:"
echo "  tail -f $PROJECT_DIR/auto-deploy.log"
echo ""
echo "Manual deployment:"
echo "  bash $PROJECT_DIR/scripts/deploy.sh"
echo ""
echo "Disable auto-deploy:"
echo "  crontab -e  # Remove the check-and-deploy.sh line"
echo ""
