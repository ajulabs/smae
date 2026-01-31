#!/bin/bash
set -euo pipefail

PROJECT_ID="stoked-coder-451819-v9"
SECRET_PREFIX="smae"

echo "# Generated from GCP Secret Manager at $(date)" >&2
echo "# Project: $PROJECT_ID" >&2
echo "# Prefix: $SECRET_PREFIX" >&2
echo "" >&2

declare -A SECRET_MAPPING=(
    ["$SECRET_PREFIX-postgres-password"]="POSTGRES_PASSWORD"
    ["$SECRET_PREFIX-mb-db-pass"]="MB_DB_PASS"
    ["$SECRET_PREFIX-minio-root-user"]="MINIO_ROOT_USER"
    ["$SECRET_PREFIX-minio-root-password"]="MINIO_ROOT_PASSWORD"
    ["$SECRET_PREFIX-s3-access-key"]="S3_ACCESS_KEY"
    ["$SECRET_PREFIX-s3-secret-key"]="S3_SECRET_KEY"
    ["$SECRET_PREFIX-session-jwt-secret"]="SESSION_JWT_SECRET"
    ["$SECRET_PREFIX-prisma-encryption-key"]="PRISMA_FIELD_ENCRYPTION_KEY"
    ["$SECRET_PREFIX-sof-api-token"]="SOF_API_TOKEN"
    ["$SECRET_PREFIX-sei-api-token"]="SEI_API_TOKEN"
    ["$SECRET_PREFIX-azure-key"]="AZURE_KEY"
)

if [ -f ".env.template" ]; then
    cat .env.template
    echo ""
fi

for SECRET_NAME in "${!SECRET_MAPPING[@]}"; do
    ENV_VAR="${SECRET_MAPPING[$SECRET_NAME]}"
    
    echo "Fetching $SECRET_NAME..." >&2
    
    SECRET_VALUE=$(gcloud secrets versions access latest \
        --secret="$SECRET_NAME" \
        --project="$PROJECT_ID" 2>/dev/null || echo "")
    
    if [ -n "$SECRET_VALUE" ]; then
        echo "$ENV_VAR=\"$SECRET_VALUE\""
        echo "✓ Fetched $ENV_VAR" >&2
    else
        echo "⚠️  Warning: Could not fetch $SECRET_NAME" >&2
    fi
done

POSTGRES_PASSWORD=$(gcloud secrets versions access latest --secret="$SECRET_PREFIX-postgres-password" --project="$PROJECT_ID" 2>/dev/null || echo "")
if [ -n "$POSTGRES_PASSWORD" ]; then
    POSTGRES_USER="${POSTGRES_USER:-smae}"
    POSTGRES_DB="${POSTGRES_DB:-smae_production}"
    echo "DATABASE_URL=\"postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB?schema=public&connection_limit=40\""
fi

echo "" >&2
echo "✅ .env generation complete!" >&2
