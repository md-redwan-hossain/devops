-- Run against the app database (DB_NAME) as a superuser.
-- Creates sequin_user + publication sequin_pub (all public tables except audit_logs).
-- Set sequin_user password to match SEQUIN_USER_PASSWORD before or after this script.

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sequin_user') THEN
        CREATE ROLE sequin_user WITH LOGIN REPLICATION PASSWORD 'change-me';
    ELSE
        ALTER ROLE sequin_user WITH LOGIN REPLICATION;
    END IF;
END
$$;

DO $$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO sequin_user', current_database());
END
$$;

GRANT USAGE ON SCHEMA public TO sequin_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO sequin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO sequin_user;

DO $$
DECLARE
    r record;
    parts text[] := ARRAY[]::text[];
    sql text;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'sequin_pub') THEN
        RAISE NOTICE 'publication sequin_pub already exists; skipping create';
        RETURN;
    END IF;

    FOR r IN
        SELECT n.nspname AS schema_name, c.relname AS table_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r', 'p')
          AND n.nspname = 'public'
          AND c.relname <> 'audit_logs'
        ORDER BY 1, 2
    LOOP
        parts := parts || format('%I.%I', r.schema_name, r.table_name);
    END LOOP;

    IF cardinality(parts) = 0 THEN
        EXECUTE $pub$
            CREATE PUBLICATION sequin_pub
            WITH (publish = 'insert, update, delete, truncate', publish_via_partition_root = true)
        $pub$;
        RAISE NOTICE 'created empty publication sequin_pub; ALTER PUBLICATION ... ADD TABLE as tables appear';
    ELSE
        sql := 'CREATE PUBLICATION sequin_pub FOR TABLE '
            || array_to_string(parts, ', ')
            || ' WITH (publish_via_partition_root = true)';
        EXECUTE sql;
    END IF;
END
$$;
