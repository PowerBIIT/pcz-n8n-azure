# Konfiguracja Credentials w n8n - Krok po kroku

## 1. Zaloguj się do n8n

1. Otwórz przeglądarkę: http://n8n-pcz.polandcentral.azurecontainer.io:5678
2. Zaloguj się:
   - Email: `admin@politechnika.edu.pl`
   - Password: `Pcz2025Admin`

## 2. PostgreSQL Credential

### Opcja A: Przez UI (zalecane dla pierwszej konfiguracji)

1. Kliknij ikonę "Settings" (koło zębate) w lewym menu
2. Wybierz "Credentials"
3. Kliknij "+ Add Credential"
4. Wyszukaj i wybierz "Postgres"
5. Wypełnij formularz:
   ```
   Name: PostgreSQL PCZ
   Host: n8n-postgres-pcz.postgres.database.azure.com
   Database: flexibleserverdb
   User: n8nadmin
   Password: w4K/hsVsjt7ru+k+okVXnjTa/OPdlbMO
   Port: 5432
   SSL: Enable (zaznacz checkbox)
   ```
6. Kliknij "Test" aby sprawdzić połączenie
7. Kliknij "Save"

### Opcja B: Przez API

```bash
# Pobierz API key z n8n (Settings → API)
# Następnie użyj:

curl -X POST http://n8n-pcz.polandcentral.azurecontainer.io:5678/api/v1/credentials \
  -H "X-N8N-API-KEY: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "PostgreSQL PCZ",
    "type": "postgres",
    "data": {
      "host": "n8n-postgres-pcz.postgres.database.azure.com",
      "database": "flexibleserverdb",
      "user": "n8nadmin",
      "password": "w4K/hsVsjt7ru+k+okVXnjTa/OPdlbMO",
      "port": 5432,
      "ssl": true
    }
  }'
```

## 3. Azure Blob Storage Credential

### Krok 1: Pobierz Access Key z Azure Portal

1. Otwórz Azure Portal: https://portal.azure.com
2. Znajdź Storage Account: `n8nstorage18411`
3. W menu po lewej wybierz "Access keys"
4. Skopiuj "key1" (kliknij "Show" i skopiuj wartość)

### Krok 2: Skonfiguruj w n8n

1. W n8n: Settings → Credentials → "+ Add Credential"
2. Wyszukaj "Microsoft Azure"
3. Wypełnij:
   ```
   Name: Azure Storage PCZ
   Account Name: n8nstorage18411
   Access Key: [klucz skopiowany z Azure Portal]
   ```
4. Kliknij "Save"

## 4. Gmail Credential

### Opcja A: Gmail App Password (prostsze)

#### Krok 1: Sprawdź czy App Password działa

```bash
# Test z hasłem aplikacji:
mkqf mjwo ylvn yvvm
```

#### Krok 2: Konfiguracja w n8n

1. W n8n: Settings → Credentials → "+ Add Credential"
2. Wyszukaj "Gmail"
3. Wybierz "Gmail OAuth2" LUB "SMTP" (SMTP jest prostsze)

**Dla SMTP:**
```
Name: Gmail PCZ
User: radekbroniszewski@gmail.com
Password: mkqfmjwoylvnyvvm (bez spacji!)
Host: smtp.gmail.com
Port: 587
Security: STARTTLS
```

**Dla OAuth2:**
- Będzie wymagane utworzenie Google Cloud Project
- OAuth2 Client ID i Secret
- (Instrukcje poniżej jeśli potrzebne)

### Opcja B: Gmail OAuth2 (bardziej bezpieczne, ale bardziej skomplikowane)

#### Krok 1: Google Cloud Console

1. Otwórz: https://console.cloud.google.com
2. Utwórz nowy projekt lub wybierz istniejący
3. Włącz Gmail API:
   - API & Services → Library
   - Wyszukaj "Gmail API"
   - Kliknij "Enable"

4. Utwórz OAuth2 credentials:
   - API & Services → Credentials
   - "+ Create Credentials" → "OAuth client ID"
   - Application type: "Web application"
   - Name: "n8n PCZ"
   - Authorized redirect URIs:
     ```
     http://n8n-pcz.polandcentral.azurecontainer.io:5678/rest/oauth2-credential/callback
     ```
   - Kliknij "Create"
   - Skopiuj "Client ID" i "Client Secret"

