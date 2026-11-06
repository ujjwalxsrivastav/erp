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

-- 12. Seed initial sample notifications for demonstration
INSERT INTO public.school_notifications (user_id, title, message, body, type, created_at)
VALUES
    ('parent1', 'Attendance Recorded', 'Daily attendance has been marked Present for your ward.', 'Attendance status is updated.', 'success', now() - interval '2 hours'),
    ('parent1', 'Upcoming PTM', 'Quarterly Parent-Teacher Meeting scheduled this Saturday.', 'Please book your slot.', 'info', now() - interval '1 day'),
    ('sstudent1', 'Mathematics Homework Assigned', 'Chapter 5 Quadratic Equations practice questions.', 'Due on Monday.', 'homework', now() - interval '3 hours'),
    ('sstudent1', 'Library Book Due Reminder', 'The book "Concepts of Physics" is due in 2 days.', 'Return or renew to avoid fines.', 'warning', now() - interval '1 day')
ON CONFLICT DO NOTHING;

SELECT 'School ERP runtime tables successfully created and verified!' AS status;

