-- 003: Home sales table for new homeowner lead generation
-- Apply manually against existing cluster:
--   kubectl -n automation cp 003-home-sales.sql automation-pg-1:/tmp/
--   kubectl -n automation exec automation-pg-1 -- psql -U postgres -d leads -f /tmp/003-home-sales.sql

CREATE TABLE IF NOT EXISTS leads.home_sales (
  id                  BIGSERIAL PRIMARY KEY,
  county              TEXT NOT NULL,
  buyer_name          TEXT,
  seller_name         TEXT,
  property_address    TEXT,
  sale_price          NUMERIC(12, 2),
  sale_date           TIMESTAMPTZ NOT NULL,
  property_class      TEXT,
  parcel_id           TEXT NOT NULL,
  bedrooms            INTEGER,
  full_baths          INTEGER,
  half_baths          INTEGER,
  finished_sqft       INTEGER,
  year_built          INTEGER,
  neighborhood_code   TEXT,
  neighborhood_name   TEXT,
  raw_payload         JSONB,
  scraped_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (county, parcel_id, sale_date)
);

CREATE INDEX IF NOT EXISTS idx_hs_sale_date ON leads.home_sales (sale_date DESC);
CREATE INDEX IF NOT EXISTS idx_hs_buyer_name ON leads.home_sales (buyer_name);
CREATE INDEX IF NOT EXISTS idx_hs_property_address ON leads.home_sales (property_address) WHERE property_address IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hs_sale_price ON leads.home_sales (sale_price) WHERE sale_price IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hs_parcel_id ON leads.home_sales (parcel_id);
CREATE INDEX IF NOT EXISTS idx_hs_county_sale_date ON leads.home_sales (county, sale_date DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON leads.home_sales TO scrapers;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA leads TO scrapers;

COMMENT ON TABLE leads.home_sales IS 'Property sales from county tax/assessor APIs for new homeowner lead generation. Charleston County source: sc-charleston.publicaccessnow.com Real Property Sales Search API.';
