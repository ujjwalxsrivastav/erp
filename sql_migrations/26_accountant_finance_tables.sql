-- ============================================================
-- MIGRATION 26: Dedicated Finance Tables for Accountant
-- ============================================================

CREATE TABLE IF NOT EXISTS finance_student_fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    fee_type TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, paid
    due_date DATE,
    paid_at TIMESTAMP,
    transaction_id TEXT,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS finance_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT,
    transaction_date TIMESTAMP DEFAULT now(),
    transaction_reference TEXT,
    fee_ids JSONB,
    created_at TIMESTAMP DEFAULT now()
);

-- Reload the schema cache for Supabase automatically
NOTIFY pgrst, 'reload schema';
