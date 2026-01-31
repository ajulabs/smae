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

echo "Step 2: Building Docker images locally..."
docker compose -f "$COMPOSE_FILE" build --parallel
echo "✓ Build complete"
echo ""

echo "Step 3: Rolling restart of services..."
echo ""

SERVICES=(
  "smae_orcamento"
  "smae_geoloc"
  "smae_sei"
  "smae_transferegov"
  "smae_transferegov_transferencias"
  "email_service"
  "gotenberg"
  "smae_api"
  "web"
)

for SERVICE in "${SERVICES[@]}"; do
  echo "  → Restarting $SERVICE..."
  
  OLD_CONTAINER=$(docker ps -q -f name="$SERVICE" || echo "")
  
  docker compose -f "$COMPOSE_FILE" up -d --no-deps "$SERVICE"
  
  echo "    Waiting for health check..."
  sleep 10
  
  NEW_CONTAINER=$(docker ps -q -f name="$SERVICE" || echo "")
  
  if [ -n "$NEW_CONTAINER" ]; then
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$NEW_CONTAINER" 2>/dev/null || echo "unknown")
    STATUS=$(docker inspect --format='{{.State.Status}}' "$NEW_CONTAINER" 2>/dev/null || echo "unknown")
    
    if [ "$STATUS" == "running" ]; then
      echo "    ✓ $SERVICE is running (health: $HEALTH)"
    else
      echo "    ✗ $SERVICE failed to start!"
      echo "    Rolling back..."
      
      if [ -n "$OLD_CONTAINER" ]; then
        docker start "$OLD_CONTAINER" || true
      fi
      
      echo "Deployment failed at $SERVICE. Please check logs:"
      docker compose -f "$COMPOSE_FILE" logs --tail=50 "$SERVICE"
      exit 1
    fi
  else
    echo "    ⚠  Warning: Could not find container for $SERVICE"
  fi
  
  echo ""
done

echo "Step 4: Cleaning up old images..."
docker image prune -f
echo "✓ Cleanup complete"
echo ""

echo "==========================================="
echo "✅ Deployment completed successfully!"
echo "==========================================="
echo ""
echo "Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
