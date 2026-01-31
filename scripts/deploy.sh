#!/bin/bash
set -euo pipefail

echo "==========================================="
echo "SMAE Deployment Script"
echo "==========================================="
echo "Timestamp: $(date)"
echo "Image Tag: ${IMAGE_TAG:-latest}"
echo ""

PROJECT_DIR="${HOME}/smae"
COMPOSE_FILE="docker-compose.production.yml"
IMAGE_TAG="${IMAGE_TAG:-latest}"

cd "$PROJECT_DIR"

echo "Step 1: Fetching secrets from Secret Manager..."
bash scripts/fetch-secrets.sh > .env 2>&1
chmod 600 .env
echo "✓ Secrets fetched and .env generated"
echo ""

echo "Step 2: Configuring Docker for Artifact Registry..."
gcloud auth configure-docker southamerica-east1-docker.pkg.dev --quiet
echo "✓ Docker configured"
echo ""

echo "Step 3: Pulling latest images..."
export IMAGE_TAG
docker compose -f "$COMPOSE_FILE" pull
echo "✓ Images pulled"
echo ""

echo "Step 4: Rolling restart of services..."
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
