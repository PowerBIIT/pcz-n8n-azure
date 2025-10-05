# N8N Deployment - Politechnika Częstochowska

Wdrożenie platformy automatyzacji n8n na Azure z PostgreSQL dla systemu akceptacji faktur - Politechnika Częstochowska.

## 🚀 Szybki start

### Wymagania
- Azure CLI zainstalowane i zalogowane
- Aktywna subskrypcja Azure
- Dostęp do bash shell
- psql client (dla testowania bazy danych)

### Wdrożenie

```bash
# Klonuj repozytorium
git clone https://github.com/PowerBIIT/pcz-n8n-azure.git
cd pcz-n8n-azure

# Wdróż infrastrukturę
cd scripts
bash deploy.sh
```

**Czas wdrożenia:** ~5 minut
**Koszt:** ~$35-40/miesiąc (n8n + PostgreSQL + Storage)

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
| PostgreSQL Flexible Server | `n8n-postgres-pcz` | Poland Central |
| Storage Account | `n8nstorage18411` | Poland Central |
| Blob Container | `invoices` | - |

## 💾 Persystencja danych

### ✅ PostgreSQL Flexible Server

n8n używa PostgreSQL jako backend database. **Dane przetrwają restart kontenera**.

- **Host:** n8n-postgres-pcz.postgres.database.azure.com
- **Database:** flexibleserverdb
- **Tabele:**
  - n8n system tables (workflows, credentials, executions)
  - `faktury` - tabela faktur z workflow

### Backup workflow (opcjonalny)

```bash
cd scripts
bash n8n-backup.sh
```

Backup nie jest już wymagany przed restartem, ale zalecany jako dodatkowe zabezpieczenie.

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

| Składnik | SKU | Koszt/miesiąc |
|----------|-----|---------------|
| Container Instance | 1 vCPU, 2GB RAM | ~$15 |
| PostgreSQL Flexible Server | Standard_B1ms | ~$20 |
| Storage Account | Blob Storage ~10GB | ~$0.50 |
| Bandwidth | Minimal | ~$1 |
| **TOTAL** | | **~$35-40** |

### Optymalizacja kosztów

- **Stop podczas nieużywania:** Container można zatrzymać (PostgreSQL nadal działa ale ~50% kosztów)
- **Auto-shutdown:** Azure Automation do wyłączania nocą/weekendy
- **PostgreSQL:** Burstable tier już jest najtańszy (B1ms)
- **Monitoring:** Alerty Azure Cost Management przy >$50/miesiąc

## 🏗️ Architektura

