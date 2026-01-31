#!/bin/bash
set -euo pipefail

echo "SMAE Health Check"
echo "=================="
echo ""

check_url() {
    local name="$1"
    local url="$2"
    
    if curl -s -f -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|301\|302"; then
        echo "✓ $name: OK"
        return 0
    else
        echo "✗ $name: FAILED"
        return 1
    fi
}

echo "Checking local services..."
check_url "Frontend" "http://localhost:45902" || true
check_url "API" "http://localhost:45000/api/ping" || true
check_url "Metabase" "http://localhost:45903/api/health" || true
echo ""

echo "Checking public endpoints..."
check_url "Frontend (Public)" "https://smae.e-siri.com" || true
check_url "API (Public)" "https://api.smae.e-siri.com/api/ping" || true
check_url "Metabase (Public)" "https://metadb.smae.e-siri.com/api/health" || true
echo ""

echo "Docker containers status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
