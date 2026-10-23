CREATE SCHEMA IF NOT EXISTS extensions;

DO $ext$
DECLARE
    ext_schema text;
BEGIN
    SELECT n.nspname INTO ext_schema
      FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
     WHERE e.extname = 'vector';
    IF NOT FOUND THEN
        CREATE EXTENSION vector WITH SCHEMA extensions;
    ELSIF ext_schema <> 'extensions' THEN
        ALTER EXTENSION vector SET SCHEMA extensions;
    END IF;
END
$ext$;

REVOKE ALL ON SCHEMA extensions FROM PUBLIC;
GRANT USAGE ON SCHEMA extensions TO kagent_owner, kagent_readwrite;
