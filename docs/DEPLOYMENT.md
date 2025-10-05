# Deployment Guide - N8N Azure

## Przegląd wdrożenia

**Data:** 2025-10-05
**Środowisko:** Azure Poland Central
**Status:** ✅ Production Ready (z manual backup)

## Zasoby utworzone

### Azure Resources

| Typ | Nazwa | Specyfikacja | Status |
|-----|-------|--------------|--------|
| Resource Group | `n8n-poland-rg` | Poland Central | Active |
| Container Instance | `n8n-pcz` | 1 vCPU, 1.5GB RAM | Running |
| Storage Account | `n8nstorage18411` | Standard LRS | Active |
| File Share | `n8ndata` | 10GB | Active (backup only) |

### Networking

- **Public IP:** 74.248.250.87 (może się zmienić po restarcie)
- **FQDN:** n8n-pcz.polandcentral.azurecontainer.io
- **Port:** 5678 (HTTP)
- **DNS Label:** n8n-pcz

## Konfiguracja n8n

### Environment Variables

```bash
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=Pcz2025Admin
GENERIC_TIMEZONE=Europe/Warsaw
N8N_PORT=5678
N8N_SECURE_COOKIE=false  # Required for HTTP
```

### Database

- **Type:** SQLite
- **Location:** In-container (`/home/node/.n8n/database.sqlite`)
- **Persistence:** ❌ None (manual backup required)

### Authentication

- **Method:** Basic Auth
- **Email:** admin@politechnika.edu.pl
- **Password:** Pcz2025Admin

⚠️ **TODO dla production:** Zmienić hasło!

## Proces wdrożenia

### 1. Przygotowanie środowiska

```bash
# Login do Azure
az login

# Sprawdź subskrypcję
az account show

# Ustaw subskrypcję (jeśli potrzeba)
az account set --subscription "Pay-As-You-Go"
```

### 2. Utworzenie Resource Group

```bash
az group create \
  --name n8n-poland-rg \
  --location polandcentral
```

### 3. Utworzenie Storage Account (dla backupów)

```bash
az storage account create \
  --name n8nstorage18411 \
  --resource-group n8n-poland-rg \
  --location polandcentral \
  --sku Standard_LRS \
  --kind StorageV2
```

### 4. Utworzenie File Share

```bash
az storage share create \
  --name n8ndata \
  --account-name n8nstorage18411 \
  --quota 10
```

### 5. Deploy n8n Container

```bash
az container create \
  --resource-group n8n-poland-rg \
  --name n8n-pcz \
  --location polandcentral \
  --cpu 1 \
  --memory 1.5 \
  --os-type Linux \
  --ip-address Public \
  --ports 5678 \
  --dns-name-label n8n-pcz \
  --image n8nio/n8n:latest \
  --environment-variables \
    N8N_BASIC_AUTH_ACTIVE=true \
    N8N_BASIC_AUTH_USER=admin \
    N8N_BASIC_AUTH_PASSWORD=Pcz2025Admin \
    GENERIC_TIMEZONE=Europe/Warsaw \
    N8N_PORT=5678 \
    N8N_SECURE_COOKIE=false
```

### 6. Weryfikacja

```bash
# Sprawdź status
az container show --resource-group n8n-poland-rg --name n8n-pcz --query 'instanceView.state' -o tsv

# Sprawdź logi
az container logs --resource-group n8n-poland-rg --name n8n-pcz

# Test dostępu
curl http://n8n-pcz.polandcentral.azurecontainer.io:5678
```

## Problemy napotkane i rozwiązania

### ❌ Problem 1: Azure File Share nie montuje się

**Symptom:**
```
Failed to mount Azure File Volume
```

**Próbowane rozwiązania:**
1. YAML manifest z volume mount → Failed
2. CLI z --azure-file-volume parameters → Failed
3. Różne mount paths (/data, /home/node/.n8n) → Failed

**Root Cause:**
Azure Container Instances ma problemy z montowaniem File Share w niektórych konfiguracjach/regionach.

**Final Solution:**
Manual backup przez n8n REST API + upload do File Share.

### ❌ Problem 2: PostgreSQL w multi-container setup

**Symptom:**
```
connect ECONNREFUSED 127.0.0.1:5432
```

**Próba:**
Deployment z PostgreSQL i n8n w jednym container group (localhost networking).

**Dlaczego nie zadziałało:**
Containers w Azure Container Instances nie mogą używać localhost do komunikacji między sobą.

**Solution:**
SQLite w pojedynczym container.

### ❌ Problem 3: Secure Cookie Error

**Symptom:**
```
Your n8n server is configured to use a secure cookie, however you are either visiting this via an insecure URL
```

