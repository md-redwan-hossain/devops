-- Set variables for the database, schema, users, and passwords
\set dbname 'test_db'
\set schema_to_create 'test_schema'
\set admin_user 'test_db_admin'
\set admin_password 'admin_password'
\set regular_user 'test_db_user'
\set user_password 'user_password'

-- Create the database
CREATE DATABASE :dbname;

-- Connect to the database
\c :dbname

-- Create schema
CREATE SCHEMA :schema_to_create;

-- Create users
CREATE USER :admin_user WITH ENCRYPTED PASSWORD :'admin_password';
CREATE USER :regular_user WITH ENCRYPTED PASSWORD :'user_password';
