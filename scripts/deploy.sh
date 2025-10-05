#!/bin/bash
# Deploy n8n to Azure Container Instances with PostgreSQL
# Politechnika Częstochowska - N8N Automation Platform

set -e

RESOURCE_GROUP="n8n-poland-rg"
LOCATION="polandcentral"
CONTAINER_NAME="n8n-pcz"
DNS_LABEL="n8n-pcz"

# n8n Credentials
N8N_USER="admin"
N8N_PASSWORD="Pcz2025Admin"

# PostgreSQL Credentials
PG_HOST="n8n-postgres-pcz.postgres.database.azure.com"
PG_USER="n8nadmin"
PG_DATABASE="flexibleserverdb"
PG_PORT="5432"

# Read PostgreSQL password from file
if [ -f ".postgres-password" ]; then
    PG_PASSWORD=$(cat .postgres-password | tr -d '\n' | tr -d ' ')
else
    echo "❌ Error: .postgres-password file not found"
    exit 1
fi

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

# Deploy container with PostgreSQL connection
echo "Deploying n8n container with PostgreSQL..."
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --location $LOCATION \
  --cpu 1 \
  --memory 2 \
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
    N8N_SECURE_COOKIE=false \
    DB_TYPE=postgresdb \
    DB_POSTGRESDB_HOST=$PG_HOST \
    DB_POSTGRESDB_PORT=$PG_PORT \
    DB_POSTGRESDB_DATABASE=$PG_DATABASE \
    DB_POSTGRESDB_USER=$PG_USER \
    DB_POSTGRESDB_PASSWORD=$PG_PASSWORD \
    DB_POSTGRESDB_SSL_ENABLED=true \
    DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false

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
echo "PostgreSQL Database:"
echo "  Host: $PG_HOST"
echo "  Database: $PG_DATABASE"
echo "  User: $PG_USER"
echo ""
echo "Cost: ~$35-40/month"
echo "  - n8n Container (1 vCPU, 2GB): ~$15"
echo "  - PostgreSQL Flexible Server: ~$20"
echo "  - Azure Blob Storage: ~$0.50"
echo ""
echo "Next steps:"
echo "  1. Configure credentials in n8n (see docs/SETUP-CREDENTIALS.md)"
echo "  2. Import invoice workflow (workflows/invoice-approval-workflow.json)"
echo "  3. Test workflow end-to-end"
echo ""
echo "======================================"
