-- ============================================================
-- EXAMINATION (COE) MODULE — Supabase Migration 01
-- ============================================================
-- Run this in the Supabase SQL Editor.
-- Tables: exam_sessions, exam_subjects, exam_registrations,
--         hall_tickets, exam_results, revaluation_requests
-- Idempotent: safe to run more than once.
-- RLS style matches the repo (see sql_migrations/01: permissive
-- "Allow all for authenticated users" policy).

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. EXAM SESSIONS
-- One row per examination cycle (e.g. "End Sem 2026 - Sem 5")
-- ============================================================
CREATE TABLE IF NOT EXISTS exam_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    academic_year TEXT NOT NULL,                       -- e.g. '2026-27'
    exam_type TEXT NOT NULL DEFAULT 'regular'
        CHECK (exam_type IN ('regular', 'backlog', 'supplementary')),
    semester INTEGER,
    start_date DATE,
    end_date DATE,
    form_open_date DATE,
    form_close_date DATE,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'conducted', 'result_declared')),
    created_by TEXT,                                   -- users.username of COE/staff
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE exam_sessions IS 'Examination cycles managed by the COE office';
COMMENT ON COLUMN exam_sessions.status IS 'draft -> published -> conducted -> result_declared';
COMMENT ON COLUMN exam_sessions.exam_type IS 'regular, backlog or supplementary';

CREATE INDEX IF NOT EXISTS idx_exam_sessions_status ON exam_sessions(status);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_semester ON exam_sessions(semester);

-- ============================================================
-- 2. EXAM SUBJECTS
-- Subjects scheduled inside a session, with date-sheet info
-- ============================================================
CREATE TABLE IF NOT EXISTS exam_subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
    subject_id TEXT,                                   -- subjects.subject_id (kept loose so COE can add papers not yet in the master)
    subject_name TEXT NOT NULL,
    exam_date DATE,
    start_time TEXT,                                   -- e.g. '10:00 AM' (stored as text to match timetable display style)
    end_time TEXT,                                     -- e.g. '01:00 PM'
    max_marks NUMERIC(6, 2) NOT NULL DEFAULT 100,
    passing_marks NUMERIC(6, 2) NOT NULL DEFAULT 40,
    room TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE exam_subjects IS 'Date-sheet entries: one subject paper per row inside an exam session';

CREATE INDEX IF NOT EXISTS idx_exam_subjects_session ON exam_subjects(session_id);
CREATE INDEX IF NOT EXISTS idx_exam_subjects_subject ON exam_subjects(subject_id);

-- ============================================================
-- 3. EXAM REGISTRATIONS
-- One row per student per session; chosen papers in subjects (jsonb)
-- subjects jsonb shape: [{"subject_id":"CS501","subject_name":"DBMS"}, ...]
-- ============================================================
CREATE TABLE IF NOT EXISTS exam_registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,                          -- student_details.student_id / users.username
    subjects JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'applied'
        CHECK (status IN ('applied', 'verified', 'hall_ticket_issued')),
    fee_paid BOOLEAN NOT NULL DEFAULT FALSE,
    fee_receipt_id TEXT,                               -- fee_receipts reference (receipt number/id from Finance)
    eligibility_status TEXT NOT NULL DEFAULT 'eligible'
        CHECK (eligibility_status IN ('eligible', 'detained', 'conditional')),
    detention_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (session_id, student_id)
);

COMMENT ON TABLE exam_registrations IS 'Student exam-form registrations for a session; eligibility is gated by dues/detention rules';
COMMENT ON COLUMN exam_registrations.subjects IS 'jsonb array of {subject_id, subject_name} papers the student is appearing for';

CREATE INDEX IF NOT EXISTS idx_exam_registrations_session ON exam_registrations(session_id);
CREATE INDEX IF NOT EXISTS idx_exam_registrations_student ON exam_registrations(student_id);
CREATE INDEX IF NOT EXISTS idx_exam_registrations_status ON exam_registrations(status);

-- ============================================================
-- 4. HALL TICKETS
-- ============================================================
CREATE TABLE IF NOT EXISTS hall_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_id UUID NOT NULL REFERENCES exam_registrations(id) ON DELETE CASCADE,
    ticket_no TEXT NOT NULL UNIQUE,                    -- e.g. HT-2026-0001
    qr_data TEXT,                                      -- payload encoded in the QR (ticket no + student + session)
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (registration_id)
);

COMMENT ON TABLE hall_tickets IS 'Issued admit cards for verified exam registrations';

