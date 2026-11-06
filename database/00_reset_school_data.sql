-- ============================================================================
-- RESET SCHOOL DATA BEFORE A CLEAN RE-SEED
-- File: database/00_reset_school_data.sql
--
-- WHAT IT DOES
--   Clears the data (not the tables) of every school / module table so the
--   seed files can be run again from scratch. Sequences are reset too.
--
--   public.users IS INTENTIONALLY NOT TOUCHED:
--     * there is no CREATE TABLE users in database/ (only in
--       database_export/schema.sql), and
--     02_school_seed_test_data.sql INSERTs into public.users.
--     Dropping/truncating it would leave nothing to log in with.
--
-- HOW TO RUN
--   Supabase dashboard -> SQL Editor -> paste -> Run.
--   (or: psql "$DATABASE_URL" -f database/00_reset_school_data.sql)
--
--   Then run the seed files in this order:
--     1. dual_mode_school_setup.sql
--     2. users_institution_setup.sql
--     3. 01_class_structure_no_sections.sql
--     4. 02_school_seed_test_data.sql
--     5. school_fees_setup.sql
--     6. school_fee_receipts_setup.sql
--     7. school_homework_submissions_setup.sql
--     8. school_student_leaves_setup.sql
--     9. school_permissions_setup.sql
--    10. school_examination_management_setup.sql
--    11. school_academic_calendar_setup.sql
--    12. school_activities_setup.sql
--    13. school_alumni_setup.sql
--    14. school_admin_suite_setup.sql
--    15. school_ai_setup.sql
--    16. school_discipline_setup.sql
--    17. school_hostel_infirmary_cafeteria_setup.sql
--    18. school_inventory_setup.sql
--    19. school_library_setup.sql
--    20. school_multi_setup.sql
--    21. school_parent_admin_lifecycle.sql
--    22. school_parent_comms_setup.sql
--    23. school_payroll_setup.sql
--    24. school_student_suite_setup.sql
--    25. school_runtime_fix_setup.sql
--    26. school_role_screens_notifications.sql
--    27. school_report_card_seed.sql
--    28. school_demo_practice_quiz.sql
--    29. performance_indexes.sql
--
--   NOT part of the school re-seed (legacy / alternate datasets):
--     school_seed_client.sql, fees_tables.sql, database_export/*
--
-- NOTE  CASCADE truncates anything that has a foreign key into these tables.
--       Every dependent table is already in the list below, so nothing
--       unexpected (and nothing in public.users) is affected.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  t text;
  targets text[] := ARRAY[
    'bus_fee_enrollment',
    'fee_transactions',
    'hostel_fee_enrollment',
    'institutes',
    'parent_student_links',
    'school_academic_calendar',
    'school_activity_events',
    'school_activity_participations',
    'school_admissions',
    'school_ai_feedback',
    'school_ai_question_papers',
    'school_ai_remarks',
    'school_ai_usage_log',
    'school_alumni_donation_interests',
    'school_alumni_events',
    'school_alumni_profiles',
    'school_alumni_rsvps',
    'school_attendance',
    'school_audit_log',
    'school_cafeteria_menus',
    'school_canteen_orders',
    'school_certificate_requests',
    'school_circulars',
    'school_classes',
    'school_club_memberships',
    'school_clubs',
    'school_co_scholastic',
    'school_discipline_actions',
    'school_discipline_incidents',
    'school_discipline_inquiries',
    'school_discipline_parent_notices',
    'school_exam_management_sessions',
    'school_exam_rooms',
    'school_exam_schedule_papers',
    'school_exam_sessions',
    'school_exams',
    'school_fee_accounts',
    'school_fee_items',
    'school_fee_payments',
    'school_fee_receipts',
    'school_gate_passes',
    'school_homework',
    'school_homework_submissions',
    'school_hostel_allocations',
    'school_hostel_attendance',
    'school_hostel_rooms',
    'school_hostels',
    'school_infirmary_records',
    'school_infirmary_visits',
    'school_institute_billing',
    'school_institute_settings',
    'school_institutes',
    'school_inventory_audits',
    'school_inventory_issues',
    'school_inventory_items',
    'school_inventory_maintenance',
    'school_library',
    'school_library_ebooks',
    'school_library_fine_ledger',
    'school_library_issues',
    'school_library_reservations',
    'school_maker_checker_requests',
    'school_marks',
    'school_marks_locks',
    'school_meal_plans',
    'school_medicine_stock',
    'school_notifications',
    'school_parent_grievances',
    'school_parent_preferences',
    'school_parent_teacher_messages',
    'school_payroll_runs',
    'school_payslips',
    'school_ptm_bookings',
    'school_quiz_attempts',
    'school_quizzes',
    'school_report_card_meta',
    'school_role_permissions',
    'school_salary_structures',
    'school_settings',
    'school_sports_teams',
    'school_staff_leaves',
    'school_student_goals',
    'school_student_leaves',
    'school_student_queries',
    'school_students',
    'school_subjects',
    'school_teacher_classes',
    'school_teacher_messages',
    'school_teachers',
    'school_timetable',
    'school_transport',
    'student_fees',
  ];
BEGIN
  FOREACH t IN ARRAY targets LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('TRUNCATE TABLE public.%I RESTART IDENTITY CASCADE', t);
    END IF;
  END LOOP;
END $$;

COMMIT;

-- OPTIONAL: also clear the login table. Only do this if you are re-running
-- the user-seeding section of 02_school_seed_test_data.sql too — otherwise
-- existing staff/parent accounts would disappear.
-- TRUNCATE TABLE public.users;

-- Verification: every counter below should read 0.
-- SELECT 'school_students' t, count(*) FROM public.school_students
-- UNION ALL SELECT 'school_teachers', count(*) FROM public.school_teachers
-- UNION ALL SELECT 'school_marks', count(*) FROM public.school_marks
-- UNION ALL SELECT 'school_fee_payments', count(*) FROM public.school_fee_payments
-- UNION ALL SELECT 'school_timetable', count(*) FROM public.school_timetable
-- UNION ALL SELECT 'school_attendance', count(*) FROM public.school_attendance;

-- ----------------------------------------------------------------------------
-- NUCLEAR OPTION (only if table definitions themselves are broken):
-- drops the tables instead of emptying them. The CREATE TABLE IF NOT EXISTS
-- statements in the seed files will rebuild them. public.users is still kept.
-- ----------------------------------------------------------------------------
-- DO $$
-- DECLARE t text;
-- BEGIN
--   FOR t IN
--     SELECT tablename FROM pg_tables
--     WHERE schemaname = 'public'
--       AND (tablename LIKE 'school_%'
--            OR tablename IN ('institutes','parent_student_links',
--                             'fee_transactions','student_fees',
--                             'bus_fee_enrollment','hostel_fee_enrollment'))
--   LOOP
--     EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE', t);
--   END LOOP;
-- END $$;
