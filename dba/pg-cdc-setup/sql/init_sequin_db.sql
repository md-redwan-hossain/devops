-- Logical database for Sequin's own state (same Postgres host as the app DB).
-- Run once as a superuser against any DB (e.g. postgres). Name must match PG_DATABASE in .env.
-- Ignore "already exists" if re-run.

CREATE DATABASE sequin;
