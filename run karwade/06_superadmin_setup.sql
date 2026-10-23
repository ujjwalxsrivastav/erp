-- ============================================================
-- 06: SuperAdmin / Institute Setup — Master Data
-- Module: Admin (SuperAdmin foundation)
-- Run in Supabase SQL Editor. Idempotent — safe to re-run.
-- Creates the MASTER tables for departments, designations and
-- academic years, plus a generic key/value institute_settings
-- store for the institute profile and branding.
-- NOTE: student_details.department / teacher_details.department
-- stay free TEXT in the existing tables; this module provides
-- the master list the app will pick from going forward.
-- ============================================================

-- ------------------------------------------------------------
-- 1. DEPARTMENTS (master)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT NOT NULL UNIQUE,
    code         TEXT NOT NULL UNIQUE,
    hod_username TEXT,
    email        TEXT,
    phone        TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE departments IS 'SuperAdmin master: institute departments. name/code are unique; hod_username points at the users.username / teacher_id of the Head of Department.';
COMMENT ON COLUMN departments.code IS 'Short department code, stored uppercase (e.g. CSE, ECE, ME).';
COMMENT ON COLUMN departments.hod_username IS 'Username of the teacher appointed HOD for this department.';

-- ------------------------------------------------------------
-- 2. DESIGNATIONS (master)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS designations (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title     TEXT NOT NULL UNIQUE,
    category  TEXT NOT NULL DEFAULT 'teaching'
              CHECK (category IN ('teaching', 'non_teaching', 'leadership')),
    level     INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE designations IS 'SuperAdmin master: staff designations grouped by category (teaching / non_teaching / leadership). level orders seniority within a category (higher = more senior).';

-- Common designations (seeded once; safe to re-run)
INSERT INTO designations (title, category, level) VALUES
    ('Professor',            'teaching',     4),
    ('Associate Professor',  'teaching',     3),
    ('Assistant Professor',  'teaching',     2),
    ('Lecturer',             'teaching',     1),
    ('HOD',                  'leadership',   3),
    ('Dean',                 'leadership',   4),
    ('Lab Technician',       'non_teaching', 1),
    ('Clerk',                'non_teaching', 1),
    ('Accountant',           'non_teaching', 2),
    ('Librarian',            'non_teaching', 2)
ON CONFLICT (title) DO NOTHING;

-- ------------------------------------------------------------
-- 3. ACADEMIC YEARS (master)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS academic_years (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label      TEXT NOT NULL UNIQUE,
    start_date DATE,
    end_date   DATE,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE academic_years IS 'SuperAdmin master: academic years (label like 2026-27). Exactly one row should have is_current = true; the app enforces this when switching.';
COMMENT ON COLUMN academic_years.label IS 'Display label, e.g. 2026-27.';

-- ------------------------------------------------------------
-- 4. INSTITUTE SETTINGS (key/value store)
-- Keys used by the app:
--   'institute_profile' -> {name, affiliation, address, phone,
--                           email, website, established_year}
--   'branding'          -> {primary_color, logo_url}
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS institute_settings (
    key        TEXT PRIMARY KEY,
    value      JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_by TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE institute_settings IS 'SuperAdmin: generic key/value store for institute-wide settings. value is a JSONB object; see header comment for the keys the app uses.';

-- ------------------------------------------------------------
-- 5. INDEXES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_departments_active ON departments(is_active);
CREATE INDEX IF NOT EXISTS idx_departments_hod ON departments(hod_username);
CREATE INDEX IF NOT EXISTS idx_designations_category ON designations(category);
CREATE INDEX IF NOT EXISTS idx_designations_active ON designations(is_active);
CREATE INDEX IF NOT EXISTS idx_academic_years_current ON academic_years(is_current);

-- ------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (repo-style permissive policies)
-- ------------------------------------------------------------
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "departments_all" ON departments;
CREATE POLICY "departments_all" ON departments
    FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE designations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "designations_all" ON designations;
CREATE POLICY "designations_all" ON designations
    FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE academic_years ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "academic_years_all" ON academic_years;
CREATE POLICY "academic_years_all" ON academic_years
    FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE institute_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "institute_settings_all" ON institute_settings;
CREATE POLICY "institute_settings_all" ON institute_settings
    FOR ALL USING (true) WITH CHECK (true);

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
