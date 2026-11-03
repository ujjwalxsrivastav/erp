-- ============================================================================
-- SCHOOL FEES BACKEND
-- Run this in Supabase Dashboard -> SQL Editor.
--
-- Safe to re-run. It does NOT insert demo/dummy data.
--
-- Design rule:
--   * school_fee_accounts.total_fee is the fixed fee amount.
--   * A successful payment only increases paid_amount.
--   * pending_amount is always recalculated as total_fee - paid_amount.
--   * Payments can never change total_fee.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. School student profile
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_students (
    id              TEXT PRIMARY KEY DEFAULT (gen_random_uuid()::text),
    username        TEXT NOT NULL UNIQUE,          -- matches users.username
    name            TEXT NOT NULL,
    class_id        TEXT,                          -- matches school_classes.id
    class_name      TEXT,
    section         TEXT,
    roll_number     TEXT,
    admission_no    TEXT UNIQUE,
    parent_name     TEXT,
    contact         TEXT,
    academic_year   TEXT NOT NULL DEFAULT '2024-2025',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_students_class
    ON public.school_students (class_id);

CREATE INDEX IF NOT EXISTS idx_school_students_username
    ON public.school_students (username);

-- ---------------------------------------------------------------------------
-- 2. One fee account per student per academic year
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_fee_accounts (
    id                TEXT PRIMARY KEY DEFAULT (gen_random_uuid()::text),
    student_id        TEXT NOT NULL,               -- school_students.id
    student_username  TEXT NOT NULL,               -- users.username
    class_id          TEXT,
    class_name        TEXT,
    section           TEXT,
    academic_year     TEXT NOT NULL DEFAULT '2024-2025',
    total_fee         NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_fee >= 0),
    paid_amount       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
    pending_amount    NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (pending_amount >= 0),
    status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'partial', 'paid')),
    last_payment_date TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (student_id, academic_year),
    CONSTRAINT school_fee_accounts_paid_within_total
        CHECK (paid_amount <= total_fee)
);

CREATE INDEX IF NOT EXISTS idx_school_fee_accounts_student
    ON public.school_fee_accounts (student_id);

CREATE INDEX IF NOT EXISTS idx_school_fee_accounts_username
    ON public.school_fee_accounts (student_username);

CREATE INDEX IF NOT EXISTS idx_school_fee_accounts_year
    ON public.school_fee_accounts (academic_year);

-- ---------------------------------------------------------------------------
-- 3. Optional fee breakdown/heads for display
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_fee_items (
    id            TEXT PRIMARY KEY DEFAULT (gen_random_uuid()::text),
    account_id    TEXT NOT NULL
                  REFERENCES public.school_fee_accounts(id) ON DELETE CASCADE,
    fee_head      TEXT NOT NULL,
    amount        NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (account_id, fee_head)
);

CREATE INDEX IF NOT EXISTS idx_school_fee_items_account
    ON public.school_fee_items (account_id);

