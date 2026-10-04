-- ============================================================================
-- CONTROL FLAGS (set to FALSE to skip)
-- ============================================================================
\set create_database TRUE
\set create_admin_user TRUE
\set create_schema FALSE
\set create_regular_user FALSE
\set create_readonly_user FALSE
\set drop_existing FALSE

-- ============================================================================
-- NAMES AND PASSWORDS (change the passwords!)
-- ============================================================================
\set dbname                'test_db'
\set schema_to_create      'test_schema'
\set admin_user            'test_db_admin'
\set admin_password        'admin_password'
\set regular_user          'test_db_user'
\set regular_user_password 'regular_user_password'
\set readonly_user         'test_db_readonly'
\set readonly_user_password 'readonly_user_password'

-- The role that actually CREATES tables (the user in your EF Core connection
-- string / migrations). Default privileges only apply to objects created by
-- this role. Change it if migrations do not run as the admin user.
\set table_creator_role    :admin_user

-- ============================================================================
-- DROP EXISTING (only if drop_existing is TRUE)
-- ============================================================================
\if :drop_existing
    \if :create_database
        DROP DATABASE IF EXISTS :dbname;
    \endif
    \if :create_admin_user
        DROP USER IF EXISTS :admin_user;
    \endif
    \if :create_regular_user
        DROP USER IF EXISTS :regular_user;
    \endif
    \if :create_readonly_user
        DROP USER IF EXISTS :readonly_user;
    \endif
\endif

-- ============================================================================
-- CREATE DATABASE, SCHEMA, USERS
-- ============================================================================
\if :create_database
    CREATE DATABASE :dbname;
\endif

\c :dbname

\if :create_schema
    CREATE SCHEMA :schema_to_create;
\endif

\if :create_admin_user
    CREATE USER :admin_user WITH ENCRYPTED PASSWORD :'admin_password';
\endif

\if :create_regular_user
    CREATE USER :regular_user WITH ENCRYPTED PASSWORD :'regular_user_password';
\endif

\if :create_readonly_user
    CREATE USER :readonly_user WITH ENCRYPTED PASSWORD :'readonly_user_password';
\endif

-- ============================================================================
-- PASS PSQL VARIABLES INTO DO BLOCKS
-- (psql variables are not expanded inside $$ ... $$, so use session settings)
-- ============================================================================
SELECT set_config('app.dbname',       :'dbname',             false) AS a,
       set_config('app.admin_user',   :'admin_user',         false) AS b,
       set_config('app.regular_user', :'regular_user',       false) AS c,
       set_config('app.readonly_user',:'readonly_user',      false) AS d,
       set_config('app.creator_role', :'table_creator_role', false) AS e
\gset cfg_

-- ============================================================================
-- ADMIN USER: full access to every user schema
-- ============================================================================
\if :create_admin_user

GRANT ALL PRIVILEGES ON DATABASE :dbname TO :admin_user;

DO $$
DECLARE
    s       text;
    usr     text := current_setting('app.admin_user');
    creator text := current_setting('app.creator_role');
BEGIN
    FOR s IN
        SELECT nspname FROM pg_namespace
        WHERE nspname !~ '^pg_' AND nspname <> 'information_schema'
    LOOP
        -- existing objects
        EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA %I TO %I', s, usr);

        -- future objects created by the table creator role
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT ALL PRIVILEGES ON TABLES TO %I', creator, s, usr);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT ALL PRIVILEGES ON SEQUENCES TO %I', creator, s, usr);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT ALL PRIVILEGES ON FUNCTIONS TO %I', creator, s, usr);
    END LOOP;
END $$;

\endif

-- ============================================================================
-- REGULAR USER: read/write data in every user schema
-- ============================================================================
\if :create_regular_user

GRANT CONNECT ON DATABASE :dbname TO :regular_user;

DO $$
DECLARE
    s       text;
    usr     text := current_setting('app.regular_user');
    creator text := current_setting('app.creator_role');
BEGIN
    FOR s IN
        SELECT nspname FROM pg_namespace
        WHERE nspname !~ '^pg_' AND nspname <> 'information_schema'
    LOOP
        -- existing objects
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO %I', s, usr);

        -- future objects created by the table creator role
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I', creator, s, usr);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I', creator, s, usr);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT EXECUTE ON FUNCTIONS TO %I', creator, s, usr);
    END LOOP;
END $$;

\endif

-- ============================================================================
-- READONLY USER: read-only access in every user schema
-- ============================================================================
\if :create_readonly_user

GRANT CONNECT ON DATABASE :dbname TO :readonly_user;

DO $$
DECLARE
    s       text;
    usr     text := current_setting('app.readonly_user');
    creator text := current_setting('app.creator_role');
BEGIN
    FOR s IN
        SELECT nspname FROM pg_namespace
        WHERE nspname !~ '^pg_' AND nspname <> 'information_schema'
    LOOP
        -- existing objects
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA %I TO %I', s, usr);
        EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO %I', s, usr);

        -- future objects created by the table creator role
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT SELECT ON TABLES TO %I', creator, s, usr);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT USAGE, SELECT ON SEQUENCES TO %I', creator, s, usr);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA %I GRANT EXECUTE ON FUNCTIONS TO %I', creator, s, usr);
    END LOOP;
END $$;

\endif