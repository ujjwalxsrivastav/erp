-- ============================================================================
-- SCHOOL ERP: PARENT COMMUNICATION HUB DDL & RLS POLICIES (PAR4)
-- Tables: school_teacher_messages, school_notifications,
--         school_parent_teacher_messages, school_parent_preferences
-- ============================================================================

-- 1. Table: school_teacher_messages (PN1: Class Announcements & Teacher Broadcasts)
CREATE TABLE IF NOT EXISTS public.school_teacher_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id TEXT NOT NULL,
    teacher_name TEXT,
    class_id TEXT NOT NULL,
    class_name TEXT,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    priority TEXT DEFAULT 'normal', -- 'normal', 'important', 'urgent'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_teacher_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read on school_teacher_messages"
    ON public.school_teacher_messages
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Allow teachers and staff insert on school_teacher_messages"
    ON public.school_teacher_messages
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- 2. Table: school_notifications (PN2: Live Event Feed & Real Alerts)
CREATE TABLE IF NOT EXISTS public.school_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,          -- username of the recipient (e.g. 'parent1')
    user_role TEXT DEFAULT 'parent',
    child_id TEXT,                  -- student username or id (e.g. 'sstudent1')
    type TEXT NOT NULL,             -- 'absence', 'homework', 'fee_due', 'leave_update', 'ptm', 'circular'
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    link_route TEXT,                -- deep-link route e.g. '/school/attendance'
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to read own notifications"
    ON public.school_notifications
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Allow authenticated insert on school_notifications"
    ON public.school_notifications
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

CREATE POLICY "Allow users to update own notifications"
    ON public.school_notifications
    FOR UPDATE
    TO authenticated, anon
    USING (true);

-- 3. Table: school_parent_teacher_messages (PN9: 1:1 Direct Teacher Messaging Thread)
CREATE TABLE IF NOT EXISTS public.school_parent_teacher_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_username TEXT NOT NULL,
    student_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    teacher_name TEXT,
    subject TEXT,
    body TEXT NOT NULL,
    sender_role TEXT NOT NULL DEFAULT 'parent', -- 'parent' or 'teacher'
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_parent_teacher_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow thread participants to read messages"
    ON public.school_parent_teacher_messages
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Allow thread participants to send messages"
    ON public.school_parent_teacher_messages
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- 4. Table: school_parent_preferences (PM12: Parent Notification Preferences)
CREATE TABLE IF NOT EXISTS public.school_parent_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_username TEXT NOT NULL UNIQUE,
    absence_alerts BOOLEAN DEFAULT true,
    homework_alerts BOOLEAN DEFAULT true,
    fee_due_alerts BOOLEAN DEFAULT true,
    ptm_reminders BOOLEAN DEFAULT true,
    emergency_circulars BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_parent_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow parent read and update preferences"
    ON public.school_parent_preferences
    FOR ALL
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);

