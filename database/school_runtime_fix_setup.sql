-- ============================================================================
-- SCHOOL ERP: RUNTIME TABLES COMPREHENSIVE SETUP SCRIPT
-- Execute this script in your Supabase Project -> SQL Editor
--
-- This script creates the missing runtime tables queried by the School ERP
-- Web App:
--   1. school_student_leaves (leave management)
--   2. school_notifications (real-time alerts and parent/student push feed)
--   3. school_student_goals (academic target and goal tracking)
--   4. school_quizzes & school_quiz_attempts (online assessment engine)
--   5. school_student_queries (doubt clearing / faculty messaging)
-- ============================================================================

-- 1. Table: school_student_leaves
CREATE TABLE IF NOT EXISTS public.school_student_leaves (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id      UUID,
    student_id        TEXT,
    student_username  TEXT NOT NULL,
    student_name      TEXT NOT NULL,
    class_id          TEXT,
    class_name        TEXT,
    section           TEXT,
    class_teacher_id  TEXT,
    leave_type        TEXT NOT NULL DEFAULT 'Casual Leave',
    start_date        DATE NOT NULL,
    end_date          DATE NOT NULL,
    total_days        INTEGER NOT NULL DEFAULT 1 CHECK (total_days > 0),
    reason            TEXT NOT NULL,
    document_url      TEXT,
    status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    applied_by        TEXT,
    applied_by_role   TEXT,
    reviewed_by       TEXT,
    reviewer_name     TEXT,
    review_remarks    TEXT,
    reviewed_at       TIMESTAMPTZ,
    attendance_marked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_student_leaves_student
    ON public.school_student_leaves (student_username);
CREATE INDEX IF NOT EXISTS idx_school_student_leaves_class
    ON public.school_student_leaves (class_id);
CREATE INDEX IF NOT EXISTS idx_school_student_leaves_status
    ON public.school_student_leaves (status);

ALTER TABLE public.school_student_leaves DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_student_leaves TO anon, authenticated, service_role;

-- 2. Table: school_notifications
CREATE TABLE IF NOT EXISTS public.school_notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id UUID,
    user_id     TEXT NOT NULL,
    child_id    TEXT,
    title       TEXT NOT NULL,
    message     TEXT,
    body        TEXT,
    type        TEXT DEFAULT 'info',
    link_route  TEXT,
    is_read     BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_notifications_user
    ON public.school_notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_school_notifications_created
    ON public.school_notifications (created_at DESC);

ALTER TABLE public.school_notifications DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_notifications TO anon, authenticated, service_role;

-- 3. Table: school_student_goals
CREATE TABLE IF NOT EXISTS public.school_student_goals (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id   UUID,
    student_id     TEXT NOT NULL,
    subject        TEXT NOT NULL,
    target_percent NUMERIC(5,2) NOT NULL DEFAULT 85.0,
    target_score   NUMERIC(5,2) DEFAULT 85.0,
    current_score  NUMERIC(5,2) DEFAULT 0.0,
    term           TEXT DEFAULT 'Term 1',
    created_at     TIMESTAMPTZ DEFAULT now(),
    updated_at     TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_student_goals_student
    ON public.school_student_goals (student_id);

ALTER TABLE public.school_student_goals DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_student_goals TO anon, authenticated, service_role;

-- 4. Table: school_quizzes
CREATE TABLE IF NOT EXISTS public.school_quizzes (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id      UUID,
    class_id          TEXT NOT NULL,
    class_name        TEXT,
    subject           TEXT NOT NULL,
    title             TEXT NOT NULL,
    duration_minutes  INT DEFAULT 15,
    total_questions   INT DEFAULT 3,
    weightage_percent INT DEFAULT 10,
    questions         JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_by        TEXT,
    created_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_quizzes DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_quizzes TO anon, authenticated, service_role;

-- 5. Table: school_quiz_attempts
CREATE TABLE IF NOT EXISTS public.school_quiz_attempts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id UUID,
    quiz_id      UUID REFERENCES public.school_quizzes(id) ON DELETE CASCADE,
    student_id   TEXT NOT NULL,
    student_name TEXT,
    score        NUMERIC(5,2) NOT NULL DEFAULT 0.0,
    total        NUMERIC(5,2) NOT NULL DEFAULT 10.0,
    percentage   NUMERIC(5,2) GENERATED ALWAYS AS (CASE WHEN total > 0 THEN (score / total) * 100 ELSE 0 END) STORED,
    answers      JSONB DEFAULT '{}'::jsonb,
    attempted_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_quiz_attempts DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_quiz_attempts TO anon, authenticated, service_role;

-- 6. Table: school_student_queries
CREATE TABLE IF NOT EXISTS public.school_student_queries (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id UUID,
    student_id   TEXT NOT NULL,
    student_name TEXT,
    teacher_id   TEXT,
    teacher_name TEXT,
    subject      TEXT NOT NULL,
    message      TEXT NOT NULL,
    reply        TEXT,
    status       TEXT DEFAULT 'pending',
    created_at   TIMESTAMPTZ DEFAULT now(),
    replied_at   TIMESTAMPTZ
);

ALTER TABLE public.school_student_queries DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_student_queries TO anon, authenticated, service_role;

-- 7. Table: school_teacher_messages
CREATE TABLE IF NOT EXISTS public.school_teacher_messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id UUID,
    teacher_id   TEXT NOT NULL,
    teacher_name TEXT,
    class_id     TEXT NOT NULL,
    class_name   TEXT,
    subject      TEXT NOT NULL,
    body         TEXT NOT NULL,
    priority     TEXT DEFAULT 'normal',
    created_at   TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_teacher_messages DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_teacher_messages TO anon, authenticated, service_role;

-- 8. Table: school_parent_teacher_messages
CREATE TABLE IF NOT EXISTS public.school_parent_teacher_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id    UUID,
    parent_username TEXT NOT NULL,
    teacher_id      TEXT NOT NULL,
    teacher_name    TEXT,
    subject         TEXT NOT NULL,
    body            TEXT NOT NULL,
    is_read         BOOLEAN DEFAULT false,
    created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_parent_teacher_messages DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_parent_teacher_messages TO anon, authenticated, service_role;

-- 9. Table: school_parent_preferences
CREATE TABLE IF NOT EXISTS public.school_parent_preferences (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_username TEXT NOT NULL UNIQUE,
    sms_alerts      BOOLEAN DEFAULT true,
    email_digest    BOOLEAN DEFAULT true,
    push_updates    BOOLEAN DEFAULT true,
    language        TEXT DEFAULT 'en',
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_parent_preferences DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_parent_preferences TO anon, authenticated, service_role;

-- 10. Table: school_ptm_bookings
CREATE TABLE IF NOT EXISTS public.school_ptm_bookings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id    UUID,
    parent_username TEXT NOT NULL,
    student_id      TEXT NOT NULL,
    student_name    TEXT,
    teacher_id      TEXT NOT NULL,
    teacher_name    TEXT,
    date            TEXT NOT NULL,
    time_slot       TEXT NOT NULL,
    agenda          TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'confirmed',
    created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_ptm_bookings DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_ptm_bookings TO anon, authenticated, service_role;

-- 11. Table: school_parent_grievances
CREATE TABLE IF NOT EXISTS public.school_parent_grievances (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id    UUID,
    ticket_no       TEXT NOT NULL UNIQUE,
    parent_username TEXT NOT NULL,
    student_id      TEXT NOT NULL,
    student_name    TEXT,
    category        TEXT NOT NULL,
    subject         TEXT NOT NULL,
    description     TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'submitted',
    admin_reply     TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_parent_grievances DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_parent_grievances TO anon, authenticated, service_role;

-- 12. Table: school_academic_calendar (Enterprise Academic Calendar & Milestones)
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

ALTER TABLE public.school_academic_calendar DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.school_academic_calendar TO anon, authenticated, service_role;

-- 13. Seed initial sample notifications for demonstration
INSERT INTO public.school_notifications (user_id, title, message, body, type, created_at)
VALUES
    ('parent1', 'Attendance Recorded', 'Daily attendance has been marked Present for your ward.', 'Attendance status is updated.', 'success', now() - interval '2 hours'),
    ('parent1', 'Upcoming PTM', 'Quarterly Parent-Teacher Meeting scheduled this Saturday.', 'Please book your slot.', 'info', now() - interval '1 day'),
    ('sstudent1', 'Mathematics Homework Assigned', 'Chapter 5 Quadratic Equations practice questions.', 'Due on Monday.', 'homework', now() - interval '3 hours'),
    ('sstudent1', 'Library Book Due Reminder', 'The book "Concepts of Physics" is due in 2 days.', 'Return or renew to avoid fines.', 'warning', now() - interval '1 day')
ON CONFLICT DO NOTHING;

-- 14. Seed authentic academic calendar milestones for 2026-27 session
INSERT INTO public.school_academic_calendar 
(academic_year, term, title, description, category, start_date, end_date, start_time, end_time, is_all_day, is_holiday, target_audience, applicable_classes, venue, color_code, created_by)
VALUES
    ('2026-2027', 'Term 1', 'Academic Session 2026-27 Commences', 'Orientation assembly and commencement of regular classroom instructions.', 'Academic', '2026-04-01', '2026-04-01', '08:00 AM', '02:00 PM', true, false, 'all', ARRAY['All']::TEXT[], 'Main Campus', '#10B981', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Dr. B.R. Ambedkar Jayanti', 'Gazetted Holiday on account of Ambedkar Jayanti.', 'Holiday', '2026-04-14', '2026-04-14', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#EF4444', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Periodic Assessment / Unit Test 1', 'Formal assessment cycle for Term 1 core curriculum subjects.', 'Examination', '2026-05-11', '2026-05-16', '08:30 AM', '11:30 AM', false, false, 'students', ARRAY['Class 6-A', 'Class 7-A', 'Class 8-A', 'Class 9-A', 'Class 10-A']::TEXT[], 'Examination Halls A & B', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Summer Vacation', 'Annual summer vacation for junior and middle schools.', 'Holiday', '2026-05-25', '2026-06-30', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#F59E0B', 'sadmin1'),
    ('2026-2027', 'Term 1', 'School Reopens Post Summer Break', 'Resumption of academic schedule and club activities.', 'Academic', '2026-07-01', '2026-07-01', '08:00 AM', '02:00 PM', true, false, 'all', ARRAY['All']::TEXT[], 'Main Campus', '#10B981', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Term 1 Parent-Teacher Meeting (PTM 1)', 'Review of Unit Test 1 academic progress and attendance counseling.', 'PTM', '2026-07-18', '2026-07-18', '08:30 AM', '01:00 PM', false, false, 'parents', ARRAY['All']::TEXT[], 'Respective Classrooms', '#EC4899', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Independence Day Celebrations', 'Patriotic flag hoisting, march past, and Student Council badge investiture.', 'Co-Curricular', '2026-08-15', '2026-08-15', '08:00 AM', '11:00 AM', false, false, 'all', ARRAY['All']::TEXT[], 'School Ground', '#3B82F6', 'sadmin1'),
    ('2026-2027', 'Term 1', 'Half Yearly / Mid-Term Examinations', 'Comprehensive Term 1 examinations across all scholastic subjects.', 'Examination', '2026-09-14', '2026-09-26', '08:30 AM', '12:00 PM', false, false, 'students', ARRAY['All']::TEXT[], 'Designated Examination Blocks', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Mahatma Gandhi Jayanti', 'National holiday on account of Gandhi Jayanti.', 'Holiday', '2026-10-02', '2026-10-02', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#EF4444', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Mid-Term Report Card & PTM (PTM 2)', 'Distribution of Term 1 Holistic Progress Cards and faculty consultations.', 'PTM', '2026-10-10', '2026-10-10', '08:30 AM', '01:30 PM', false, false, 'parents', ARRAY['All']::TEXT[], 'School Campus', '#EC4899', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Autumn / Dussehra Break', 'Dussehra and autumn festival vacation.', 'Holiday', '2026-10-19', '2026-10-23', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#F59E0B', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Childrens Day & Annual Sports Meet', 'Inter-house athletic meet, track & field finals, and cultural presentations.', 'Co-Curricular', '2026-11-14', '2026-11-15', '08:00 AM', '04:00 PM', false, false, 'all', ARRAY['All']::TEXT[], 'Sports Complex', '#3B82F6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Winter Break', 'Scheduled winter vacation for students and staff.', 'Holiday', '2026-12-25', '2027-01-05', NULL, NULL, true, true, 'all', ARRAY['All']::TEXT[], 'Campus Closed', '#F59E0B', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Class 10 & 12 Pre-Board Examinations', 'Full-syllabus mock board exams adhering to CBSE blueprints.', 'Examination', '2027-01-15', '2027-01-28', '09:00 AM', '12:30 PM', false, false, 'students', ARRAY['Class 10-A', 'Class 10-B', 'Class 12-A']::TEXT[], 'Senior Examination Hall', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Republic Day Celebrations', 'Ceremonial parade and cultural performances.', 'Co-Curricular', '2027-01-26', '2027-01-26', '08:00 AM', '11:00 AM', false, false, 'all', ARRAY['All']::TEXT[], 'Campus Grounds', '#3B82F6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Annual Final Examinations 2026-27', 'Final academic examinations for promotion to subsequent class cohorts.', 'Examination', '2027-02-15', '2027-03-10', '08:30 AM', '12:00 PM', false, false, 'students', ARRAY['All']::TEXT[], 'Designated Examination Blocks', '#8B5CF6', 'sadmin1'),
    ('2026-2027', 'Term 2', 'Annual PTM & Final Result Declaration', 'Declaration of annual promotion results and distribution of CBSE HPC report cards.', 'PTM', '2027-03-20', '2027-03-20', '08:30 AM', '02:00 PM', false, false, 'parents', ARRAY['All']::TEXT[], 'Classrooms', '#EC4899', 'sadmin1')
ON CONFLICT DO NOTHING;

-- 15. Student wallet balance column fix
ALTER TABLE IF EXISTS public.school_students ADD COLUMN IF NOT EXISTS wallet_balance NUMERIC(10,2) DEFAULT 0.00;

-- 16. School AI Architecture (SP11: Remarks, Question Papers, Feedback, Usage Log)
CREATE TABLE IF NOT EXISTS public.school_ai_remarks (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    student_username TEXT NOT NULL,
    student_name TEXT NOT NULL,
    exam_id TEXT NOT NULL,
    class_id TEXT NOT NULL,
    draft_remark TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft_pending_approval' CHECK (status IN ('draft_pending_approval', 'approved', 'rejected', 'edited')),
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    teacher_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_ai_question_papers (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    title TEXT NOT NULL,
    class_id TEXT NOT NULL,
    subject TEXT NOT NULL,
    total_marks INTEGER NOT NULL DEFAULT 50,
    difficulty_mix JSONB DEFAULT '{"easy": 40, "medium": 40, "hard": 20}'::jsonb,
    sections JSONB DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'draft_pending_approval' CHECK (status IN ('draft_pending_approval', 'approved', 'archived')),
    created_by TEXT NOT NULL,
    approved_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_ai_feedback (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    assignment_id TEXT NOT NULL,
    student_username TEXT NOT NULL,
    student_name TEXT NOT NULL,
    draft_feedback TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft_pending_approval' CHECK (status IN ('draft_pending_approval', 'approved', 'edited')),
    created_by TEXT NOT NULL,
    approved_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_ai_usage_log (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    user_username TEXT NOT NULL,
    user_role TEXT NOT NULL,
    feature TEXT NOT NULL CHECK (feature IN ('remarks', 'question_paper', 'feedback', 'rag_chat')),
    prompt_snippet TEXT,
    tokens_used INTEGER DEFAULT 0,
    model_used TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_ai_remarks DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_ai_question_papers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_ai_feedback DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_ai_usage_log DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.school_ai_remarks TO anon, authenticated, service_role;
GRANT ALL ON public.school_ai_question_papers TO anon, authenticated, service_role;
GRANT ALL ON public.school_ai_feedback TO anon, authenticated, service_role;
GRANT ALL ON public.school_ai_usage_log TO anon, authenticated, service_role;

SELECT 'School ERP runtime tables successfully created and verified!' AS status;