CREATE INDEX IF NOT EXISTS idx_hall_tickets_ticket_no ON hall_tickets(ticket_no);

-- ============================================================
-- 5. EXAM RESULTS
-- One row per student per subject per session (published gate)
-- ============================================================
CREATE TABLE IF NOT EXISTS exam_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    subject_id TEXT,
    subject_name TEXT,
    internal_marks NUMERIC(6, 2) NOT NULL DEFAULT 0,
    external_marks NUMERIC(6, 2) NOT NULL DEFAULT 0,
    total NUMERIC(6, 2) NOT NULL DEFAULT 0,
    grade TEXT,                                        -- O, A+, A, B+, B, C, F
    grade_point NUMERIC(4, 2) NOT NULL DEFAULT 0,
    credits NUMERIC(4, 2) NOT NULL DEFAULT 3,
    status TEXT NOT NULL DEFAULT 'pass'
        CHECK (status IN ('pass', 'fail', 'backlog')),
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (session_id, student_id, subject_id)
);

COMMENT ON TABLE exam_results IS 'Tabulated results; students see a row only when is_published = true';
COMMENT ON COLUMN exam_results.grade IS '10-point scale: O=10, A+=9, A=8, B+=7, B=6, C=5, F=0';

CREATE INDEX IF NOT EXISTS idx_exam_results_session ON exam_results(session_id);
CREATE INDEX IF NOT EXISTS idx_exam_results_student ON exam_results(student_id);
CREATE INDEX IF NOT EXISTS idx_exam_results_published ON exam_results(is_published);

-- ============================================================
-- 6. REVALUATION REQUESTS
-- ============================================================
CREATE TABLE IF NOT EXISTS revaluation_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    result_id UUID REFERENCES exam_results(id) ON DELETE SET NULL,
    student_id TEXT NOT NULL,
    subject_id TEXT,
    subject_name TEXT,
    original_marks NUMERIC(6, 2),
    revised_marks NUMERIC(6, 2),
    fee_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'under_review', 'completed', 'rejected')),
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_by TEXT,                                 -- users.username of COE/staff who processed it
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE revaluation_requests IS 'Student re-checking / revaluation applications against published results';

CREATE INDEX IF NOT EXISTS idx_revaluation_student ON revaluation_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_revaluation_status ON revaluation_requests(status);
CREATE INDEX IF NOT EXISTS idx_revaluation_result ON revaluation_requests(result_id);

-- ============================================================
-- ENABLE ROW LEVEL SECURITY (repo style: permissive policy)
-- ============================================================
ALTER TABLE exam_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE hall_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE revaluation_requests ENABLE ROW LEVEL SECURITY;

-- Policies are not idempotent in Postgres, so drop-then-create.
DROP POLICY IF EXISTS "Allow all for authenticated users" ON exam_sessions;
CREATE POLICY "Allow all for authenticated users" ON exam_sessions
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated users" ON exam_subjects;
CREATE POLICY "Allow all for authenticated users" ON exam_subjects
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated users" ON exam_registrations;
CREATE POLICY "Allow all for authenticated users" ON exam_registrations
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated users" ON hall_tickets;
CREATE POLICY "Allow all for authenticated users" ON hall_tickets
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated users" ON exam_results;
CREATE POLICY "Allow all for authenticated users" ON exam_results
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated users" ON revaluation_requests;
CREATE POLICY "Allow all for authenticated users" ON revaluation_requests
    FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- UPDATED_AT TRIGGERS (same pattern as student_marks migration)
-- ============================================================
CREATE OR REPLACE FUNCTION update_examination_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_exam_sessions_updated_at ON exam_sessions;
CREATE TRIGGER trigger_exam_sessions_updated_at
    BEFORE UPDATE ON exam_sessions
    FOR EACH ROW EXECUTE FUNCTION update_examination_updated_at();

DROP TRIGGER IF EXISTS trigger_exam_registrations_updated_at ON exam_registrations;
CREATE TRIGGER trigger_exam_registrations_updated_at
    BEFORE UPDATE ON exam_registrations
    FOR EACH ROW EXECUTE FUNCTION update_examination_updated_at();

DROP TRIGGER IF EXISTS trigger_exam_results_updated_at ON exam_results;
CREATE TRIGGER trigger_exam_results_updated_at
    BEFORE UPDATE ON exam_results
    FOR EACH ROW EXECUTE FUNCTION update_examination_updated_at();

-- ============================================================
-- DONE. Examination module tables are ready.
-- ============================================================
