CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_type') THEN
        CREATE TYPE user_type AS ENUM ('ADMIN', 'EDITOR', 'VIEWER');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS auth (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP,
    created_by TEXT,
    updated_by TEXT,
    deleted_by TEXT,
    email VARCHAR(320) UNIQUE NOT NULL,
    "password" TEXT NOT NULL,
    user_type user_type NOT NULL DEFAULT 'VIEWER'
);

-- Ensure the `update_modified_column` function exists
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a function that will apply the trigger to all tables dynamically
CREATE OR REPLACE FUNCTION sync_updated_at_triggers()
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT table_name FROM information_schema.columns
              WHERE column_name = 'updated_at' AND table_schema = current_schema())
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trigger_set_timestamp_%I ON %I;
            CREATE TRIGGER trigger_set_timestamp_%I
            BEFORE UPDATE ON %I
            FOR EACH ROW
            EXECUTE FUNCTION update_modified_column();',
            r.table_name, r.table_name, r.table_name, r.table_name);
    END LOOP;
END $$ LANGUAGE plpgsql;
