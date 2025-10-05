#!/bin/bash
# Upload workflow to n8n via API

set -e

WORKFLOW_FILE="${1:-workflows/test-workflow-basic.json}"
API_KEY=$(cat .n8n-api-key 2>/dev/null || echo "")

if [ -z "$API_KEY" ]; then
    echo "ERROR: API key not found in .n8n-api-key"
    exit 1
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "ERROR: Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "Uploading workflow: $WORKFLOW_FILE"

RESPONSE=$(curl -s -X POST \
  http://n8n-pcz.polandcentral.azurecontainer.io:5678/api/v1/workflows \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: $API_KEY" \
  -d @"$WORKFLOW_FILE")

echo "$RESPONSE" | grep -q '"id"' && echo "✅ Workflow created successfully!" || echo "❌ Error: $RESPONSE"
echo "$RESPONSE"
