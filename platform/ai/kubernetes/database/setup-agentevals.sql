-- Provision schema + login role for agentevals run history (preview storage).
-- Tables are created by agentevals autoMigrate at pod startup.
-- Variables (psql --set):
--   agentevals_user, agentevals_password, agentevals_schema

SELECT
    set_config('agentevals.setup_user', :'agentevals_user', true) AS agentevals_user,
    set_config('agentevals.setup_password', :'agentevals_password', true) AS agentevals_password,
    set_config('agentevals.setup_schema', :'agentevals_schema', true) AS agentevals_schema
\gset

DO $setup$
DECLARE
    role_name text := current_setting('agentevals.setup_user');
    role_password text := NULLIF(current_setting('agentevals.setup_password'), '');
    schema_name text := current_setting('agentevals.setup_schema');
    schema_owner text;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('agentevals:setup:' || schema_name, 0));

    IF role_password IS NULL THEN
        RAISE EXCEPTION 'agentevals password must not be empty';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE format(
            'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L',
            role_name, role_password
        );
    ELSE
        EXECUTE format('ALTER ROLE %I PASSWORD %L', role_name, role_password);
    END IF;

    EXECUTE format('GRANT CONNECT, CREATE ON DATABASE %I TO %I', current_database(), role_name);

    SELECT pg_get_userbyid(nspowner) INTO schema_owner
      FROM pg_namespace WHERE nspname = schema_name;
    IF NOT FOUND THEN
        EXECUTE format('CREATE SCHEMA %I AUTHORIZATION %I', schema_name, role_name);
    ELSIF schema_owner <> role_name THEN
        RAISE EXCEPTION 'schema "%" is owned by "%", not "%"', schema_name, schema_owner, role_name;
    END IF;

    EXECUTE format('REVOKE ALL ON SCHEMA %I FROM PUBLIC', schema_name);
    EXECUTE format('GRANT ALL ON SCHEMA %I TO %I', schema_name, role_name);
    EXECUTE format('ALTER ROLE %I SET search_path TO %I, public', role_name, schema_name);
END
$setup$;