5. Skonfiguruj OAuth consent screen:
   - User Type: External
   - Dodaj swój email: radekbroniszewski@gmail.com
   - Scopes: Gmail Send

#### Krok 2: Konfiguracja w n8n

1. W n8n: Settings → Credentials → "+ Add Credential"
2. Wybierz "Gmail OAuth2"
3. Wypełnij:
   ```
   Name: Gmail PCZ OAuth
   Client ID: [z Google Cloud Console]
   Client Secret: [z Google Cloud Console]
   ```
4. Kliknij "Sign in with Google"
5. Zaloguj się jako radekbroniszewski@gmail.com
6. Zaakceptuj uprawnienia
7. Kliknij "Save"

## 5. Weryfikacja Credentials

### Test PostgreSQL:
```sql
-- Połącz się przez psql:
PGPASSWORD='w4K/hsVsjt7ru+k+okVXnjTa/OPdlbMO' psql \
  -h n8n-postgres-pcz.postgres.database.azure.com \
  -U n8nadmin \
  -d flexibleserverdb

-- Sprawdź tabele:
\dt

-- Sprawdź tabelę faktur:
SELECT * FROM faktury LIMIT 5;
```

### Test Azure Blob:
```bash
# Przez Azure CLI:
az storage blob list \
  --account-name n8nstorage18411 \
  --container-name invoices \
  --output table
```

### Test Gmail:
- Najlepszy test to wysłanie testowego emaila przez n8n workflow
- Alternatywnie użyj n8n "Execute Node" w edytorze workflow

## 6. Troubleshooting

### Problem: PostgreSQL - "SSL required"
**Rozwiązanie**: Upewnij się że zaznaczyłeś "SSL: Enable" w konfiguracji

### Problem: PostgreSQL - "no pg_hba.conf entry"
**Rozwiązanie**: Sprawdź czy firewall PostgreSQL dopuszcza połączenia:
```bash
az postgres flexible-server firewall-rule list \
  --resource-group n8n-poland-rg \
  --name n8n-postgres-pcz
```

### Problem: Gmail - "Invalid credentials"
**Rozwiązanie**:
1. Sprawdź czy App Password jest poprawne (bez spacji)
2. Sprawdź czy 2FA jest włączone na koncie Gmail
3. Wygeneruj nowe App Password jeśli potrzeba:
   - https://myaccount.google.com/apppasswords

### Problem: Azure Blob - "Authentication failed"
**Rozwiązanie**:
1. Sprawdź czy Access Key jest poprawny
2. Upewnij się że Storage Account name to dokładnie: `n8nstorage18411`
3. Sprawdź czy kontener `invoices` istnieje

## 7. Bezpieczeństwo

⚠️ **WAŻNE**:
- NIE commituj credentials do git
- NIE udostępniaj Access Keys publicznie
- Regularnie rotuj hasła i klucze
- Używaj OAuth2 zamiast App Passwords gdy to możliwe
- Ogranicz uprawnienia do minimum (Principle of Least Privilege)

## 8. Backup Credentials

Zapisz credentials w bezpiecznym miejscu (np. Azure Key Vault lub password manager):

```bash
# Przykład eksportu credentials z n8n (wymaga API key):
curl -X GET \
  http://n8n-pcz.polandcentral.azurecontainer.io:5678/api/v1/credentials \
  -H "X-N8N-API-KEY: YOUR_API_KEY" \
  > credentials-backup.json

# Szyfruj backup:
gpg -c credentials-backup.json

# Usuń plain text:
rm credentials-backup.json
```

## 9. Następne kroki

Po skonfigurowaniu wszystkich credentials:

1. Zaimportuj workflow: `workflows/invoice-approval-workflow.json`
2. W każdym node workflow wybierz odpowiednie credential
3. Test workflow end-to-end
4. Aktywuj workflow (toggle "Active")

## Kontakt

W razie problemów sprawdź:
- [docs/INVOICE-WORKFLOW.md](./INVOICE-WORKFLOW.md) - dokumentacja workflow
- [docs/DEPLOYMENT.md](./DEPLOYMENT.md) - dokumentacja deployment
- n8n logs: `az container logs --resource-group n8n-poland-rg --name n8n-pcz`
