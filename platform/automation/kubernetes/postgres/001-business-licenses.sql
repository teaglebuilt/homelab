CREATE SCHEMA IF NOT EXISTS leads;
GRANT USAGE, CREATE ON SCHEMA leads TO scrapers;
    ALTER DEFAULT PRIVILEGES IN SCHEMA leads
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO scrapers;

CREATE TABLE IF NOT EXISTS leads.business_licenses (
  id                BIGSERIAL PRIMARY KEY,
  city              TEXT NOT NULL,
  case_id           TEXT NOT NULL,
  license_number    TEXT NOT NULL,
  license_type      TEXT,
  license_status    TEXT,
  company_name      TEXT,
  dba               TEXT,
  business_type     TEXT,
  business_status   TEXT,
  address_full      TEXT,
  address_city      TEXT,
  address_state     TEXT,
  address_zip       TEXT,
  apply_date        TIMESTAMPTZ,
  issue_date        TIMESTAMPTZ,
  expire_date       TIMESTAMPTZ,
  opened_date       TIMESTAMPTZ,
  closed_date       TIMESTAMPTZ,
  tax_id            TEXT,
  raw_payload       JSONB,
  scraped_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (city, case_id)
);
CREATE INDEX IF NOT EXISTS idx_bl_apply_date ON leads.business_licenses (apply_date DESC);
CREATE INDEX IF NOT EXISTS idx_bl_city_status ON leads.business_licenses (address_city, license_status);
CREATE INDEX IF NOT EXISTS idx_bl_business_type ON leads.business_licenses (business_type);

-- County deed recordings (Charleston / Berkeley / Dorchester)
    CREATE TABLE IF NOT EXISTS leads.deed_recordings (
      id              BIGSERIAL PRIMARY KEY,
      county          TEXT NOT NULL,
      document_id     TEXT NOT NULL,
      filing_date     DATE NOT NULL,
      buyer_name      TEXT,
      seller_name     TEXT,
      property_address TEXT,
      city            TEXT,
      sale_price      NUMERIC(14, 2),
      deed_type       TEXT,
      source_url      TEXT,
      raw_payload     JSONB,
      scraped_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (county, document_id)
    );
    CREATE INDEX IF NOT EXISTS idx_deed_filing_date ON leads.deed_recordings (filing_date DESC);
    CREATE INDEX IF NOT EXISTS idx_deed_county_city ON leads.deed_recordings (county, city);
    CREATE INDEX IF NOT EXISTS idx_deed_buyer ON leads.deed_recordings (buyer_name);

    -- Charleston Chamber member directory (state-aware; tracks first_seen for "new member" digests)
    CREATE TABLE IF NOT EXISTS leads.chamber_members (
      id              BIGSERIAL PRIMARY KEY,
      business_name   TEXT NOT NULL,
      business_type   TEXT,
      address         TEXT,
      city            TEXT,
      member_url      TEXT,
      raw_payload     JSONB,
      first_seen      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      last_seen       TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_chamber_members_unique
      ON leads.chamber_members (business_name, COALESCE(address, ''));
    CREATE INDEX IF NOT EXISTS idx_chamber_first_seen ON leads.chamber_members (first_seen DESC);

    -- P&C + obituary life events (currently produced by n8n workflow #1; can migrate later)
    CREATE TABLE IF NOT EXISTS leads.life_events (
      id              BIGSERIAL PRIMARY KEY,
      source          TEXT NOT NULL,
      external_id     TEXT NOT NULL,
      event_type      TEXT NOT NULL,
      headline        TEXT,
      summary         TEXT,
      url             TEXT,
      published_at    TIMESTAMPTZ,
      raw_payload     JSONB,
      scraped_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (source, external_id)
    );
    CREATE INDEX IF NOT EXISTS idx_life_published ON leads.life_events (published_at DESC);
    CREATE INDEX IF NOT EXISTS idx_life_event_type ON leads.life_events (event_type);

    -- Daily digest delivery log so n8n can dedupe items it already sent
    CREATE TABLE IF NOT EXISTS leads.digest_log (
      id              BIGSERIAL PRIMARY KEY,
      digest_name     TEXT NOT NULL,
      lead_table      TEXT NOT NULL,
      lead_id         BIGINT NOT NULL,
      sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (digest_name, lead_table, lead_id)
    );
    CREATE INDEX IF NOT EXISTS idx_digest_sent ON leads.digest_log (sent_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON leads.business_licenses TO scrapers;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA leads TO scrapers;

-- DROP TABLE IF EXISTS leads.sos_business_filings;
