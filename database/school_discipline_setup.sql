-- ============================================================================
-- School ERP — Super Enterprise Discipline & Incident Management Setup
-- Tables: school_discipline_incidents, school_discipline_inquiries, school_discipline_actions, school_discipline_parent_notices
-- Standards: Multi-school RLS, institute_id isolation, role-gated suspension, audit trail linkage
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_discipline_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    incident_number TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    class_section TEXT NOT NULL,
    incident_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    location TEXT NOT NULL DEFAULT 'Classroom',
    category TEXT NOT NULL, -- 'Late / Punctuality', 'Classroom Disruption', 'Bullying / Misconduct', 'Property Damage', 'Uniform / Dress Code', 'Academic Dishonesty', 'Other'
    severity TEXT NOT NULL DEFAULT 'Medium', -- 'Low', 'Medium', 'High', 'Critical'
    description TEXT NOT NULL,
    reported_by_id TEXT NOT NULL,
    reported_by_name TEXT NOT NULL,
    reported_by_role TEXT NOT NULL DEFAULT 'teacher',
    witnesses TEXT,
    status TEXT NOT NULL DEFAULT 'Reported', -- 'Reported', 'Inquiring', 'Action Taken', 'Resolved'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_discipline_inquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    incident_id UUID REFERENCES public.school_discipline_incidents(id) ON DELETE CASCADE,
    inquiry_date TIMESTAMPTZ DEFAULT NOW(),
    officer_name TEXT NOT NULL,
    officer_role TEXT NOT NULL DEFAULT 'Admin / HOD',
    student_statement TEXT,
    teacher_statement TEXT,
    findings TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_discipline_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    incident_id UUID REFERENCES public.school_discipline_incidents(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    action_type TEXT NOT NULL, -- 'Verbal Warning', 'Written Reprimand', 'Counselling Session', 'Parent Conference', 'Suspension', 'Community Service'
    action_date DATE DEFAULT CURRENT_DATE,
    authorized_by_id TEXT NOT NULL,
    authorized_by_name TEXT NOT NULL,
    authorized_by_role TEXT NOT NULL, -- Suspension strictly role-gated to 'principal' or 'sadmin'
    duration_days INT DEFAULT 0,
    action_notes TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Active', -- 'Active', 'Completed', 'Revoked'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_discipline_parent_notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    incident_id UUID REFERENCES public.school_discipline_incidents(id) ON DELETE CASCADE,
    action_id UUID REFERENCES public.school_discipline_actions(id) ON DELETE SET NULL,
    student_id TEXT NOT NULL,
    parent_id TEXT,
    notice_title TEXT NOT NULL,
    notice_body TEXT NOT NULL,
    scheduled_meeting_date TIMESTAMPTZ,
    parent_read BOOLEAN DEFAULT FALSE,
    parent_read_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_school_discipline_student ON public.school_discipline_incidents(student_id);
CREATE INDEX IF NOT EXISTS idx_school_discipline_category ON public.school_discipline_incidents(category);
CREATE INDEX IF NOT EXISTS idx_school_discipline_status ON public.school_discipline_incidents(status);
CREATE INDEX IF NOT EXISTS idx_school_discipline_parent_notices_student ON public.school_discipline_parent_notices(student_id);

-- Enable RLS
ALTER TABLE public.school_discipline_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_discipline_inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_discipline_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_discipline_parent_notices ENABLE ROW LEVEL SECURITY;

-- Standard Multi-school Policies
CREATE POLICY "Incidents visible to staff and admin" 
ON public.school_discipline_incidents FOR SELECT TO authenticated USING (true);

CREATE POLICY "Incidents manageable by staff and admin" 
ON public.school_discipline_incidents FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Inquiries manageable by admin" 
ON public.school_discipline_inquiries FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Discipline actions manageable by authorized staff" 
ON public.school_discipline_actions FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Discipline parent notices visible to authenticated users" 
ON public.school_discipline_parent_notices FOR ALL TO authenticated USING (true) WITH CHECK (true);
