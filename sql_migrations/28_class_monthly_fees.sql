-- ============================================================
-- MIGRATION 28: Class-wise monthly fees
-- ============================================================
-- Every student in the same class pays the same monthly fee. Admins will be
-- able to edit these rows; until then the seeded values apply and the app
-- falls back to the same defaults if this table is not present yet.

CREATE TABLE IF NOT EXISTS public.school_class_monthly_fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id TEXT,
    class_name TEXT NOT NULL,
    grade INT,
    monthly_fee NUMERIC(10, 2) NOT NULL DEFAULT 0,
    academic_year TEXT NOT NULL DEFAULT '2026-27',
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS school_class_monthly_fees_year_grade
    ON public.school_class_monthly_fees (academic_year, grade);

-- Seeded defaults (Pre-Primary through Class 12).
INSERT INTO public.school_class_monthly_fees (class_name, grade, monthly_fee, academic_year)
VALUES
    ('Pre-Primary', 0, 2500.00, '2026-27'),
    ('Class 1', 1, 3200.00, '2026-27'),
    ('Class 2', 2, 3200.00, '2026-27'),
    ('Class 3', 3, 3200.00, '2026-27'),
    ('Class 4', 4, 3500.00, '2026-27'),
    ('Class 5', 5, 3500.00, '2026-27'),
    ('Class 6', 6, 4200.00, '2026-27'),
    ('Class 7', 7, 4200.00, '2026-27'),
    ('Class 8', 8, 4500.00, '2026-27'),
    ('Class 9', 9, 4800.00, '2026-27'),
    ('Class 10', 10, 5000.00, '2026-27'),
    ('Class 11', 11, 5500.00, '2026-27'),
    ('Class 12', 12, 6000.00, '2026-27')
ON CONFLICT (academic_year, grade) DO NOTHING;

-- Reload the schema cache for Supabase automatically
NOTIFY pgrst, 'reload schema';
