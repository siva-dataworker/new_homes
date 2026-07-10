-- Complete Database Schema Fix for Labour Entry Issue
-- This migration ensures both Supervisor and Site Engineer can submit same labour type separately
-- Date: 2026-05-16

BEGIN;

-- ============================================
-- 1. ADD MISSING COLUMNS
-- ============================================

-- Add entry_type column if it doesn't exist
ALTER TABLE labour_entries
ADD COLUMN IF NOT EXISTS entry_type VARCHAR(10) DEFAULT 'morning'
    CHECK (entry_type IN ('morning', 'evening'));

-- Verify column was added
SELECT 'labour_entries.entry_type column added' AS step;

-- ============================================
-- 2. REMOVE CONFLICTING UNIQUE CONSTRAINTS
-- ============================================

-- Drop any existing unique constraint on (site_id, entry_date, labour_type)
-- which would prevent multiple roles from submitting the same labour type
ALTER TABLE labour_entries
DROP CONSTRAINT IF EXISTS labour_entries_site_id_entry_date_labour_type_key;

-- Also check for partial constraint names
ALTER TABLE labour_entries
DROP CONSTRAINT IF EXISTS labour_entries_site_id_entry_date_key;

SELECT 'Dropped conflicting UNIQUE constraints' AS step;

-- ============================================
-- 3. CREATE COMPOSITE INDEXES FOR EFFICIENCY
-- ============================================

-- Index for the new duplicate check query
-- Covers: (site_id, entry_date, entry_type, labour_type, submitted_by_role)
CREATE INDEX IF NOT EXISTS idx_labour_check_duplicate
    ON labour_entries(site_id, entry_date, entry_type, labour_type, submitted_by_role);

-- Additional indexes for common queries
CREATE INDEX IF NOT EXISTS idx_labour_site_date
    ON labour_entries(site_id, entry_date);

CREATE INDEX IF NOT EXISTS idx_labour_site_date_type
    ON labour_entries(site_id, entry_date, entry_type);

CREATE INDEX IF NOT EXISTS idx_labour_role
    ON labour_entries(submitted_by_role);

SELECT 'Created composite indexes' AS step;

-- ============================================
-- 4. VERIFY SCHEMA
-- ============================================

-- Check that all required columns exist
SELECT
    'labour_entries' as table_name,
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'labour_entries'
    AND column_name IN (
        'id', 'site_id', 'supervisor_id', 'labour_type', 'labour_count',
        'entry_date', 'entry_type', 'submitted_by_role', 'extra_cost'
    )
ORDER BY ordinal_position;

-- Check indexes
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'labour_entries'
    AND indexname LIKE 'idx_labour%'
ORDER BY indexname;

-- Check constraints
SELECT
    conname as constraint_name,
    contype as type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'labour_entries'::regclass
ORDER BY conname;

SELECT 'Schema verification complete' AS step;

COMMIT;
