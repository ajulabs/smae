#!/bin/bash
set -eo pipefail

PROJECT_DIR="$HOME/smae"
LOCK_FILE="/tmp/smae-deploy.lock"
LOG_FILE="$PROJECT_DIR/auto-deploy.log"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Project directory $PROJECT_DIR not found" >> "$LOG_FILE"
  exit 1
fi

if [ -f "$LOCK_FILE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏳ Deployment already in progress, skipping poll" >> "$LOG_FILE"
  exit 0
fi

cd "$PROJECT_DIR"

git fetch origin master --quiet 2>/dev/null || {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Error: git fetch failed" >> "$LOG_FILE"
  exit 1
}

LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE=$(git rev-parse origin/master 2>/dev/null)

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ No changes detected (local: ${LOCAL:0:8})" >> "$LOG_FILE"
  exit 0
fi

echo "=============================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 NEW COMMITS DETECTED" >> "$LOG_FILE"
echo "Local:  $LOCAL" >> "$LOG_FILE"
echo "Remote: $REMOTE" >> "$LOG_FILE"
echo "=============================================" >> "$LOG_FILE"

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling latest changes..." >> "$LOG_FILE"
git pull origin master >> "$LOG_FILE" 2>&1

if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: .env file not found, skipping deployment" >> "$LOG_FILE"
  echo "=============================================" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting deployment..." >> "$LOG_FILE"

if bash "$PROJECT_DIR/scripts/deploy.sh" >> "$LOG_FILE" 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ DEPLOYMENT SUCCESSFUL" >> "$LOG_FILE"
  echo "=============================================" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  exit 0
else
  EXITCODE=$?
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ DEPLOYMENT FAILED (exit code: $EXITCODE)" >> "$LOG_FILE"
  echo "=============================================" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  exit 1
fi
