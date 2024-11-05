-- Set variables for the database, schema, users, and passwords
\set dbname 'test_db'
\set schema_to_create 'test_schema'
\set admin_user 'test_db_admin'
\set admin_password 'admin_password'
\set regular_user 'test_db_user'
\set user_password 'user_password'

-- Connect to the database
\c :dbname

-- Grant full privileges to the admin user
GRANT ALL PRIVILEGES ON DATABASE :dbname TO :admin_user;
GRANT ALL PRIVILEGES ON SCHEMA :schema_to_create TO :admin_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA :schema_to_create TO :admin_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA :schema_to_create TO :admin_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA :schema_to_create TO :admin_user;

-- Set default privileges for the admin user
ALTER DEFAULT PRIVILEGES IN SCHEMA :schema_to_create GRANT ALL PRIVILEGES ON TABLES TO :admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA :schema_to_create GRANT ALL PRIVILEGES ON SEQUENCES TO :admin_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA :schema_to_create GRANT ALL PRIVILEGES ON FUNCTIONS TO :admin_user;

-- Grant limited privileges to the regular user
GRANT CONNECT ON DATABASE :dbname TO :regular_user;
GRANT USAGE ON SCHEMA :schema_to_create TO :regular_user;

-- Grant full privileges excluding DROP on tables and sequences
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA :schema_to_create TO :regular_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA :schema_to_create TO :regular_user;

-- Grant EXECUTE privilege on all existing functions to the regular user
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA :schema_to_create TO :regular_user;

-- Set default privileges for the regular user for new objects created by admin_user
ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :regular_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO :regular_user;

ALTER DEFAULT PRIVILEGES FOR ROLE :admin_user IN SCHEMA :schema_to_create
GRANT EXECUTE ON FUNCTIONS TO :regular_user;
