-- Database initialization script for Teable
-- This script ensures the database is properly set up for Teable

-- Create the database if it doesn't exist (this is usually handled by POSTGRES_DB)
-- But we can ensure proper encoding and settings

-- Set proper timezone
SET timezone = 'UTC';

-- Create extensions that Teable might need
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create a dedicated user for Teable if needed (optional)
-- This is useful if you want a separate user instead of postgres
-- DO $$
-- BEGIN
--     IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'teable') THEN
--         CREATE ROLE teable WITH LOGIN PASSWORD 'teable_password';
--         GRANT ALL PRIVILEGES ON DATABASE teable TO teable;
--     END IF;
-- END
-- $$;

-- Ensure proper permissions for the postgres user on the teable database
GRANT ALL PRIVILEGES ON DATABASE teable TO postgres;

-- Log the initialization
\echo 'Teable database initialization completed successfully!'
