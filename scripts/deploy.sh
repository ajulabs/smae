#!/bin/bash
set -euo pipefail

echo "==========================================="
echo "SMAE Deployment Script"
echo "==========================================="
echo "Timestamp: $(date)"
echo ""

PROJECT_DIR="${HOME}/smae"
COMPOSE_FILE="docker-compose.production.yml"
LOCK_FILE="/tmp/smae-deploy.lock"

cd "$PROJECT_DIR"

if [ -f "$LOCK_FILE" ]; then
  echo "⚠️  Deployment already running (lock file exists)"
  echo "If this is an error, remove: $LOCK_FILE"
  exit 1
fi

trap "rm -f $LOCK_FILE" EXIT
touch "$LOCK_FILE"
echo "✓ Deployment lock acquired"
echo ""

echo "Step 1: Verifying .env file exists..."
if [ ! -f .env ]; then
  echo "❌ Error: .env file not found"
  echo "Please create .env file with production configuration"
  exit 1
fi
chmod 600 .env
echo "✓ .env file found"
echo ""

echo "Step 2: Building and deploying services..."
docker compose -f "$COMPOSE_FILE" --profile fullStack up --build -d
echo "✓ Services built and started"
echo ""

echo "Step 3: Waiting for services to stabilize..."
sleep 15
echo ""

echo "Step 4: Verifying services..."
FAILED=0
for SERVICE in smae_api web metabase smae_orcamento smae_geoloc smae_sei smae_transferegov smae_transferegov_transferencias email_service gotenberg; do
  if docker ps | grep -q "$SERVICE"; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "$SERVICE" 2>/dev/null || echo "unknown")
    if [ "$STATUS" == "running" ]; then
      echo "  ✓ $SERVICE: running"
    else
      echo "  ✗ $SERVICE: $STATUS"
      FAILED=1
    fi
  else
    echo "  ⚠  $SERVICE: not found"
  fi
done
echo ""

if [ $FAILED -eq 1 ]; then
  echo "⚠️  Some services failed. Check logs:"
  docker compose -f "$COMPOSE_FILE" logs --tail=50
  exit 1
fi

echo "Step 5: Cleaning up old images..."
docker image prune -f
echo "✓ Cleanup complete"
echo ""

echo "==========================================="
echo "✅ Deployment completed successfully!"
echo "==========================================="
echo ""
echo "Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
