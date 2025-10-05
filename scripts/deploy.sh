#!/bin/bash
# Deploy n8n to Azure Container Instances
# Politechnika Częstochowska - N8N Automation Platform

set -e

RESOURCE_GROUP="n8n-poland-rg"
LOCATION="polandcentral"
CONTAINER_NAME="n8n-pcz"
DNS_LABEL="n8n-pcz"

# Credentials (change in production!)
N8N_USER="admin"
N8N_PASSWORD="Pcz2025Admin"

echo "======================================"
echo "N8N DEPLOYMENT TO AZURE"
echo "======================================"

# Check if container already exists
if az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME &>/dev/null; then
    echo "⚠️  Container $CONTAINER_NAME already exists"
    read -p "Delete and redeploy? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing container..."
        az container delete --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --yes
        sleep 10
    else
        echo "Deployment cancelled"
        exit 0
    fi
fi

# Deploy container
echo "Deploying n8n container..."
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --location $LOCATION \
  --cpu 1 \
  --memory 1.5 \
  --os-type Linux \
  --ip-address Public \
  --ports 5678 \
  --dns-name-label $DNS_LABEL \
  --image n8nio/n8n:latest \
  --environment-variables \
    N8N_BASIC_AUTH_ACTIVE=true \
    N8N_BASIC_AUTH_USER=$N8N_USER \
    N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD \
    GENERIC_TIMEZONE=Europe/Warsaw \
    N8N_PORT=5678 \
    N8N_SECURE_COOKIE=false

# Wait for deployment
echo "Waiting for container to start..."
sleep 30

# Get connection info
FQDN=$(az container show \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --query 'ipAddress.fqdn' -o tsv)

IP=$(az container show \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --query 'ipAddress.ip' -o tsv)

echo ""
echo "======================================"
echo "✅ DEPLOYMENT SUCCESSFUL"
echo "======================================"
echo ""
echo "n8n URL: http://$FQDN:5678"
echo "IP Address: $IP"
echo ""
echo "Login credentials:"
echo "  Email: admin@politechnika.edu.pl"
echo "  Password: $N8N_PASSWORD"
echo ""
echo "Cost: ~$20/month"
echo ""
echo "⚠️  IMPORTANT: Run backup before restart!"
echo "   bash scripts/n8n-backup.sh"
echo ""
echo "======================================"