-- ---------------------------------------------------------------------------
-- 4. Payment receipts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_fee_payments (
    id                TEXT PRIMARY KEY DEFAULT (gen_random_uuid()::text),
    account_id        TEXT NOT NULL
                      REFERENCES public.school_fee_accounts(id) ON DELETE CASCADE,
    student_id        TEXT NOT NULL,
    student_username  TEXT NOT NULL,
    amount            NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_mode      TEXT NOT NULL DEFAULT 'online',
    reference         TEXT,
    receipt_no        TEXT NOT NULL UNIQUE,
    status            TEXT NOT NULL DEFAULT 'success'
                      CHECK (status IN ('pending', 'success', 'failed')),
    paid_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_fee_payments_account
    ON public.school_fee_payments (account_id);

CREATE INDEX IF NOT EXISTS idx_school_fee_payments_student
    ON public.school_fee_payments (student_id);

CREATE INDEX IF NOT EXISTS idx_school_fee_payments_username
    ON public.school_fee_payments (student_username);

-- ---------------------------------------------------------------------------
-- 5. Recalculate pending amount/status on every account write
--    total_fee is NEVER changed here.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.school_fee_account_set_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.total_fee := COALESCE(NEW.total_fee, 0);
    NEW.paid_amount := COALESCE(NEW.paid_amount, 0);
    NEW.pending_amount := GREATEST(NEW.total_fee - NEW.paid_amount, 0);

    IF NEW.pending_amount = 0 THEN
        NEW.status := 'paid';
    ELSIF NEW.paid_amount > 0 THEN
        NEW.status := 'partial';
    ELSE
        NEW.status := 'pending';
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_school_fee_account_set_totals
    ON public.school_fee_accounts;
CREATE TRIGGER trg_school_fee_account_set_totals
BEFORE INSERT OR UPDATE ON public.school_fee_accounts
FOR EACH ROW
EXECUTE FUNCTION public.school_fee_account_set_totals();

-- ---------------------------------------------------------------------------
-- 6. Apply a successful payment.
--    Only paid_amount is increased; total_fee stays fixed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_school_fee_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    acc RECORD;
    pending NUMERIC(12,2);
BEGIN
    IF NEW.status <> 'success' THEN
        RETURN NEW;
    END IF;

    -- Do not apply the same successful payment twice on update.
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'success' THEN
            RETURN NEW;
        END IF;
    END IF;

    SELECT * INTO acc
    FROM public.school_fee_accounts
    WHERE id = NEW.account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fee account % not found', NEW.account_id;
    END IF;

    pending := acc.total_fee - acc.paid_amount;

    IF NEW.amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be positive';
    END IF;

    IF NEW.amount > pending THEN
        RAISE EXCEPTION 'Payment amount % exceeds pending amount %',
            NEW.amount, pending;
    END IF;

    UPDATE public.school_fee_accounts
    SET paid_amount = paid_amount + NEW.amount,
        last_payment_date = COALESCE(NEW.paid_at, now())
    WHERE id = NEW.account_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_school_fee_payment
    ON public.school_fee_payments;
CREATE TRIGGER trg_apply_school_fee_payment
AFTER INSERT OR UPDATE ON public.school_fee_payments
FOR EACH ROW
EXECUTE FUNCTION public.apply_school_fee_payment();

-- ---------------------------------------------------------------------------
-- 7. Keep school_students.updated_at fresh
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.school_students_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_school_students_updated_at
    ON public.school_students;
CREATE TRIGGER trg_school_students_updated_at
BEFORE UPDATE ON public.school_students
FOR EACH ROW
EXECUTE FUNCTION public.school_students_touch_updated_at();

-- ---------------------------------------------------------------------------
-- 8. Permissive RLS (matches the app's current anon-key access model)
-- ---------------------------------------------------------------------------
ALTER TABLE public.school_students       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_fee_accounts   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_fee_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_fee_payments   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS school_students_all ON public.school_students;
CREATE POLICY school_students_all
    ON public.school_students FOR ALL
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS school_fee_accounts_all ON public.school_fee_accounts;
CREATE POLICY school_fee_accounts_all
    ON public.school_fee_accounts FOR ALL
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS school_fee_items_all ON public.school_fee_items;
CREATE POLICY school_fee_items_all
    ON public.school_fee_items FOR ALL
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS school_fee_payments_all ON public.school_fee_payments;
CREATE POLICY school_fee_payments_all
    ON public.school_fee_payments FOR ALL
    USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE
    ON public.school_students,
       public.school_fee_accounts,
       public.school_fee_items,
       public.school_fee_payments
    TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Convenience view for the principal/admin fee dashboard (next step)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.school_student_fee_summary AS
SELECT
    s.id                AS student_id,
    s.username,
    s.name,
    s.class_id,
    s.class_name,
    s.section,
    s.admission_no,
    a.id                AS account_id,
    a.academic_year,
    a.total_fee,
    a.paid_amount,
    a.pending_amount,
    a.status,
    a.last_payment_date
FROM public.school_students s
LEFT JOIN public.school_fee_accounts a
       ON a.student_id = s.id;

GRANT SELECT ON public.school_student_fee_summary TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 10. Manual setup example (commented out intentionally - no dummy data)
-- ---------------------------------------------------------------------------
-- INSERT INTO public.school_students
--     (username, name, class_id, class_name, section, roll_number, admission_no,
--      parent_name, contact, academic_year)
-- SELECT
--     'sstudent1', 'Student Name', c.id::text, c.name, c.section,
--     '01', 'ADM2026001', 'Parent Name', '9876543210', c.academic_year
-- FROM public.school_classes c
-- WHERE c.name = 'Class 10' AND c.section = 'A'
-- LIMIT 1
-- ON CONFLICT (username) DO NOTHING;
--
-- INSERT INTO public.school_fee_accounts
--     (student_id, student_username, class_id, class_name, section,
--      academic_year, total_fee)
-- SELECT id, username, class_id, class_name, section, academic_year, 60000
-- FROM public.school_students
-- WHERE username = 'sstudent1'
-- ON CONFLICT (student_id, academic_year) DO NOTHING;
--
-- INSERT INTO public.school_fee_items (account_id, fee_head, amount, display_order)
-- SELECT id, 'Tuition Fee', 45000, 1 FROM public.school_fee_accounts
-- WHERE student_username = 'sstudent1'
-- UNION ALL
-- SELECT id, 'Exam & Activity Fee', 8000, 2 FROM public.school_fee_accounts
-- WHERE student_username = 'sstudent1'
-- UNION ALL
-- SELECT id, 'Transport Fee', 7000, 3 FROM public.school_fee_accounts
-- WHERE student_username = 'sstudent1';

-- ---------------------------------------------------------------------------
-- Done
-- ---------------------------------------------------------------------------
SELECT 'School fees setup completed successfully' AS result;
