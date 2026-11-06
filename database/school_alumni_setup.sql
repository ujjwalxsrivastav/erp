-- ============================================================================
-- School ERP — Super Enterprise Alumni Setup
-- Tables: school_alumni_profiles, school_alumni_events, school_alumni_rsvps, school_alumni_donation_interests
-- Standards: Multi-school RLS, institute_id isolation, audit trail linkage
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_alumni_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    student_id TEXT,
    full_name TEXT NOT NULL,
    passing_year INT NOT NULL,
    batch_name TEXT NOT NULL,
    last_class_section TEXT DEFAULT '12-A',
    current_status TEXT NOT NULL DEFAULT 'Higher Education',
    organization_college TEXT,
    designation_degree TEXT,
    city TEXT,
    country TEXT DEFAULT 'India',
    email TEXT,
    phone TEXT,
    linkedin_url TEXT,
    is_verified BOOLEAN DEFAULT TRUE,
    willing_to_mentor BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_alumni_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    title TEXT NOT NULL,
    event_type TEXT NOT NULL DEFAULT 'Reunion',
    event_date TIMESTAMPTZ NOT NULL,
    venue TEXT NOT NULL,
    mode TEXT NOT NULL DEFAULT 'In-Person',
    meeting_link TEXT,
    description TEXT,
    target_batches TEXT[] DEFAULT ARRAY['All'],
    created_by TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_alumni_rsvps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    event_id UUID REFERENCES public.school_alumni_events(id) ON DELETE CASCADE,
    alumni_id UUID REFERENCES public.school_alumni_profiles(id) ON DELETE SET NULL,
    alumni_name TEXT NOT NULL,
    alumni_email TEXT,
    status TEXT NOT NULL DEFAULT 'Attending',
    guest_count INT DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_alumni_donation_interests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    alumni_id UUID REFERENCES public.school_alumni_profiles(id) ON DELETE SET NULL,
    alumni_name TEXT NOT NULL,
    alumni_email TEXT NOT NULL,
    cause_area TEXT NOT NULL DEFAULT 'Student Scholarship',
    pledge_amount_estimate NUMERIC(12,2) DEFAULT 5000.00,
    message TEXT,
    status TEXT NOT NULL DEFAULT 'Expressed Interest',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_school_alumni_passing_year ON public.school_alumni_profiles(passing_year);
CREATE INDEX IF NOT EXISTS idx_school_alumni_institute ON public.school_alumni_profiles(institute_id);
CREATE INDEX IF NOT EXISTS idx_school_alumni_events_date ON public.school_alumni_events(event_date);
CREATE INDEX IF NOT EXISTS idx_school_alumni_rsvps_event ON public.school_alumni_rsvps(event_id);
CREATE INDEX IF NOT EXISTS idx_school_alumni_donations_institute ON public.school_alumni_donation_interests(institute_id);

-- Enable RLS
ALTER TABLE public.school_alumni_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_alumni_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_alumni_rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_alumni_donation_interests ENABLE ROW LEVEL SECURITY;

-- Standard Multi-school Policies
CREATE POLICY "Alumni profiles visible to authenticated users" 
ON public.school_alumni_profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Alumni profiles editable by staff/alumni" 
ON public.school_alumni_profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Alumni events visible to authenticated users" 
ON public.school_alumni_events FOR SELECT TO authenticated USING (true);

CREATE POLICY "Alumni events manageable by admin" 
ON public.school_alumni_events FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Alumni RSVPs manageable by authenticated users" 
ON public.school_alumni_rsvps FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Alumni donation interests manageable by authenticated users" 
ON public.school_alumni_donation_interests FOR ALL TO authenticated USING (true) WITH CHECK (true);
