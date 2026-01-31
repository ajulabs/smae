#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <commit-sha>"
    echo "Example: $0 abc123def456"
    echo ""
    echo "Available image tags:"
    echo "  - Use commit SHA from git log"
    echo "  - Or use 'latest' for most recent"
    exit 1
fi

ROLLBACK_TAG="$1"
PROJECT_DIR="${HOME}/smae"
COMPOSE_FILE="docker-compose.production.yml"

echo "==========================================="
echo "SMAE Rollback Script"
echo "==========================================="
echo "Timestamp: $(date)"
echo "Rolling back to: $ROLLBACK_TAG"
echo ""

cd "$PROJECT_DIR"

echo "Step 1: Verifying .env file exists..."
if [ ! -f .env ]; then
  echo "❌ Error: .env file not found"
  exit 1
fi
echo "✓ .env file found"
echo ""

echo "Step 2: Stopping all services..."
export IMAGE_TAG="$ROLLBACK_TAG"
docker compose -f "$COMPOSE_FILE" down
echo "✓ Services stopped"
echo ""

echo "Step 3: Pulling images for tag: $ROLLBACK_TAG..."
docker compose -f "$COMPOSE_FILE" pull
echo "✓ Images pulled"
echo ""

echo "Step 4: Starting services with rollback images..."
docker compose -f "$COMPOSE_FILE" --profile fullStack up -d
echo "✓ Services started"
echo ""

echo "Step 5: Waiting for services to stabilize..."
sleep 15
echo ""

echo "==========================================="
echo "✅ Rollback completed!"
echo "==========================================="
echo ""
echo "Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo ""
echo "⚠️  Please verify application is working correctly:"
echo "  - Frontend: https://smae.e-siri.com"
echo "  - API: https://api.smae.e-siri.com/api/ping"
echo "  - Metabase: https://metadb.smae.e-siri.com/api/health"