```
┌──────────────────────────────────────────────────────────┐
│  User                                                     │
│  1. Wypełnia formularz faktury                           │
│  2. Otrzymuje email z linkami akceptacji/odrzucenia      │
└──────────────────────────────────────────────────────────┘
                        │
                        ↓
┌──────────────────────────────────────────────────────────┐
│  Azure Container Instance - n8n                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  n8n:latest                                        │ │
│  │  - Port: 5678 (HTTP)                               │ │
│  │  - CPU: 1 vCPU, RAM: 2GB                          │ │
│  │  - Form Trigger: /form/faktura-pcz                │ │
│  │  - Webhook: /webhook/faktura-akceptacja           │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
           │                    │                 │
           │                    │                 │
           ↓                    ↓                 ↓
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ PostgreSQL       │  │ Azure Blob       │  │ Gmail SMTP       │
│ Flexible Server  │  │ Storage          │  │                  │
│                  │  │                  │  │                  │
│ - n8n tables     │  │ - Container:     │  │ - From:          │
│ - faktury table  │  │   invoices       │  │   radek@...      │
│   • id           │  │ - PDF files      │  │ - To:            │
│   • numer_fv     │  │                  │  │   właściciel     │
│   • kontrahent   │  │                  │  │                  │
│   • kwoty        │  │                  │  │                  │
│   • status       │  │                  │  │                  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## 📊 Workflow Faktur

Szczegółowy opis workflow znajduje się w: **[docs/INVOICE-WORKFLOW.md](docs/INVOICE-WORKFLOW.md)**

**Proces:**
1. User → Formularz → Dane faktury + PDF
2. n8n → Obliczenie VAT i brutto
3. n8n → Zapis do PostgreSQL (status: oczekuje)
4. n8n → Upload PDF do Azure Blob
5. n8n → Email do właściciela budżetu (linki akcept/odrzuć)
6. Właściciel → Klik link → Webhook
7. n8n → Update statusu w DB (zaakceptowana/odrzucona)
8. User → Potwierdzenie w przeglądarce

## 📚 Dokumentacja

### Struktura projektu

```
pcz-n8n-azure/
├── README.md                          # Ten plik
├── docs/
│   ├── DEPLOYMENT.md                  # Szczegółowa dokumentacja wdrożenia
│   ├── INVOICE-WORKFLOW.md            # Dokumentacja workflow faktur
│   └── SETUP-CREDENTIALS.md           # Konfiguracja credentials krok po kroku
├── scripts/
│   ├── deploy.sh                      # Wdrożenie n8n + PostgreSQL
│   ├── n8n-backup.sh                  # Backup workflows (opcjonalny)
│   └── create-invoice-table.sql       # Schemat tabeli faktur
├── workflows/
│   ├── invoice-approval-workflow.json # Workflow akceptacji faktur
│   └── test-workflow-basic.json       # Testowy workflow
├── .postgres-password                 # Hasło PostgreSQL (gitignored)
├── .n8n-api-key                       # n8n API key (gitignored)
└── backups/                           # Lokalne backupy (auto-generated)
```

### Dokumentacja

| Plik | Opis |
|------|------|
| [docs/INVOICE-WORKFLOW.md](docs/INVOICE-WORKFLOW.md) | Kompletna dokumentacja workflow faktur |
| [docs/SETUP-CREDENTIALS.md](docs/SETUP-CREDENTIALS.md) | Konfiguracja credentials w n8n |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Deployment i troubleshooting |

## 🔧 Konfiguracja po wdrożeniu

### 1. Setup credentials w n8n

Szczegółowe instrukcje: **[docs/SETUP-CREDENTIALS.md](docs/SETUP-CREDENTIALS.md)**

Potrzebne credentials:
- **PostgreSQL PCZ** - połączenie z bazą danych
- **Azure Storage PCZ** - przechowywanie PDF
- **Gmail PCZ** - wysyłanie powiadomień email

### 2. Import workflow

```bash
# Przez UI (zalecane dla pierwszego razu):
# 1. Zaloguj się: http://n8n-pcz.polandcentral.azurecontainer.io:5678
# 2. Workflows → Import from File
# 3. Wybierz: workflows/invoice-approval-workflow.json

# LUB przez API:
# 1. Wygeneruj API key w n8n (Settings → API)
# 2. Zapisz do .n8n-api-key
# 3. Uruchom:
bash scripts/create-workflow.sh workflows/invoice-approval-workflow.json
```

### 3. Test workflow

1. Otwórz formularz: http://n8n-pcz.polandcentral.azurecontainer.io:5678/form/faktura-pcz
2. Wypełnij wszystkie pola testowymi danymi
3. Załącz testowy PDF
4. Sprawdź email
5. Kliknij link akceptacji/odrzucenia
6. Zweryfikuj w bazie:
```sql
PGPASSWORD='...' psql -h n8n-postgres-pcz.postgres.database.azure.com \
  -U n8nadmin -d flexibleserverdb \
  -c "SELECT * FROM faktury ORDER BY created_at DESC LIMIT 5;"
```

## ❓ FAQ

### Dlaczego PostgreSQL zamiast SQLite?

**SQLite** - dane w kontenerze, restart = utrata danych
**PostgreSQL Flexible Server** - persystencja danych, profesjonalne rozwiązanie

Koszt +$20/mies, ale bezpieczeństwo danych bezcenne.

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
