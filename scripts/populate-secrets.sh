#!/usr/bin/env bash
set -eo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path-to-.env-file>"
    echo "Example: $0 .env.production"
    exit 1
fi

ENV_FILE="$1"
PROJECT_ID="stoked-coder-451819-v9"
SECRET_PREFIX="smae"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: File $ENV_FILE not found"
    exit 1
fi

echo "Reading secrets from $ENV_FILE and uploading to GCP Secret Manager..."
echo "Project: $PROJECT_ID"
echo "Prefix: $SECRET_PREFIX"
echo ""

upload_secret() {
    local ENV_VAR="$1"
    local SECRET_NAME="$2"
    
    local SECRET_VALUE
    SECRET_VALUE=$(grep "^${ENV_VAR}=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
    
    if [ -z "$SECRET_VALUE" ]; then
        echo "⚠️  Skipping $SECRET_NAME - value not found"
        return
    fi
    
    if [[ "$SECRET_VALUE" == "CHANGE_ME"* ]] || [[ "$SECRET_VALUE" == "YOUR_"* ]] || [[ "$SECRET_VALUE" == "REPLACE_"* ]]; then
        echo "⚠️  Skipping $SECRET_NAME - placeholder detected"
        return
    fi
    
    echo "Processing: $SECRET_NAME"
    
    if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
        echo "$SECRET_VALUE" | gcloud secrets versions add "$SECRET_NAME" \
            --project="$PROJECT_ID" \
            --data-file=- 2>&1 | grep -v "WARNING" || true
        echo "✓ Updated: $SECRET_NAME"
    else
        echo "$SECRET_VALUE" | gcloud secrets create "$SECRET_NAME" \
            --project="$PROJECT_ID" \
            --replication-policy="automatic" \
            --data-file=- 2>&1 | grep -v "WARNING" || true
        echo "✓ Created: $SECRET_NAME"
    fi
}

upload_secret "POSTGRES_PASSWORD" "$SECRET_PREFIX-postgres-password"
upload_secret "MB_DB_PASS" "$SECRET_PREFIX-mb-db-pass"
upload_secret "MINIO_ROOT_USER" "$SECRET_PREFIX-minio-root-user"
upload_secret "MINIO_ROOT_PASSWORD" "$SECRET_PREFIX-minio-root-password"
upload_secret "S3_ACCESS_KEY" "$SECRET_PREFIX-s3-access-key"
upload_secret "S3_SECRET_KEY" "$SECRET_PREFIX-s3-secret-key"
upload_secret "SESSION_JWT_SECRET" "$SECRET_PREFIX-session-jwt-secret"
upload_secret "PRISMA_FIELD_ENCRYPTION_KEY" "$SECRET_PREFIX-prisma-encryption-key"
upload_secret "SOF_API_TOKEN" "$SECRET_PREFIX-sof-api-token"
upload_secret "SEI_API_TOKEN" "$SECRET_PREFIX-sei-api-token"
upload_secret "AZURE_KEY" "$SECRET_PREFIX-azure-key"

echo ""
echo "✅ Secret upload complete!"
echo ""
echo "Verify with: gcloud secrets list --filter='name:smae-' --project=$PROJECT_ID"
