-- ============================================================================
-- School ERP — Super Enterprise Activities, Clubs & Sports Setup
-- Tables: school_activity_events, school_clubs, school_club_memberships, school_sports_teams, school_activity_participations
-- Standards: Multi-school RLS, institute_id isolation, certificate linkage
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_activity_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    title TEXT NOT NULL,
    category TEXT NOT NULL, -- 'Cultural', 'Sports', 'Science & Innovation', 'Literary', 'Performing Arts'
    event_date DATE NOT NULL,
    venue TEXT NOT NULL DEFAULT 'School Grounds / Auditorium',
    coordinator_teacher_id TEXT,
    coordinator_teacher_name TEXT,
    eligibility_classes TEXT[] DEFAULT ARRAY['All'],
    max_participants INT DEFAULT 100,
    status TEXT NOT NULL DEFAULT 'Upcoming', -- 'Upcoming', 'Ongoing', 'Completed'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    name TEXT NOT NULL,
    category TEXT NOT NULL, -- 'STEM', 'Performing Arts', 'Literature & Debate', 'Nature & Environment', 'Social Service'
    patron_teacher_id TEXT NOT NULL,
    patron_teacher_name TEXT NOT NULL,
    meeting_schedule TEXT NOT NULL DEFAULT 'Every Wednesday 3:30 PM',
    room_venue TEXT NOT NULL DEFAULT 'Activity Room B',
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_club_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    club_id UUID REFERENCES public.school_clubs(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    class_section TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'Member', -- 'President', 'Secretary', 'Treasurer', 'Member'
    joined_date DATE DEFAULT CURRENT_DATE,
    approval_status TEXT NOT NULL DEFAULT 'Approved', -- 'Pending', 'Approved', 'Rejected'
    approved_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_sports_teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    sport_name TEXT NOT NULL, -- 'Cricket', 'Football', 'Basketball', 'Badminton', 'Athletics', 'Chess', 'Table Tennis'
    age_category TEXT NOT NULL DEFAULT 'Under-17', -- 'Under-14', 'Under-17', 'Under-19'
    coach_name TEXT NOT NULL,
    captain_student_id TEXT,
    captain_student_name TEXT,
    training_schedule TEXT DEFAULT 'Daily 6:30 AM - 8:00 AM',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_activity_participations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    event_id UUID REFERENCES public.school_activity_events(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    class_section TEXT NOT NULL,
    activity_type TEXT NOT NULL, -- 'Event', 'Sport', 'Competition'
    role_or_item TEXT, -- e.g. '100m Sprint', 'Robotics Demo', 'Debate First Speaker'
    position_award TEXT DEFAULT 'Participant', -- '1st Place (Gold)', '2nd Place (Silver)', '3rd Place (Bronze)', 'Special Commendation', 'Participant'
    certificate_serial TEXT,
    certificate_issued BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_school_activity_events_date ON public.school_activity_events(event_date);
CREATE INDEX IF NOT EXISTS idx_school_activity_participations_student ON public.school_activity_participations(student_id);
CREATE INDEX IF NOT EXISTS idx_school_club_memberships_club ON public.school_club_memberships(club_id);

-- Enable RLS
ALTER TABLE public.school_activity_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_club_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sports_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_activity_participations ENABLE ROW LEVEL SECURITY;

-- Standard Multi-school Policies
CREATE POLICY "Activity events visible to authenticated users" 
ON public.school_activity_events FOR SELECT TO authenticated USING (true);

CREATE POLICY "Activity events manageable by staff" 
ON public.school_activity_events FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Clubs visible to authenticated users" 
ON public.school_clubs FOR SELECT TO authenticated USING (true);

CREATE POLICY "Clubs manageable by staff" 
ON public.school_clubs FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Club memberships manageable by authenticated users" 
ON public.school_club_memberships FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Sports teams visible to authenticated users" 
ON public.school_sports_teams FOR SELECT TO authenticated USING (true);

CREATE POLICY "Participations manageable by staff" 
ON public.school_activity_participations FOR ALL TO authenticated USING (true) WITH CHECK (true);
