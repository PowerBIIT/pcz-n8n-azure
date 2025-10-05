#!/bin/bash
# Backup n8n workflows to Azure File Share
# Since Azure File Share mount doesn't work, we backup via API

set -e

N8N_URL="http://n8n-pcz.polandcentral.azurecontainer.io:5678"
N8N_USER="admin"
N8N_PASSWORD="Pcz2025Admin"
BACKUP_DIR="/tmp/n8n-backup-$(date +%Y%m%d-%H%M%S)"

echo "======================================"
echo "N8N BACKUP"
echo "======================================"

mkdir -p "$BACKUP_DIR"

# Login and get cookie
echo "Logging in to n8n..."
COOKIE=$(curl -s -c - -X POST "$N8N_URL/rest/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"admin@politechnika.edu.pl\",\"password\":\"$N8N_PASSWORD\"}" \
  | grep -i 'n8n-auth' | awk '{print $7}')

if [ -z "$COOKIE" ]; then
    echo "ERROR: Failed to login"
    exit 1
fi

echo "Logged in successfully"

# Export workflows
echo "Exporting workflows..."
curl -s -b "n8n-auth=$COOKIE" "$N8N_URL/rest/workflows" > "$BACKUP_DIR/workflows.json"

# Export credentials
echo "Exporting credentials..."
curl -s -b "n8n-auth=$COOKIE" "$N8N_URL/rest/credentials" > "$BACKUP_DIR/credentials.json"

# Count items
WORKFLOW_COUNT=$(cat "$BACKUP_DIR/workflows.json" | grep -o '"id"' | wc -l)
CRED_COUNT=$(cat "$BACKUP_DIR/credentials.json" | grep -o '"id"' | wc -l)

echo ""
echo "Backup complete!"
echo "  Workflows: $WORKFLOW_COUNT"
echo "  Credentials: $CRED_COUNT"
echo "  Location: $BACKUP_DIR"
echo ""

# Upload to Azure File Share
echo "Uploading to Azure File Share..."
STORAGE_ACCOUNT="n8nstorage18411"
FILE_SHARE="n8ndata"

# Create backup directory in file share
az storage directory create \
  --account-name $STORAGE_ACCOUNT \
  --share-name $FILE_SHARE \
  --name "backups" \
  --only-show-errors 2>/dev/null || true

# Upload files
az storage file upload \
  --account-name $STORAGE_ACCOUNT \
  --share-name $FILE_SHARE \
  --source "$BACKUP_DIR/workflows.json" \
  --path "backups/workflows-$(date +%Y%m%d-%H%M%S).json" \
  --only-show-errors

az storage file upload \
  --account-name $STORAGE_ACCOUNT \
  --share-name $FILE_SHARE \
  --source "$BACKUP_DIR/credentials.json" \
  --path "backups/credentials-$(date +%Y%m%d-%H%M%S).json" \
  --only-show-errors

echo "✓ Backup uploaded to Azure File Share"
echo ""
echo "======================================"
