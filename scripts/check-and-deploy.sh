#!/bin/bash
set -eo pipefail

PROJECT_DIR="$HOME/smae"
LOCK_FILE="/tmp/smae-deploy.lock"
LOG_FILE="$PROJECT_DIR/auto-deploy.log"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "[$(date)] Error: Project directory $PROJECT_DIR not found" >> "$LOG_FILE"
  exit 1
fi

if [ -f "$LOCK_FILE" ]; then
  exit 0
fi

cd "$PROJECT_DIR"

git fetch origin master --quiet 2>/dev/null || {
  echo "[$(date)] Error: git fetch failed" >> "$LOG_FILE"
  exit 1
}

LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE=$(git rev-parse origin/master 2>/dev/null)

if [ "$LOCAL" = "$REMOTE" ]; then
  exit 0
fi

echo "=============================================" >> "$LOG_FILE"
echo "[$(date)] NEW COMMITS DETECTED" >> "$LOG_FILE"
echo "Local:  $LOCAL" >> "$LOG_FILE"
echo "Remote: $REMOTE" >> "$LOG_FILE"
echo "=============================================" >> "$LOG_FILE"

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

echo "[$(date)] Pulling latest changes..." >> "$LOG_FILE"
git pull origin master >> "$LOG_FILE" 2>&1

echo "[$(date)] Starting deployment..." >> "$LOG_FILE"

if bash "$PROJECT_DIR/scripts/deploy.sh" >> "$LOG_FILE" 2>&1; then
  echo "[$(date)] ✅ DEPLOYMENT SUCCESSFUL" >> "$LOG_FILE"
  echo "=============================================" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  exit 0
else
  EXITCODE=$?
  echo "[$(date)] ❌ DEPLOYMENT FAILED (exit code: $EXITCODE)" >> "$LOG_FILE"
  echo "=============================================" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  exit 1
fi
