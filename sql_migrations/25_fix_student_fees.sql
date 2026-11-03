-- ============================================================
-- MIGRATION 25: Fix student_fees table schema
-- ============================================================

-- If the table already existed without these columns, this will add them.
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS fee_type TEXT;
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS amount NUMERIC(10, 2);
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS due_date DATE;
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS paid_at TIMESTAMP;
ALTER TABLE student_fees ADD COLUMN IF NOT EXISTS transaction_id TEXT;

-- Reload the schema cache for Supabase automatically
NOTIFY pgrst, 'reload schema';
