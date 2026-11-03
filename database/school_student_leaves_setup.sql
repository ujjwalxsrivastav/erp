-- ============================================================================
-- SCHOOL STUDENT LEAVE REQUESTS BACKEND
-- Run this in Supabase Dashboard -> SQL Editor.
--
-- Safe to re-run (idempotent). No demo/dummy data is inserted.
--
-- Purpose:
--   * A student (or their parent) files a leave application for a date range.
--   * The application is routed to the class teacher of the student's class
--     (school_classes.class_teacher_id).
--   * The class teacher approves or rejects it with remarks. Approval marks
--     the covered days as 'excused' in school_attendance.
--
-- Before this table exists the app falls back to the legacy
-- school_circulars (category = 'StudentLeave') storage, so nothing breaks
-- if this script has not been run yet.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_student_leaves (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id        TEXT,                     -- school_students.id (best effort)
    student_username  TEXT NOT NULL,            -- users.username (student identity)
    student_name      TEXT NOT NULL,
    class_id          TEXT,
    class_name        TEXT,
    section           TEXT,
    class_teacher_id  TEXT,                     -- users.username of the class teacher
    leave_type        TEXT NOT NULL DEFAULT 'Casual Leave',
    start_date        DATE NOT NULL,
    end_date          DATE NOT NULL,
    total_days        INTEGER NOT NULL DEFAULT 1 CHECK (total_days > 0),
    reason            TEXT NOT NULL,
    document_url      TEXT,                     -- medical certificate / proof (optional)
    status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    applied_by        TEXT,                     -- username that filed the application
    applied_by_role   TEXT,                     -- 'student' or 'parent'
    reviewed_by       TEXT,                     -- username of the class teacher
    reviewer_name     TEXT,
    review_remarks    TEXT,
    reviewed_at       TIMESTAMPTZ,
    attendance_marked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT school_student_leaves_date_order CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_school_student_leaves_student
    ON public.school_student_leaves (student_username);

CREATE INDEX IF NOT EXISTS idx_school_student_leaves_class
    ON public.school_student_leaves (class_id);

CREATE INDEX IF NOT EXISTS idx_school_student_leaves_teacher
    ON public.school_student_leaves (class_teacher_id);

CREATE INDEX IF NOT EXISTS idx_school_student_leaves_status
    ON public.school_student_leaves (status);

-- ---------------------------------------------------------------------------
-- Access (matches the dual-mode ERP policy: RLS disabled for the app)
-- ---------------------------------------------------------------------------
ALTER TABLE public.school_student_leaves DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.school_student_leaves
    TO anon, authenticated, service_role;

SELECT 'School student leaves setup completed successfully!' AS result;
