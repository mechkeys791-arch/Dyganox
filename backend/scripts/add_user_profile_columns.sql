-- Add columns to person table for Cognito user profile (DOB, Gender)
-- Run this ONLY if Hibernate hasn't auto-created them (e.g., if table was created before model update)
-- Connect to RDS: psql -h postgresforpro.cw52wo446izi.us-east-1.rds.amazonaws.com -U postgres_ForPro -d postgres

-- Add email column if not exists (unique - links to Cognito)
ALTER TABLE person ADD COLUMN IF NOT EXISTS email VARCHAR(255) UNIQUE;

-- Add date_of_birth column if not exists
ALTER TABLE person ADD COLUMN IF NOT EXISTS date_of_birth VARCHAR(50);

-- Add gender column if not exists
ALTER TABLE person ADD COLUMN IF NOT EXISTS gender VARCHAR(50);

-- Add unique constraint on email (if column exists but constraint missing)
-- ALTER TABLE person ADD CONSTRAINT person_email_unique UNIQUE (email);