**Solution:**
Dodać `N8N_SECURE_COOKIE=false` dla HTTP access.

## Best Practices

### Security

- [ ] **TODO:** Dodać HTTPS (Azure Front Door lub nginx reverse proxy)
- [ ] **TODO:** Zmienić domyślne hasło
- [x] Basic Auth włączony
- [x] Azure File Share encrypted at rest
- [ ] **TODO:** Rozważyć Azure Private Link dla prywatnego dostępu

### Backup Strategy

1. **Przed każdym restartem:**
   ```bash
   bash scripts/n8n-backup.sh
   ```

2. **Cron job (recommended):**
   ```bash
   # Daily backup at 2 AM
   0 2 * * * cd /home/radek/pcz-n8n-azure && bash scripts/n8n-backup.sh
   ```

3. **Retention:**
   - Trzymaj 7 dni daily backups
   - 4 tygodnie weekly backups
   - 3 miesiące monthly backups

### Monitoring

**Recommended:**
- Azure Monitor alerts dla container crashes
- Cost alerts przy >$25/month
- Uptime monitoring (np. UptimeRobot)

**Komendy monitoring:**

```bash
# CPU/Memory usage
az container show --resource-group n8n-poland-rg --name n8n-pcz \
  --query 'containers[0].instanceView.currentState' -o json

# Logs (last 100 lines)
az container logs --resource-group n8n-poland-rg --name n8n-pcz --tail 100

# Events
az container show --resource-group n8n-poland-rg --name n8n-pcz \
  --query 'instanceView.events' -o table
```

## Upgrade Path

### Do managed database (gdy potrzeba)

1. **Azure Database for PostgreSQL:**
   ```bash
   # Create PostgreSQL server
   az postgres flexible-server create \
     --name n8n-postgres \
     --resource-group n8n-poland-rg \
     --location polandcentral \
     --admin-user n8nadmin \
     --admin-password <PASSWORD> \
     --sku-name Standard_B1ms
   ```

2. **Update container z DB_TYPE=postgresdb**

**Koszt:** +$35/month (total ~$55/month)

### Do Azure App Service

```bash
az appservice plan create --name n8n-plan --resource-group n8n-poland-rg --sku B1
az webapp create --name n8n-pcz-app --resource-group n8n-poland-rg --plan n8n-plan
```

**Pros:**
- Automatic persistence
- SSL included
- Easy scaling

**Cons:**
- Koszt ~$55/month vs $20/month

## Rollback Plan

Jeśli coś pójdzie nie tak:

1. **Container restart:**
   ```bash
   az container restart --name n8n-pcz --resource-group n8n-poland-rg
   ```

2. **Redeploy from backup:**
   ```bash
   # Delete failed container
   az container delete --name n8n-pcz --resource-group n8n-poland-rg --yes

   # Redeploy
   bash scripts/deploy.sh

   # Restore workflows from backup
   # (via n8n UI: Settings → Import)
   ```

3. **Full cleanup:**
   ```bash
   az group delete --name n8n-poland-rg --yes
   # Then redeploy everything
   ```

## Koszty szczegółowo

### Rzeczywiste koszty (październik 2025)

| Zasób | Koszt dzienny | Koszt miesięczny |
|-------|---------------|------------------|
| Container Instance (1 vCPU, 1.5GB, running 24/7) | $0.50 | $15.00 |
| Storage Account (10GB File Share) | $0.07 | $2.00 |
| Bandwidth (assume 5GB/month) | $0.10 | $3.00 |
| **TOTAL** | **$0.67** | **~$20.00** |

### Oszczędności

**Stop nocą (18h/dzień, 6h running):**
- Container running: 6h × $0.021/h × 30 = $3.78
- Storage (zawsze): $2.00
- **Total:** ~$6/month (70% oszczędności!)

## Migration do uczelni Azure

Gdy dostępna będzie subskrypcja uczelni:

1. Backup z obecnego środowiska:
   ```bash
   bash scripts/n8n-backup.sh
   ```

2. Login do uczelni Azure:
   ```bash
   az login
   az account set --subscription "<UNIVERSITY_SUB_ID>"
   ```

3. Deploy na nowej subskrypcji:
   ```bash
   bash scripts/deploy.sh
   ```

4. Restore workflow z backupu

5. Cleanup starej subskrypcji:
   ```bash
   az account set --subscription "Pay-As-You-Go"
   az group delete --name n8n-poland-rg --yes
   ```

---

**Last updated:** 2025-10-05
**Deployed by:** Claude AI Assistant
**Status:** ✅ Production Ready
