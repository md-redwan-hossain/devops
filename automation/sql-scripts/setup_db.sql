-- Control flags for what to create (set to FALSE to skip creation)
\set create_database TRUE
\set create_admin_user TRUE
\set create_schema FALSE
\set create_regular_user FALSE
\set create_readonly_user FALSE
\set drop_existing FALSE

-- Set variables for the database, schema, users, and passwords
\set dbname 'test_db'
\set schema_to_create 'test_schema'
\set admin_user 'test_db_admin'
\set admin_password 'admin_password'
\set regular_user 'test_db_user'
\set regular_user_password 'regular_user_password'
\set readonly_user 'test_db_readonly'
\set readonly_user_password 'readonly_user_password'

-- Drop existing resources if flag is set
\if :drop_existing
DROP DATABASE IF EXISTS :dbname;
DROP USER IF EXISTS :admin_user;
DROP USER IF EXISTS :regular_user;
DROP USER IF EXISTS :readonly_user;
\endif

-- Create the database if flag is set
\if :create_database
CREATE DATABASE :dbname;
\endif

-- Connect to the database
\c :dbname

-- Create schema if flag is set
\if :create_schema
CREATE SCHEMA :schema_to_create;
\endif

-- Create admin user if flag is set
\if :create_admin_user
CREATE USER :admin_user WITH ENCRYPTED PASSWORD :'admin_password';
\endif

-- Create regular user if flag is set
\if :create_regular_user
CREATE USER :regular_user WITH ENCRYPTED PASSWORD :'regular_user_password';
\endif

-- Create readonly user if flag is set
\if :create_readonly_user
CREATE USER :readonly_user WITH ENCRYPTED PASSWORD :'readonly_user_password';
\endif

-- ============================================================================
-- GRANT PRIVILEGES TO ADMIN USER
-- ============================================================================
\if :create_admin_user

-- Grant full privileges to the admin user on database
GRANT ALL PRIVILEGES ON DATABASE :dbname TO :admin_user;

-- Grant privileges on test_schema if it's being created
\if :create_schema
GRANT ALL PRIVILEGES ON SCHEMA :schema_to_create TO :admin_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA :schema_to_create TO :admin_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA :schema_to_create TO :admin_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA :schema_to_create TO :admin_user;

-- Set default privileges for the admin user on test_schema
ALTER DEFAULT PRIVILEGES IN SCHEMA :schema_to_create GRANT ALL PRIVILEGES ON TABLES TO :admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA :schema_to_create GRANT ALL PRIVILEGES ON SEQUENCES TO :admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA :schema_to_create GRANT ALL PRIVILEGES ON FUNCTIONS TO :admin_user;
\endif

-- Grant full privileges to the admin user on public schema
GRANT ALL PRIVILEGES ON SCHEMA public TO :admin_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO :admin_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO :admin_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO :admin_user;

-- Set default privileges for the admin user on public schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO :admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO :admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO :admin_user;

\endif

-- ============================================================================
-- GRANT PRIVILEGES TO REGULAR USER
-- ============================================================================
\if :create_regular_user

-- Grant limited privileges to the regular user
GRANT CONNECT ON DATABASE :dbname TO :regular_user;

-- Grant privileges on test_schema if it's being created
\if :create_schema
GRANT USAGE ON SCHEMA :schema_to_create TO :regular_user;

-- Grant limited privileges on tables and sequences in test_schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA :schema_to_create TO :regular_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA :schema_to_create TO :regular_user;

-- Grant EXECUTE privilege on all existing functions in test_schema to the regular user
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA :schema_to_create TO :regular_user;

-- Set default privileges for the regular user for new objects created by admin_user in test_schema
ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :regular_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO :regular_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT EXECUTE ON FUNCTIONS TO :regular_user;
\endif

-- Grant limited privileges to the regular user on public schema
GRANT USAGE ON SCHEMA public TO :regular_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :regular_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO :regular_user;

-- Grant EXECUTE privilege on all existing functions in public schema to the regular user
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO :regular_user;

-- Set default privileges for the regular user for new objects created by admin_user in public schema
ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :regular_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO :regular_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA public
GRANT EXECUTE ON FUNCTIONS TO :regular_user;

\endif

-- ============================================================================
-- GRANT PRIVILEGES TO READONLY USER
-- ============================================================================
\if :create_readonly_user

-- Grant privileges to the read-only user
GRANT CONNECT ON DATABASE :dbname TO :readonly_user;

-- Grant privileges on test_schema if it's being created
\if :create_schema
GRANT USAGE ON SCHEMA :schema_to_create TO :readonly_user;

-- Grant SELECT privilege on all tables and views in test_schema
GRANT SELECT ON ALL TABLES IN SCHEMA :schema_to_create TO :readonly_user;

-- Grant USAGE and SELECT privilege on all sequences in test_schema
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA :schema_to_create TO :readonly_user;

-- Grant EXECUTE privilege on all functions in test_schema
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA :schema_to_create TO :readonly_user;

-- Set default privileges for the read-only user for new objects in test_schema
ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT SELECT ON TABLES TO :readonly_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT USAGE, SELECT ON SEQUENCES TO :readonly_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT EXECUTE ON FUNCTIONS TO :readonly_user;
\endif

-- Grant privileges to the read-only user on public schema
GRANT USAGE ON SCHEMA public TO :readonly_user;

-- Grant SELECT privilege on all tables and views in public schema
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :readonly_user;

-- Grant USAGE and SELECT privilege on all sequences in public schema
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :readonly_user;

-- Grant EXECUTE privilege on all functions in public schema
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO :readonly_user;

-- Set default privileges for the read-only user for new objects in public schema
ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA public
GRANT SELECT ON TABLES TO :readonly_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO :readonly_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA public
GRANT EXECUTE ON FUNCTIONS TO :readonly_user;

\endif
