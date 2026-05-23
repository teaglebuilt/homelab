-- n8n application database (separate from leads).
-- Role setup is idempotent; CREATE DATABASE runs once on first cluster bootstrap.
DO $do$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n') THEN
    CREATE ROLE n8n LOGIN PASSWORD 'n8n-password';
  ELSE
    ALTER ROLE n8n WITH PASSWORD 'n8n-password';
  END IF;
END
$do$;

CREATE DATABASE n8n OWNER n8n;
