-- ============================================================================
-- SCHOOL AI SYSTEM, QUESTION GENERATOR & CHATBOT RAG (SP11)
-- ============================================================================

-- 1. AI REPORT CARD REMARKS
CREATE TABLE IF NOT EXISTS school_ai_remarks (
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

-- 2. AI QUESTION PAPERS
CREATE TABLE IF NOT EXISTS school_ai_question_papers (
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

-- 3. AI ASSIGNMENT FEEDBACK
CREATE TABLE IF NOT EXISTS school_ai_feedback (
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

-- 4. AI USAGE & QUOTA AUDIT LOG
CREATE TABLE IF NOT EXISTS school_ai_usage_log (
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

-- RLS POLICIES
ALTER TABLE school_ai_remarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_ai_question_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_ai_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_ai_usage_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Multi-school isolation ai_remarks" ON school_ai_remarks
    FOR ALL USING (institute_id = CURRENT_SETTING('app.current_institute_id', true) OR CURRENT_SETTING('app.current_institute_id', true) IS NULL);

CREATE POLICY "Multi-school isolation ai_papers" ON school_ai_question_papers
    FOR ALL USING (institute_id = CURRENT_SETTING('app.current_institute_id', true) OR CURRENT_SETTING('app.current_institute_id', true) IS NULL);

CREATE POLICY "Multi-school isolation ai_feedback" ON school_ai_feedback
    FOR ALL USING (institute_id = CURRENT_SETTING('app.current_institute_id', true) OR CURRENT_SETTING('app.current_institute_id', true) IS NULL);

CREATE POLICY "Multi-school isolation ai_usage" ON school_ai_usage_log
    FOR ALL USING (institute_id = CURRENT_SETTING('app.current_institute_id', true) OR CURRENT_SETTING('app.current_institute_id', true) IS NULL);
