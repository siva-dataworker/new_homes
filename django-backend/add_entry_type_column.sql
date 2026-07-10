-- Add entry_type column to labour_entries table
-- This column tracks whether an entry is morning or evening

ALTER TABLE labour_entries
ADD COLUMN IF NOT EXISTS entry_type VARCHAR(10) CHECK (entry_type IN ('morning', 'evening')) DEFAULT 'morning';

ALTER TABLE material_balances
ADD COLUMN IF NOT EXISTS entry_type VARCHAR(10) CHECK (entry_type IN ('morning', 'evening')) DEFAULT 'morning';

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_labour_entry_type ON labour_entries(entry_type);
CREATE INDEX IF NOT EXISTS idx_labour_site_date_type ON labour_entries(site_id, entry_date, entry_type);
CREATE INDEX IF NOT EXISTS idx_labour_site_date_type_labour ON labour_entries(site_id, entry_date, entry_type, labour_type);
CREATE INDEX IF NOT EXISTS idx_labour_site_date_type_labour_role ON labour_entries(site_id, entry_date, entry_type, labour_type, submitted_by_role);

-- Verify the changes
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'labour_entries'
    AND column_name IN ('entry_type', 'labour_type', 'entry_date', 'submitted_by_role')
ORDER BY ordinal_position;
