-- ============================================================================
-- PERFORMANCE INDEXES (safe, idempotent, single transaction)
-- ----------------------------------------------------------------------------
-- The app filters/joins almost every screen by student, class, and fee status.
-- Without indexes Postgres does sequential scans, which is the main reason
-- screens feel slow on a seeded database. This file only ADDS indexes; it
-- never drops or changes data. Re-running it is a no-op.
--
-- Run order: after the school schema/seed files (01/02/03).
-- ============================================================================

BEGIN;

DO $$
BEGIN
  -- ── Fees ────────────────────────────────────────────────────────────────
  IF to_regclass('public.school_fee_payments') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_fee_payments_student
      ON public.school_fee_payments (student_id);
    CREATE INDEX IF NOT EXISTS idx_school_fee_payments_status
      ON public.school_fee_payments (status);
    CREATE INDEX IF NOT EXISTS idx_school_fee_payments_student_status
      ON public.school_fee_payments (student_id, status);
    CREATE INDEX IF NOT EXISTS idx_school_fee_payments_class
      ON public.school_fee_payments (class_id);
    CREATE INDEX IF NOT EXISTS idx_school_fee_payments_due_date
      ON public.school_fee_payments (due_date);
  END IF;

  IF to_regclass('public.school_fee_receipts') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_fee_receipts_student
      ON public.school_fee_receipts (student_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_school_fee_receipts_receipt_no
      ON public.school_fee_receipts (receipt_no);
  END IF;

  -- ── Students ────────────────────────────────────────────────────────────
  IF to_regclass('public.school_students') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_students_username
      ON public.school_students (username);
    CREATE INDEX IF NOT EXISTS idx_school_students_class_name
      ON public.school_students (class_name);
    CREATE INDEX IF NOT EXISTS idx_school_students_class_id
      ON public.school_students (class_id);
  END IF;

  -- ── Marks / report cards ────────────────────────────────────────────────
  IF to_regclass('public.school_marks') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_marks_student
      ON public.school_marks (student_id);
    CREATE INDEX IF NOT EXISTS idx_school_marks_student_exam
      ON public.school_marks (student_id, exam_type);
    CREATE INDEX IF NOT EXISTS idx_school_marks_class_exam
      ON public.school_marks (class_name, exam_type);
  END IF;

  -- ── Homework ────────────────────────────────────────────────────────────
  IF to_regclass('public.school_homework') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_homework_class
      ON public.school_homework (class_name);
    CREATE INDEX IF NOT EXISTS idx_school_homework_due_date
      ON public.school_homework (due_date);
  END IF;

  IF to_regclass('public.school_homework_submissions') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_homework_submissions_student
      ON public.school_homework_submissions (student_username);
    CREATE INDEX IF NOT EXISTS idx_school_homework_submissions_homework
      ON public.school_homework_submissions (homework_id);
  END IF;

  -- ── Attendance ──────────────────────────────────────────────────────────
  IF to_regclass('public.school_attendance') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_attendance_student_date
      ON public.school_attendance (student_id, date);
    CREATE INDEX IF NOT EXISTS idx_school_attendance_date
      ON public.school_attendance (date);
    CREATE INDEX IF NOT EXISTS idx_school_attendance_class_date
      ON public.school_attendance (class_name, date);
  END IF;

  -- ── Timetable ───────────────────────────────────────────────────────────
  IF to_regclass('public.school_timetable') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_timetable_class
      ON public.school_timetable (class_id);
    CREATE INDEX IF NOT EXISTS idx_school_timetable_teacher
      ON public.school_timetable (teacher_username);
  END IF;

  -- ── Misc hot reads ──────────────────────────────────────────────────────
  IF to_regclass('public.school_circulars') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_circulars_category
      ON public.school_circulars (category, published_at DESC);
  END IF;

  IF to_regclass('public.school_notifications') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_school_notifications_user
      ON public.school_notifications (user_id, created_at DESC);
  END IF;
END
$$;

COMMIT;
