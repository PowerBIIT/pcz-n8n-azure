-- Tabela faktur dla systemu n8n
CREATE TABLE IF NOT EXISTS faktury (
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

-- Indeksy
CREATE INDEX idx_faktury_status ON faktury(status);
CREATE INDEX idx_faktury_data_wystawienia ON faktury(data_wystawienia);
CREATE INDEX idx_faktury_email ON faktury(email_wlasciciela);

-- Komentarze
COMMENT ON TABLE faktury IS 'Faktury w systemie akceptacji Politechniki Częstochowskiej';
COMMENT ON COLUMN faktury.status IS 'Status: oczekuje, zaakceptowana, odrzucona';
