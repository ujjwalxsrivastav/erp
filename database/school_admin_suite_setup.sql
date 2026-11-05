-- ============================================================================
-- SCHOOL ERP: ADMIN DASHBOARD SUITE DDL & RLS POLICIES (ADM5)
-- Tables: school_settings, school_audit_log
-- ============================================================================

-- 1. Table: school_settings (N5: Institute Settings & Statutory Configuration)
CREATE TABLE IF NOT EXISTS public.school_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT NOT NULL DEFAULT 'SHIV-SCH',
    school_name TEXT NOT NULL DEFAULT 'Shivalik International School',
    affiliation_no TEXT NOT NULL DEFAULT 'CBSE #3530124',
    udise_code TEXT NOT NULL DEFAULT '05050100101',
    academic_session TEXT NOT NULL DEFAULT '2025-2026',
    current_term TEXT NOT NULL DEFAULT 'Term II',
    rte_quota_seats INTEGER NOT NULL DEFAULT 45,
    fire_noc_expiry DATE DEFAULT '2027-12-31',
    sanitation_cert_expiry DATE DEFAULT '2027-06-30',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on school_settings
ALTER TABLE public.school_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Anyone authenticated can read school_settings
CREATE POLICY "Allow authenticated read on school_settings"
    ON public.school_settings
    FOR SELECT
    TO authenticated
    USING (true);

-- RLS Policy: Only admin can insert/update school_settings
CREATE POLICY "Allow admin write on school_settings"
    ON public.school_settings
    FOR ALL
    TO authenticated
    USING (
        auth.jwt() ->> 'role' IN ('admin', 'sadmin') OR
        (auth.jwt() -> 'app_metadata' ->> 'role') IN ('admin', 'sadmin')
    )
    WITH CHECK (
        auth.jwt() ->> 'role' IN ('admin', 'sadmin') OR
        (auth.jwt() -> 'app_metadata' ->> 'role') IN ('admin', 'sadmin')
    );

-- 2. Table: school_audit_log (N4: Immutable System Audit Trail)
CREATE TABLE IF NOT EXISTS public.school_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT NOT NULL DEFAULT 'SHIV-SCH',
    actor_username TEXT NOT NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    old_value JSONB,
    new_value JSONB,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on school_audit_log
ALTER TABLE public.school_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only admin can read audit logs
CREATE POLICY "Allow admin read on school_audit_log"
    ON public.school_audit_log
    FOR SELECT
    TO authenticated
    USING (
        auth.jwt() ->> 'role' IN ('admin', 'sadmin') OR
        (auth.jwt() -> 'app_metadata' ->> 'role') IN ('admin', 'sadmin')
    );

-- RLS Policy: Service layer authenticated users can insert audit logs
CREATE POLICY "Allow authenticated insert on school_audit_log"
    ON public.school_audit_log
    FOR INSERT
    TO authenticated
    WITH CHECK (true);
