-- ============================================================================
-- SCHOOL ERP: STUDENT SUITE SETUP DDL & RLS POLICIES (STU4 & STU5)
-- Tables: school_quizzes, school_quiz_attempts, school_student_goals,
--         school_student_queries
-- ============================================================================

-- 1. Table: school_quizzes (N4: Online Assessment Quizzes)
CREATE TABLE IF NOT EXISTS public.school_quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id TEXT NOT NULL,
    class_name TEXT,
    subject TEXT NOT NULL,
    title TEXT NOT NULL,
    duration_minutes INT DEFAULT 15,
    total_questions INT DEFAULT 3,
    weightage_percent INT DEFAULT 10,
    questions JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_quizzes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read on school_quizzes"
    ON public.school_quizzes
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Allow teachers and admins write on school_quizzes"
    ON public.school_quizzes
    FOR ALL
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);

-- 2. Table: school_quiz_attempts (N4: Student Quiz Submissions & Scorecard)
CREATE TABLE IF NOT EXISTS public.school_quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id UUID REFERENCES public.school_quizzes(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,              -- username (e.g. 'sstudent1')
    student_name TEXT,
    score NUMERIC(5,2) NOT NULL DEFAULT 0.0,
    total NUMERIC(5,2) NOT NULL DEFAULT 10.0,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS (CASE WHEN total > 0 THEN (score / total) * 100 ELSE 0 END) STORED,
    answers JSONB DEFAULT '{}'::jsonb,
    attempted_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_quiz_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow students to view their own quiz attempts"
    ON public.school_quiz_attempts
    FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Allow students to insert their quiz attempts"
    ON public.school_quiz_attempts
    FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- 3. Table: school_student_goals (N6: Subject Target Goal Setting)
CREATE TABLE IF NOT EXISTS public.school_student_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,              -- student username
    subject TEXT NOT NULL,
    target_percent NUMERIC(5,2) NOT NULL DEFAULT 85.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.school_student_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow students to manage their own goals"
    ON public.school_student_goals
    FOR ALL
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);

-- 4. Table: school_student_queries (N14: Ask Teacher Doubts & In-App Replies)
CREATE TABLE IF NOT EXISTS public.school_student_queries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,              -- student username
    student_name TEXT,
    teacher_id TEXT,                       -- teacher username
    teacher_name TEXT,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    reply TEXT,
    status TEXT DEFAULT 'pending',         -- 'pending', 'replied', 'closed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    replied_at TIMESTAMPTZ
);

ALTER TABLE public.school_student_queries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow students to view and create queries"
    ON public.school_student_queries
    FOR ALL
    TO authenticated, anon
    USING (true)
    WITH CHECK (true);
