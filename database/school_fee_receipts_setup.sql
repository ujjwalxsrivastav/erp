-- ============================================================================
-- SCHOOL FEE RECEIPTS — one row per PAYMENT made by a student
-- Run this in Supabase Dashboard -> SQL Editor.
--
-- Safe to re-run (idempotent). Single transaction (Supabase editor) — on any
-- error everything rolls back, just re-run the whole file.
--
-- Why this table exists:
--   * school_fee_payments is the DEMAND ledger — a demand row only keeps the
--     LATER receipt number when a fee is paid in parts, so older receipts of
--     past payments were being lost.
--   * school_fee_receipts stores EVERY payment as its own receipt, so the
--     student can download every receipt they have ever made (individually
--     or all at once in one PDF).
--
-- App behaviour:
--   * recordFeePayment() inserts a row here on every successful payment.
--   * If this table is missing/empty, the app falls back to deriving receipts
--     from the ledger's receipt_no values, so nothing breaks before you run
--     this file.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Receipts table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_fee_receipts (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_no    TEXT NOT NULL,
    student_id    TEXT NOT NULL,              -- school_students.username (login identity)
    student_name  TEXT,
    class_id      TEXT,
    amount        NUMERIC NOT NULL,           -- amount actually paid in THIS payment
    payment_mode  TEXT DEFAULT 'UPI',
    head          TEXT,                       -- fee head(s) this payment settled
    note          TEXT,
    paid_on       DATE,                       -- payment date (YYYY-MM-DD)
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_fee_receipts_student
    ON public.school_fee_receipts (student_id);

-- RLS stays OFF for the demo build (the app has no Supabase Auth session).
ALTER TABLE public.school_fee_receipts DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_fee_receipts
    TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Best-effort backfill from the existing ledger
--    One receipt per (receipt_no, student) = one payment that settled one or
--    more demand rows. Amount = sum of what that receipt actually covered.
--    Guarded with NOT EXISTS so re-running never duplicates rows, and rows the
--    app already recorded are never overwritten.
-- ---------------------------------------------------------------------------
INSERT INTO public.school_fee_receipts
    (receipt_no, student_id, student_name, class_id, amount,
     payment_mode, head, note, paid_on, created_at)
SELECT
    p.receipt_no,
    p.student_id,
    (SELECT st.name FROM public.school_students st
      WHERE st.username = p.student_id LIMIT 1),
    MIN(p.class_id),
    SUM(LEAST(p.paid_amount, p.amount)),      -- never attribute more than the demand
    MIN(p.payment_mode),
    STRING_AGG(DISTINCT p.head, ', '),
    'Backfilled from fee ledger',
    MIN(p.created_at)::date,
    MIN(p.created_at)
FROM public.school_fee_payments p
WHERE p.receipt_no IS NOT NULL
  AND p.receipt_no <> ''
  AND p.paid_amount > 0
  AND NOT EXISTS (
        SELECT 1 FROM public.school_fee_receipts r
         WHERE r.receipt_no = p.receipt_no
           AND r.student_id = p.student_id)
GROUP BY p.receipt_no, p.student_id;

SELECT 'School fee receipts setup completed successfully!' AS result;
