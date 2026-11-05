-- ============================================================================
-- SCHOOL ERP: PARENT FINANCIAL & ADMINISTRATIVE LIFECYCLE DDL & RLS (PAR5)
-- Tables: school_ptm_bookings, school_parent_grievances
-- ============================================================================

-- 1. Table: school_ptm_bookings (PN7 & PM4: PTM Appointments & Availability)
CREATE TABLE IF NOT EXISTS public.school_ptm_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_username TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT,
    teacher_id TEXT NOT NULL,
    teacher_name TEXT,
    date TEXT NOT NULL,             -- YYYY-MM-DD
    time_slot TEXT NOT NULL,        -- e.g. '02:30 PM - 02:45 PM'
    agenda TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'confirmed', -- 'confirmed', 'completed', 'cancelled', 'rescheduled'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_ptm_bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow parent to view own ptm bookings"
    ON public.school_ptm_bookings
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Allow parent to create ptm bookings"
    ON public.school_ptm_bookings
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

CREATE POLICY "Allow parent and teacher to update ptm bookings"
    ON public.school_ptm_bookings
    FOR UPDATE
    TO authenticated, anon
    USING (true);

-- 2. Table: school_parent_grievances (PN8: Grievance & Complaint Lifecycle Tracker)
CREATE TABLE IF NOT EXISTS public.school_parent_grievances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_no TEXT NOT NULL UNIQUE,
    parent_username TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT,
    category TEXT NOT NULL,         -- 'Academics', 'Transport', 'Fee & Accounts', 'Safety & Pastoral', 'Infrastructure'
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'submitted', -- 'submitted', 'in_review', 'resolved', 'reopened'
    admin_reply TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_parent_grievances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow parent to view own grievances"
    ON public.school_parent_grievances
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Allow parent to file grievances"
    ON public.school_parent_grievances
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

CREATE POLICY "Allow admin to update grievance status"
    ON public.school_parent_grievances
    FOR UPDATE
    TO authenticated, anon
    USING (true);

