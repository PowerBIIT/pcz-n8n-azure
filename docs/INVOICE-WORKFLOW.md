# Workflow Faktur - Dokumentacja

## Przegląd

System akceptacji faktur dla Politechniki Częstochowskiej zbudowany w n8n.

## Architektura

### Komponenty:
1. **n8n** - silnik workflow (Azure Container Instance)
2. **PostgreSQL** - baza danych faktur (Azure PostgreSQL Flexible Server)
3. **Azure Blob Storage** - przechowywanie PDF faktur
4. **Gmail** - powiadomienia email

## Proces workflow

### 1. Zgłoszenie faktury (Form Trigger)
- Użytkownik wypełnia formularz: http://n8n-pcz.polandcentral.azurecontainer.io:5678/form/faktura-pcz
- Pola formularza:
  - Numer faktury (wymagane)
  - Nazwa kontrahenta (wymagane)
  - Data wystawienia (wymagane)
  - Kwota netto PLN (wymagane)
  - VAT % (wymagane)
  - Opis (opcjonalne)
  - Email właściciela budżetu (wymagane)
  - PDF faktury (wymagane, tylko .pdf)

### 2. Obliczenia (Function Node)
- Automatyczne obliczenie:
  - Kwota VAT = Netto × (VAT% / 100)
  - Kwota brutto = Netto + Kwota VAT
  - Data zgłoszenia = timestamp

### 3. Zapis w PostgreSQL
- Tabela: `faktury`
- Status początkowy: `oczekuje`
- Zwraca ID faktury

### 4. Upload PDF do Azure Blob
- Kontener: `invoices`
- Nazwa pliku: `{numer-faktury}.pdf`
- Storage Account: `n8nstorage18411`

### 5. Email do właściciela budżetu
- From: radekbroniszewski@gmail.com
- To: email właściciela z formularza
- Zawiera:
  - Szczegóły faktury
  - Link do akceptacji
  - Link do odrzucenia

### 6. Webhook akceptacji/odrzucenia
- URL: http://n8n-pcz.polandcentral.azurecontainer.io:5678/webhook/faktura-akceptacja
- Parametry:
  - `action=accept` lub `action=reject`
  - `id={id_faktury}`

### 7. Aktualizacja statusu
- **Akceptacja**:
  - Status → `zaakceptowana`
  - `data_akceptacji` → timestamp
- **Odrzucenie**:
  - Status → `odrzucona`
  - `data_odrzucenia` → timestamp

### 8. Odpowiedź użytkownikowi
- Potwierdzenie w przeglądarce

## Schemat bazy danych

```sql
CREATE TABLE faktury (
    id SERIAL PRIMARY KEY,
    numer_faktury VARCHAR(100) NOT NULL UNIQUE,
    nazwa_kontrahenta VARCHAR(255) NOT NULL,
    data_wystawienia DATE NOT NULL,
    kwota_netto DECIMAL(10, 2) NOT NULL,
    vat_procent DECIMAL(5, 2) NOT NULL,
    kwota_vat DECIMAL(10, 2) NOT NULL,
    kwota_brutto DECIMAL(10, 2) NOT NULL,
    opis TEXT,
    email_wlasciciela VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'oczekuje',
    data_zgloszenia TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_akceptacji TIMESTAMP,
    data_odrzucenia TIMESTAMP,
    blob_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Konfiguracja credentials w n8n

### 1. PostgreSQL PCZ
- **Type**: PostgreSQL
- **Host**: n8n-postgres-pcz.postgres.database.azure.com
- **Database**: flexibleserverdb
- **User**: n8nadmin
- **Password**: (z pliku `.postgres-password`)
- **SSL**: Enabled
- **Port**: 5432

### 2. Azure Storage PCZ
- **Type**: Microsoft Azure
- **Account Name**: n8nstorage18411
- **Account Key**: (klucz dostępu z Azure Portal)

### 3. Gmail PCZ
- **Type**: Gmail OAuth2
- **Email**: radekbroniszewski@gmail.com
- **App Password**: mkqf mjwo ylvn yvvm
- **Alternatywnie**: OAuth2 z Google Console

## Deployment workflow

```bash
# 1. Zaloguj się do n8n
# http://n8n-pcz.polandcentral.azurecontainer.io:5678
# admin@politechnika.edu.pl / Pcz2025Admin

# 2. Skonfiguruj credentials (Settings → Credentials)

# 3. Zaimportuj workflow przez API:
bash scripts/create-workflow.sh workflows/invoice-approval-workflow.json

# LUB zaimportuj przez UI:
# - Otwórz Workflows
# - Import from File
# - Wybierz workflows/invoice-approval-workflow.json
```

## Testowanie

### Test 1: Zgłoszenie faktury
1. Otwórz: http://n8n-pcz.polandcentral.azurecontainer.io:5678/form/faktura-pcz
2. Wypełnij wszystkie pola
3. Załącz testowy PDF
4. Wyślij formularz
5. Sprawdź email właściciela budżetu

### Test 2: Akceptacja
1. Kliknij link "Akceptuj" w emailu
2. Sprawdź odpowiedź w przeglądarce
3. Zweryfikuj w bazie:
```sql
SELECT * FROM faktury WHERE status = 'zaakceptowana';
```

### Test 3: Odrzucenie
1. Kliknij link "Odrzuć" w emailu
2. Sprawdź odpowiedź w przeglądarce
3. Zweryfikuj w bazie:
```sql
SELECT * FROM faktury WHERE status = 'odrzucona';
```

## Rozszerzenia (przyszłość)

1. **Multi-level approval**: Dodanie drugiego/trzeciego poziomu akceptacji
2. **Notifications**: Powiadomienia SMS lub Teams
3. **Dashboard**: Interfejs do przeglądania faktur
4. **OCR**: Automatyczne wyciąganie danych z PDF
5. **Integration**: Integracja z systemem księgowym
6. **Reporting**: Raporty i statystyki

## Troubleshooting

### Problem: Email nie przychodzi
- Sprawdź konfigurację Gmail credentials
- Zweryfikuj App Password
- Sprawdź logi n8n: `az container logs --resource-group n8n-poland-rg --name n8n-pcz`

### Problem: PDF nie zapisuje się
- Sprawdź Azure Storage Account credentials
- Zweryfikuj czy kontener `invoices` istnieje
- Sprawdź uprawnienia storage account

### Problem: Dane nie zapisują się w PostgreSQL
- Sprawdź połączenie z bazą
- Zweryfikuj czy tabela `faktury` istnieje
- Sprawdź PostgreSQL logs w Azure Portal

## Bezpieczeństwo

- ✅ PostgreSQL - SSL wymuszony
- ✅ Azure Blob - private access
- ✅ n8n - Basic Auth
- ✅ Credentials - gitignored
- ⚠️ TODO: HTTPS dla n8n (obecnie HTTP)
- ⚠️ TODO: Azure AD authentication

## Koszty (miesięczne)

- n8n Container (1 vCPU, 2GB): ~$15
- PostgreSQL Flexible Server (B1ms): ~$20
- Azure Blob Storage (~10GB): ~$0.50
- **Łącznie: ~$35-40/miesiąc**
