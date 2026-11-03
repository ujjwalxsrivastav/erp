-- ============================================================
-- MIGRATION 23: Finance Module & Accountant User
-- ============================================================

-- 1. Drop existing role constraint and recreate it allowing accountant
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('student', 'teacher', 'admin', 'HR', 'hod', 'admissiondean', 'counsellor', 'temp_student', 'warden', 'transport_officer', 'conductor', 'accountant', 'superadmin'));

-- 2. Insert accountant1 into users table
INSERT INTO users (username, password, role)
VALUES (
  'accountant1',
  'accountant@123',
  'accountant'
)
ON CONFLICT (username) DO UPDATE
  SET role       = EXCLUDED.role,
      password   = EXCLUDED.password;

-- 3. Create tables for Fee Management
CREATE TABLE IF NOT EXISTS student_fees (
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

CREATE TABLE IF NOT EXISTS fee_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT,
    transaction_date TIMESTAMP DEFAULT now(),
    transaction_reference TEXT,
    fee_ids JSONB,
    created_at TIMESTAMP DEFAULT now()
);
