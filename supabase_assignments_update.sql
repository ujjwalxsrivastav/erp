-- Add year and section to assignments for targeted distribution
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS year TEXT;
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS section TEXT;

-- Update existing assignments (if any) to have default values or leave null
-- For now, we leave them null which implies "all sections" or "legacy"
