-- ============================================================================
-- SCHOOL ERP: ENTERPRISE ACADEMIC CALENDAR & MILESTONES (SETUP DDL)
-- Execute this script in your Supabase Project -> SQL Editor
--
-- Features:
--   - Term-wise academic milestones and scheduling
--   - Examinations, statutory holidays, PTMs, co-curricular & sports
--   - Role & class-specific targeting (All, Students, Teachers, Parents)
--   - Multi-tenant institute_id isolation support
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_academic_calendar (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id       UUID,
    academic_year      TEXT NOT NULL DEFAULT '2026-2027',
    term               TEXT NOT NULL DEFAULT 'Term 1' CHECK (term IN ('Term 1', 'Term 2', 'Annual')),
    title              TEXT NOT NULL,
    description        TEXT,
    category           TEXT NOT NULL DEFAULT 'Academic' 
                       CHECK (category IN ('Academic', 'Examination', 'Holiday', 'PTM', 'Co-Curricular', 'Administrative')),
    start_date         DATE NOT NULL,
    end_date           DATE NOT NULL,
    start_time         TEXT,
    end_time           TEXT,
    is_all_day         BOOLEAN NOT NULL DEFAULT true,
    is_holiday         BOOLEAN NOT NULL DEFAULT false,
    target_audience    TEXT NOT NULL DEFAULT 'all' CHECK (target_audience IN ('all', 'students', 'teachers', 'parents')),
    applicable_classes TEXT[] DEFAULT ARRAY['All']::TEXT[],
    venue              TEXT DEFAULT 'Main Campus',
    color_code         TEXT DEFAULT '#3B82F6',
    is_published       BOOLEAN NOT NULL DEFAULT true,
    created_by         TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_academic_calendar_year_date
    ON public.school_academic_calendar (academic_year, start_date);

CREATE INDEX IF NOT EXISTS idx_school_academic_calendar_category
    ON public.school_academic_calendar (category);

CREATE INDEX IF NOT EXISTS idx_school_academic_calendar_audience
    ON public.school_academic_calendar (target_audience);

ALTER TABLE public.school_academic_calendar DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_academic_calendar TO anon, authenticated, service_role;

-- Seed authentic CBSE / Indian School Academic Calendar for Session 2026-2027
INSERT INTO public.school_academic_calendar 
(academic_year, term, title, description, category, start_date, end_date, start_time, end_time, is_all_day, is_holiday, target_audience, applicable_classes, venue, color_code, created_by)
VALUES
    ('2026-2027', 'Term 1', 'Academic Session 2026-27 Commences', 'Orientation assembly and commencement of regular classroom instructions.', 'Academic', '2026-04-01', '2026-04-01', '08:00 AM', '02:00 PM', true, false, 'all', ARRAY['All']::TEXT[], 'Main Campus', '#10B981', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Dr. B.R. Ambedkar Jayanti', 'Gazetted Holiday on account of Ambedkar Jayanti.', 'Holiday', '2026-04-14', '2026-04-14', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#EF4444', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Periodic Assessment / Unit Test 1', 'Formal assessment cycle for Term 1 core curriculum subjects.', 'Examination', '2026-05-11', '2026-05-16', '08:30 AM', '11:30 AM', false, false, 'students', ARRAY['Class 6-A', 'Class 7-A', 'Class 8-A', 'Class 9-A', 'Class 10-A']::TEXT[], 'Examination Halls A & B', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Summer Vacation (Students & Staff)', 'Annual summer vacation for junior and middle schools. Remedial tutorials for board batches.', 'Holiday', '2026-05-25', '2026-06-30', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#F59E0B', 'sadmin1'),
    ('2026-2027', 'Term 1', 'School Reopens Post Summer Break', 'Resumption of academic schedule and club activities.', 'Academic', '2026-07-01', '2026-07-01', '08:00 AM', '02:00 PM', true, false, 'all', ARRAY['All']::TEXT[], 'Main Campus', '#10B981', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Term 1 Parent-Teacher Meeting (PTM 1)', 'Review of Unit Test 1 academic progress and attendance counseling.', 'PTM', '2026-07-18', '2026-07-18', '08:30 AM', '01:00 PM', false, false, 'parents', ARRAY['All']::TEXT[], 'Respective Classrooms', '#EC4899', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Independence Day Celebrations & Investiture', 'Patriotic flag hoisting, march past, and Student Council badge investiture.', 'Co-Curricular', '2026-08-15', '2026-08-15', '08:00 AM', '11:00 AM', false, false, 'all', ARRAY['All']::TEXT[], 'School Ground & Auditorium', '#3B82F6', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Teachers Day & Faculty Recognition', 'Special assembly honoring faculty, followed by teacher-leadership workshop.', 'Co-Curricular', '2026-09-05', '2026-09-05', '09:00 AM', '01:30 PM', false, false, 'all', ARRAY['All']::TEXT[], 'Auditorium', '#06B6D4', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Half Yearly / Mid-Term Examinations', 'Comprehensive Term 1 examinations across all scholastic subjects.', 'Examination', '2026-09-14', '2026-09-26', '08:30 AM', '12:00 PM', false, false, 'students', ARRAY['All']::TEXT[], 'Designated Examination Blocks', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Mahatma Gandhi Jayanti', 'National holiday on account of Gandhi Jayanti.', 'Holiday', '2026-10-02', '2026-10-02', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#EF4444', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Mid-Term Report Card & PTM (PTM 2)', 'Distribution of Term 1 Holistic Progress Cards and faculty-parent consultations.', 'PTM', '2026-10-10', '2026-10-10', '08:30 AM', '01:30 PM', false, false, 'parents', ARRAY['All']::TEXT[], 'School Campus', '#EC4899', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Autumn / Dussehra Break', 'Dussehra and autumn festival vacation.', 'Holiday', '2026-10-19', '2026-10-23', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#F59E0B', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Deepawali & Chhath Festival Break', 'Festival of lights break for students and staff.', 'Holiday', '2026-11-08', '2026-11-12', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#F59E0B', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Childrens Day & Annual Sports Meet', 'Inter-house athletic meet, track & field finals, and cultural stalls.', 'Co-Curricular', '2026-11-14', '2026-11-15', '08:00 AM', '04:00 PM', false, false, 'all', ARRAY['All']::TEXT[], 'Main Sports Complex', '#3B82F6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Periodic Assessment / Unit Test 2', 'Formative evaluation for Term 2 syllabus topics.', 'Examination', '2026-12-07', '2026-12-12', '08:30 AM', '11:30 AM', false, false, 'students', ARRAY['All']::TEXT[], 'Examination Halls', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Winter Break', 'Scheduled winter vacation. Campus maintenance and teacher lesson-plan preparation.', 'Holiday', '2026-12-25', '2027-01-05', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#F59E0B', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Class 10 & 12 Pre-Board Examinations', 'Full-syllabus mock board exams adhering to CBSE official blueprints and marking schemes.', 'Examination', '2027-01-15', '2027-01-28', '09:00 AM', '12:30 PM', false, false, 'students', ARRAY['Class 10-A', 'Class 10-B', 'Class 12-A']::TEXT[], 'Senior Examination Hall', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Republic Day Celebrations', 'Ceremonial parade, cultural presentations, and felicitation of student achievers.', 'Co-Curricular', '2027-01-26', '2027-01-26', '08:00 AM', '11:00 AM', false, false, 'all', ARRAY['All']::TEXT[], 'Campus Grounds', '#3B82F6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Annual Final Examinations 2026-27', 'Final academic examinations for promotion to subsequent class cohorts.', 'Examination', '2027-02-15', '2027-03-10', '08:30 AM', '12:00 PM', false, false, 'students', ARRAY['All']::TEXT[], 'Designated Examination Blocks', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Annual PTM & Final Result Declaration', 'Declaration of annual promotion results and distribution of CBSE HPC report cards.', 'PTM', '2027-03-20', '2027-03-20', '08:30 AM', '02:00 PM', false, false, 'parents', ARRAY['All']::TEXT[], 'Classrooms & Auditorium', '#EC4899', 'sadmin1'),
    ('2026-2027', 'Term 2', 'New Session Transition & Faculty Planning', 'Faculty curriculum workshop, book distribution, and new session planning.', 'Administrative', '2027-03-25', '2027-03-31', '09:00 AM', '03:00 PM', true, false, 'teachers', ARRAY['All']::TEXT[], 'Academic Blocks', '#10B981', 'sadmin1')
ON CONFLICT DO NOTHING;

SELECT 'School academic calendar table and 2026-27 session successfully initialized!' AS status;

