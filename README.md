# N8N Deployment - Politechnika Częstochowska

Wdrożenie platformy automatyzacji n8n na Azure Container Instances dla Politechniki Częstochowskiej.

## 🚀 Szybki start

### Wymagania
- Azure CLI zainstalowane i zalogowane
- Aktywna subskrypcja Azure
- Dostęp do bash shell

### Wdrożenie

```bash
cd scripts
bash deploy.sh
```

**Czas wdrożenia:** ~2 minuty
**Koszt:** ~$20/miesiąc (1 vCPU, 1.5GB RAM)

## 📋 Informacje o wdrożeniu

### Dostęp do n8n

- **URL:** http://n8n-pcz.polandcentral.azurecontainer.io:5678
- **Email:** admin@politechnika.edu.pl
- **Hasło:** Pcz2025Admin

### Zasoby Azure

| Zasób | Nazwa | Lokalizacja |
|-------|-------|-------------|
| Resource Group | `n8n-poland-rg` | Poland Central |
| Container Instance | `n8n-pcz` | Poland Central |
| Storage Account | `n8nstorage18411` | Poland Central |
| File Share | `n8ndata` | - |

## 💾 Backup i persystencja danych

### ⚠️ WAŻNE: Brak automatycznej persystencji

n8n działa z SQLite w pamięci kontenera. **Restart kontenera = utrata danych**.

### Backup workflow (przed restartem)

```bash
cd scripts
bash n8n-backup.sh
```

Skrypt:
- Eksportuje wszystkie workflows i credentials przez API
- Zapisuje do Azure File Share (`n8ndata/backups/`)
- Lokalny backup w `/tmp/n8n-backup-YYYYMMDD-HHMMSS/`

### Restore workflow (po restarcie)

1. Deploy nowego kontenera (lub restart istniejącego)
2. W n8n UI: **Settings → Import from File**
3. Wybierz plik: `/tmp/n8n-backup-YYYYMMDD-HHMMSS/workflows.json`

## 🛠️ Zarządzanie

### Zatrzymaj container (oszczędzanie kosztów)

```bash
az container stop --name n8n-pcz --resource-group n8n-poland-rg
```

**Gdy zatrzymany:** $0/dzień (płacisz tylko za storage ~$0.07/dzień)

### Uruchom ponownie

```bash
az container start --name n8n-pcz --resource-group n8n-poland-rg
```

**Czas startu:** ~30 sekund

### Sprawdź logi

```bash
az container logs --resource-group n8n-poland-rg --name n8n-pcz
```

### Sprawdź status

```bash
az container show --resource-group n8n-poland-rg --name n8n-pcz --query 'instanceView.state' -o tsv
```

## 💰 Koszty

| Składnik | Koszt/miesiąc |
|----------|---------------|
| Container Instance (1 vCPU, 1.5GB) | ~$15 |
| Storage Account (10GB File Share) | ~$2 |
| Bandwidth | ~$3 |
| **TOTAL** | **~$20** |

### Optymalizacja kosztów

- **Stop podczas nieużywania:** Container można zatrzymać → $0/dzień
- **Auto-shutdown:** Rozważ Azure Automation do automatycznego wyłączania nocą/weekendy
- **Monitoring:** Ustawić alerty Azure Cost Management przy >$25/miesiąc

## 🏗️ Architektura

```
┌─────────────────────────────────────┐
│  Azure Container Instance           │
│  ┌──────────────────────────────┐  │
│  │  n8n:latest                  │  │
│  │  - Port: 5678                │  │
│  │  - CPU: 1 vCPU               │  │
│  │  - RAM: 1.5GB                │  │
│  │  - DB: SQLite (in-container) │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
           │
           │ (manual backup via API)
           ↓
┌─────────────────────────────────────┐
│  Azure File Share                   │
│  - n8ndata/backups/                 │
│  - workflows-YYYYMMDD.json          │
│  - credentials-YYYYMMDD.json        │
└─────────────────────────────────────┘
```

## 📚 Dokumentacja

### Struktura projektu

```
pcz-n8n-azure/
├── README.md                    # Ten plik
├── docs/
│   └── credentials.md          # Dane dostępowe (NIE commituj!)
├── scripts/
│   ├── deploy.sh               # Wdrożenie n8n
│   └── n8n-backup.sh           # Backup workflows
└── backups/                    # Lokalne backupy (auto-generated)
```

### Pliki konfiguracyjne

- **scripts/deploy.sh** - Główny skrypt wdrożeniowy
- **scripts/n8n-backup.sh** - Automatyczny backup przez API
- **docs/credentials.md** - Wszystkie dane dostępowe i komendy

## ❓ FAQ

### Dlaczego nie Azure File Share do persystencji?

Azure Container Instances ma problemy z montowaniem File Share w niektórych konfiguracjach. Próby montowania kończyły się błędem "Failed to mount Azure File Volume".

**Alternatywy:**
- **VM z Dockerem** (~$68/mies) - pełna kontrola, File Share działa
- **Azure App Service** (~$55/mies) - managed, persystencja wbudowana
- **Obecne rozwiązanie** (~$20/mies) - manual backup, 5x taniej

### Jak migrować na inną subskrypcję (np. uczelnianą)?

1. Zrób backup: `bash scripts/n8n-backup.sh`
2. Zaloguj się do nowej subskrypcji: `az login`
3. Ustaw subskrypcję: `az account set --subscription <ID>`
4. Deploy: `bash scripts/deploy.sh`
5. Restore z backupu w UI

### Czy dane są bezpieczne?

- ✅ Basic Auth włączony (user/password)
- ✅ HTTPS można dodać przez Azure Front Door lub nginx
- ⚠️ Obecnie HTTP (dla development OK, dla production dodaj SSL)
- ✅ Credentials w n8n szyfrowane encryption key

### Jak dodać HTTPS?

**Opcja 1: Azure Front Door**
```bash
# Utwórz Front Door
az afd profile create --name n8n-fd --resource-group n8n-poland-rg
# Dodaj endpoint i custom domain
```

**Opcja 2: Nginx Reverse Proxy**
- Deploy osobny container z nginx
- Dodaj Let's Encrypt dla SSL
- Proxy do n8n container

## 🔧 Troubleshooting

### Container nie startuje

```bash
# Sprawdź logi
az container logs --resource-group n8n-poland-rg --name n8n-pcz

# Sprawdź eventy
az container show --resource-group n8n-poland-rg --name n8n-pcz --query 'instanceView.events'
```

### Nie mogę się zalogować

Sprawdź credentials w `docs/credentials.md` lub:

```bash
az container show --resource-group n8n-poland-rg --name n8n-pcz \
  --query 'containers[0].environmentVariables' -o table
```

### Backup nie działa

1. Sprawdź czy n8n jest dostępny: `curl http://n8n-pcz.polandcentral.azurecontainer.io:5678`
2. Sprawdź credentials w skrypcie
3. Sprawdź Azure CLI login: `az account show`

## 📞 Wsparcie

- **Dokumentacja n8n:** https://docs.n8n.io/
- **Azure Container Instances:** https://learn.microsoft.com/azure/container-instances/
- **Issues:** GitHub Issues w tym repo

## 📝 Licencja

Projekt wdrożeniowy dla Politechniki Częstochowskiej.

---

**Data utworzenia:** 2025-10-05
**Wersja n8n:** 1.113.3
**Autor:** Deployment automation
