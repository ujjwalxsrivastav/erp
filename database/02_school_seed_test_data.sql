-- ============================================================================
-- SHIVALIK SCHOOL — TEST SEED DATA (CLASS 10)
-- Run AFTER database/01_class_structure_no_sections.sql
-- (It will still work without it, but run order above is recommended.)
--
-- Creates ready-to-test dummy data. Idempotent: safe to re-run.
-- Passwords = usernames (matches the app's existing login pattern).
--
--   * Class 10                : 1 class row (no sections)
--   * 50 students of Class 10 : s10s01 .. s10s50  (password same)
--   * 22 subject teachers     : steach01 .. steach22 (password same)
--   * Class teacher of 10     : steach01 (Mathematics)
--   * 1 demo parent           : parent1 (existing) gets 2 children of Class 10
--   * Fee demands             : 1 pending demand per student (+5 paid samples)
--   * Homework                : 5 assignments for Class 10
--   * Attendance              : last 5 working days × all 50 students
--   * Marks                   : Mid Term rows for first 10 students
--   * Timetable               : Mon–Sat × 6 periods for Class 10
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Make sure exactly one 'Class 10' class row exists (no section)
-- ---------------------------------------------------------------------------
DO $$
DECLARE cid TEXT;
BEGIN
  SELECT id INTO cid
  FROM public.school_classes
  WHERE name = 'Class 10'
  ORDER BY created_at ASC NULLS LAST
  LIMIT 1;

  IF cid IS NULL THEN
    INSERT INTO public.school_classes (name, section, academic_year)
    VALUES ('Class 10', NULL, '2026-2027');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1. USERS — 50 students of Class 10
-- ---------------------------------------------------------------------------
INSERT INTO public.users (username, password, role, institute_type)
SELECT username, username, 'student', 'school'
FROM (
  SELECT 's10s' || lpad(g::text, 2, '0') AS username FROM generate_series(1, 50) g
) u
ON CONFLICT (username) DO UPDATE
  SET password = EXCLUDED.password,
      role = 'student',
      institute_type = 'school';

-- ---------------------------------------------------------------------------
-- 2. STUDENT MASTER RECORDS (school_students)
-- ---------------------------------------------------------------------------
WITH cfg AS (
  SELECT (SELECT id FROM public.school_classes
          WHERE name = 'Class 10'
          ORDER BY created_at ASC NULLS LAST LIMIT 1) AS cid
),
g AS (SELECT generate_series(1, 50) AS i),
first_names AS (
  SELECT ARRAY[
    'Aarav','Vivaan','Aditya','Vihaan','Arjun','Reyansh','Ishaan','Karthik',
    'Ananya','Diya','Advika','Ira','Myra','Sara','Anika','Riya','Navya','Kiara',
    'Rohan','Kabir','Dhruv','Advait','Shaurya','Atharv','Pranav',
    'Meera','Tara','Zoya','Radhika','Sneha','Priya','Nisha','Kavya',
    'Aryan','Viyan','Nivaan','Yash','Rudra','Om','Dev','Parth',
    'Shanaya','Aadhya','Prisha','Anvi','Charvi','Trisha','Vaani','Hiral','Nitya'
  ] AS fn
),
last_names AS (
  SELECT ARRAY[
    'Sharma','Verma','Gupta','Singh','Mehta','Malhotra','Chopra','Kapoor',
    'Joshi','Nair','Pillai','Desai','Bose','Chatterjee','Rathore','Thakur',
    'Iyer','Banerjee','Reddy','Menon','Khanna','Saxena','Pandey','Bhat'
  ] AS ln
),
parent_first AS (
  SELECT ARRAY[
    'Rajesh','Suresh','Mahesh','Naveen','Vikram','Sanjay','Anil','Prakash',
    'Harish','Mukesh','Dinesh','Ramesh','Ajay','Nikhil','Ashok','Vinod'
  ] AS pfn
)
-- Name mixes come from an md5 hash of the roll number, so every student gets
-- a "random"-looking but STABLE name (won't change between re-runs).
INSERT INTO public.school_students
  (id, username, name, class_id, class_name, roll_number, admission_no,
   parent_name, contact)
SELECT
  'SCH10-' || lpad(i::text, 2, '0'),
  's10s' || lpad(i::text, 2, '0'),
  fn[1 + (r % array_length(fn,1))] || ' ' ||
    ln[1 + ((r / array_length(fn,1)) % array_length(ln,1))],
  (SELECT cid::text FROM cfg),
  'Class 10',
  lpad(i::text, 2, '0'),
  'ADM26-10-' || lpad(i::text, 2, '0'),
  CASE
    WHEN (r % 4) = 3
      THEN 'Mrs. ' || fn[1 + ((r / 7) % array_length(fn,1))] || ' ' ||
           ln[1 + ((r / array_length(fn,1)) % array_length(ln,1))]
    ELSE 'Mr. ' ||
           pfn[1 + ((r / 3) % array_length(pfn,1))] || ' ' ||
           ln[1 + ((r / array_length(fn,1)) % array_length(ln,1))]
  END,
  '98' || lpad(((r % 90000000) + 10000000)::text, 8, '0')
FROM g, first_names, last_names, parent_first,
     LATERAL (SELECT ('x' || substr(md5('cls10-student-' || i::text), 1, 6))::bit(24)::int AS r) h
ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name,
      class_id = EXCLUDED.class_id,
      class_name = EXCLUDED.class_name,
      roll_number = EXCLUDED.roll_number,
      admission_no = EXCLUDED.admission_no,
      parent_name = EXCLUDED.parent_name,
      contact = EXCLUDED.contact;

-- ---------------------------------------------------------------------------
-- 3. USERS — 22 subject teachers (one class teacher among them)
-- ---------------------------------------------------------------------------
WITH teachers (i, tname, subject, qualification) AS (
  VALUES
    ( 1, 'Rakesh Sharma',      'Mathematics',       'M.Sc (Mathematics), B.Ed'),
    ( 2, 'Sunita Gupta',       'Mathematics',       'M.Sc (Mathematics), B.Ed'),
    ( 3, 'Deepak Mehta',       'Mathematics',       'M.Sc (Mathematics), M.Ed'),
    ( 4, 'Anjali Nair',        'Science',           'M.Sc (Physics), B.Ed'),
    ( 5, 'Vivek Rathore',      'Science',           'M.Sc (Chemistry), B.Ed'),
    ( 6, 'Pooja Desai',        'Physics',           'M.Sc (Physics), B.Ed'),
    ( 7, 'Amit Chatterjee',    'Physics',           'M.Sc (Physics), B.Ed'),
    ( 8, 'Rekha Iyer',         'Chemistry',         'M.Sc (Chemistry), B.Ed'),
    ( 9, 'Suresh Pillai',      'Chemistry',         'M.Sc (Chemistry), B.Ed'),
    (10, 'Nandini Bose',       'Biology',           'M.Sc (Botany), B.Ed'),
    (11, 'Farah Khan',         'English',           'M.A (English), B.Ed'),
    (12, 'Rajiv Malhotra',     'English',           'M.A (English), B.Ed'),
    (13, 'Shalini Kapoor',     'English',           'M.A (English), M.Ed'),
    (14, 'Geeta Pandey',       'Hindi',             'M.A (Hindi), B.Ed'),
    (15, 'Ravi Saxena',        'Hindi',             'M.A (Hindi), B.Ed'),
    (16, 'Manish Thakur',      'Social Studies',    'M.A (History), B.Ed'),
    (17, 'Swati Joshi',        'Social Studies',    'M.A (Geography), B.Ed'),
    (18, 'Neha Kulkarni',      'Computer Science',  'MCA, B.Ed'),
    (19, 'Imran Sheikh',       'Computer Science',  'MCA, B.Ed'),
    (20, 'Vidya Shankar',      'Sanskrit',          'M.A (Sanskrit), B.Ed'),
    (21, 'Sunil Bhatia',       'Physical Education','B.P.Ed'),
    (22, 'Priyanka Sen',       'Art & Craft',       'B.F.A')
)
INSERT INTO public.users (username, password, role, institute_type)
SELECT
  'steach' || lpad(t.i::text, 2, '0'),
  'steach' || lpad(t.i::text, 2, '0'),
  'teacher', 'school'
FROM teachers t
ON CONFLICT (username) DO UPDATE
  SET password = EXCLUDED.password,
      role = 'teacher',
      institute_type = 'school';

-- ---------------------------------------------------------------------------
-- 4. CLASS TEACHER of Class 10 — exactly one (DB constraint in file 01 also
--    guarantees a teacher can only be class teacher of ONE class)
-- ---------------------------------------------------------------------------
UPDATE public.school_classes
SET    class_teacher_id = 'steach01'
WHERE  name = 'Class 10';

-- ---------------------------------------------------------------------------
-- 5. SUBJECTS taught in Class 10 (teacher of record = first teacher of subject)
-- ---------------------------------------------------------------------------
DELETE FROM public.school_subjects WHERE class_id = (SELECT id::text FROM public.school_classes WHERE name='Class 10' ORDER BY created_at ASC NULLS LAST LIMIT 1) AND id LIKE 'sub-10-%';

INSERT INTO public.school_subjects (id, class_id, name, code)
SELECT 'sub-10-' || lower(replace(v.name, ' ', '')),
       (SELECT id::text FROM public.school_classes WHERE name='Class 10' ORDER BY created_at ASC NULLS LAST LIMIT 1),
       v.name, v.code
FROM (VALUES
  ('Mathematics',        'MATH10'),
  ('Science',            'SCI10'),
  ('Physics',            'PHY10'),
  ('Chemistry',          'CHM10'),
  ('Biology',            'BIO10'),
  ('English',            'ENG10'),
  ('Hindi',              'HIN10'),
  ('Social Studies',     'SST10'),
  ('Computer Science',   'CS10'),
  ('Sanskrit',           'SAN10'),
  ('Physical Education', 'PED10'),
  ('Art & Craft',        'ART10')
) AS v(name, code)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. FEE DEMANDS — 1 pending demand per Class 10 student (fee screen data)
--    Guarded with NOT EXISTS so re-running never duplicates rows.
-- ---------------------------------------------------------------------------
WITH cfg AS (
  SELECT (SELECT id FROM public.school_classes
          WHERE name = 'Class 10'
          ORDER BY created_at ASC NULLS LAST LIMIT 1) AS cid
)
INSERT INTO public.school_fee_payments
  (student_id, class_id, amount, paid_amount, due_date, payment_mode, receipt_no, status, head)
SELECT
  s.username, (SELECT cid::text FROM cfg), 24500.00, 0.00,
  (CURRENT_DATE + INTERVAL '15 day')::date, 'Pending', NULL, 'pending',
  'Quarter 4 Tuition Fee'
FROM public.school_students s
WHERE s.class_id = (SELECT cid::text FROM cfg)
  AND NOT EXISTS (
    SELECT 1 FROM public.school_fee_payments p
    WHERE p.student_id = s.username
      AND p.head = 'Quarter 4 Tuition Fee'
  );

-- Sample already-paid history for the first 5 students (idempotent)
INSERT INTO public.school_fee_payments
  (student_id, class_id, amount, paid_amount, due_date, payment_mode, receipt_no, status, head)
SELECT
  s.username, s.class_id, 24500.00, 24500.00, '2026-10-15', 'UPI', NULL, 'paid',
  'Quarter 3 Tuition Fee'
FROM public.school_students s
WHERE s.class_name = 'Class 10' AND s.roll_number <= '05'
  AND NOT EXISTS (
    SELECT 1 FROM public.school_fee_payments p
    WHERE p.student_id = s.username AND p.head = 'Quarter 3 Tuition Fee');

INSERT INTO public.school_fee_payments
  (student_id, class_id, amount, paid_amount, due_date, payment_mode, receipt_no, status, head)
SELECT
  s.username, s.class_id, 6500.00, 6500.00, '2026-10-15', 'UPI', NULL, 'paid',
  'Annual Activity & Lab Fee'
FROM public.school_students s
WHERE s.class_name = 'Class 10' AND s.roll_number <= '05'
  AND NOT EXISTS (
    SELECT 1 FROM public.school_fee_payments p
    WHERE p.student_id = s.username AND p.head = 'Annual Activity & Lab Fee');

-- ---------------------------------------------------------------------------
-- 7. HOMEWORK — 5 assignments for Class 10 (teacher usernames match seed)
-- ---------------------------------------------------------------------------
INSERT INTO public.school_homework
  (class_name, section, subject, title, description, due_date, teacher_username)
SELECT * FROM (VALUES
  ('Class 10', NULL, 'Mathematics', 'Chapter 7: Coordinate Geometry — Exercise 7.2',
   'Complete questions 1 to 12 in the homework notebook. Show full working.',
   (CURRENT_DATE + INTERVAL '2 day')::date, 'steach01'),
  ('Class 10', NULL, 'Science', 'Ray Diagrams — Concave Mirrors',
   'Draw the 6 standard object positions for a concave mirror, labelled, on A4 sheets.',
   (CURRENT_DATE + INTERVAL '3 day')::date, 'steach04'),
  ('Class 10', NULL, 'English', 'Essay: Water Conservation in Daily Life',
   'Write a 400-word essay with an outline. Use at least 2 real examples.',
   (CURRENT_DATE + INTERVAL '4 day')::date, 'steach11'),
  ('Class 10', NULL, 'Computer Science', 'Python Loops Worksheet Set B',
   'Trace outputs of 8 given for/while loops and write the 2 missing lines in Q7/Q8.',
   (CURRENT_DATE + INTERVAL '5 day')::date, 'steach18'),
  ('Class 10', NULL, 'Social Studies', 'Civics: Power Sharing — Textbook Questions',
   'Answer all 6 in-text questions and prepare a one-page summary of the chapter.',
   (CURRENT_DATE + INTERVAL '6 day')::date, 'steach16')
) AS v(class_name, section, subject, title, description, due_date, teacher_username)
WHERE NOT EXISTS (
  SELECT 1 FROM public.school_homework h
  WHERE h.class_name = v.class_name AND h.title = v.title
);

-- ---------------------------------------------------------------------------
-- 8. ATTENDANCE — last 5 working days × all 50 students (~85% present)
-- ---------------------------------------------------------------------------
INSERT INTO public.school_attendance
  (student_id, student_name, class_name, section, class_id, date, status, marked_by)
SELECT
  s.username,
  s.name,
  'Class 10',
  NULL,
  s.class_id,
  d::date,
  CASE WHEN (extract(day FROM d)::int + s.roll_number::int) % 7 < 6
       THEN 'present' ELSE 'absent' END,
  'steach01'
FROM public.school_students s
CROSS JOIN generate_series(
  CURRENT_DATE - INTERVAL '10 day',
  CURRENT_DATE - INTERVAL '1 day',
  INTERVAL '1 day'
) d
WHERE extract(isodow FROM d) < 6          -- weekdays only
  AND s.class_name = 'Class 10'
ON CONFLICT (student_id, date) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 9. MARKS — 'Mid Term' for the first 10 students in each Class 10 subject
-- ---------------------------------------------------------------------------
INSERT INTO public.school_marks
  (student_id, student_name, class_name, section, subject, exam_type,
   marks_obtained, total_marks, grade, remarks)
SELECT
  s.username, s.name, 'Class 10', NULL, sub.name, 'Mid Term',
  38 + ((s.roll_number::int * 7 + length(sub.name) * 13) % 60),
  100,
  CASE
    WHEN 38 + ((s.roll_number::int * 7 + length(sub.name) * 13) % 60) >= 90 THEN 'A+'
    WHEN 38 + ((s.roll_number::int * 7 + length(sub.name) * 13) % 60) >= 75 THEN 'A'
    WHEN 38 + ((s.roll_number::int * 7 + length(sub.name) * 13) % 60) >= 60 THEN 'B'
    ELSE 'C'
  END,
  'Mid Term — seeded test data'
FROM public.school_students s
CROSS JOIN public.school_subjects sub
WHERE s.class_name = 'Class 10'
  AND s.roll_number <= '10'
  AND sub.class_id = s.class_id
  AND NOT EXISTS (
    SELECT 1 FROM public.school_marks m
    WHERE m.student_id = s.username
      AND m.subject = sub.name
      AND m.exam_type = 'Mid Term');

-- ---------------------------------------------------------------------------
-- 10. TIMETABLE for Class 10 — Mon–Sat × 6 periods, subjects cycle through
--     their subject teachers. (Class-teacher steach01 also teaches Maths.)
-- ---------------------------------------------------------------------------
WITH cfg AS (
  SELECT (SELECT id FROM public.school_classes
          WHERE name = 'Class 10'
          ORDER BY created_at ASC NULLS LAST LIMIT 1) AS cid
),
days AS (
  SELECT d AS day, idx
  FROM unnest(ARRAY['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'])
       WITH ORDINALITY AS t(d, idx)
),
periods AS (
  SELECT p AS period,
         CASE p
           WHEN 1 THEN '08:00' WHEN 2 THEN '08:50' WHEN 3 THEN '09:40'
           WHEN 4 THEN '11:00' WHEN 5 THEN '11:50' ELSE '12:40'
         END AS start_time,
         CASE p
           WHEN 1 THEN '08:45' WHEN 2 THEN '09:35' WHEN 3 THEN '10:25'
           WHEN 4 THEN '11:45' WHEN 5 THEN '12:35' ELSE '13:25'
         END AS end_time
  FROM generate_series(1, 6) p
),
subject_map AS (
  SELECT ARRAY[
    ARRAY['Mathematics',        'steach01'],
    ARRAY['Science',            'steach04'],
    ARRAY['English',            'steach11'],
    ARRAY['Hindi',              'steach14'],
    ARRAY['Social Studies',     'steach16'],
    ARRAY['Computer Science',   'steach18'],
    ARRAY['Sanskrit',           'steach20'],
    ARRAY['Physical Education', 'steach21'],
    ARRAY['Art & Craft',        'steach22']
  ] AS sm
)
INSERT INTO public.school_timetable
  (class_id, day, period, start_time, end_time, subject, teacher_username, room)
SELECT
  (SELECT cid::text FROM cfg),
  d.day,
  p.period,
  p.start_time,
  p.end_time,
  sm[1 + (((d.idx - 1) * 6 + (p.period - 1)) % 9)][1],
  sm[1 + (((d.idx - 1) * 6 + (p.period - 1)) % 9)][2],
  'Room ' || (1 + (p.period % 4))::text
FROM days d
CROSS JOIN periods p
CROSS JOIN subject_map
WHERE NOT EXISTS (
  SELECT 1 FROM public.school_timetable t
  WHERE t.class_id = (SELECT cid::text FROM cfg)
    AND t.day = d.day AND t.period = p.period);

-- ---------------------------------------------------------------------------
-- 11. DEMO PARENT — parent1 (existing test parent) linked to first 2 students
-- ---------------------------------------------------------------------------
INSERT INTO public.users (username, password, role, institute_type)
VALUES ('parent1', 'parent1', 'parent', 'school')
ON CONFLICT (username) DO UPDATE
  SET password = EXCLUDED.password,
      role = 'parent',
      institute_type = 'school';

INSERT INTO public.parent_student_links (parent_username, student_username, relation)
SELECT 'parent1', s.username, 'Father'
FROM public.school_students s
WHERE s.class_name = 'Class 10' AND s.roll_number <= '02'
  AND NOT EXISTS (
    SELECT 1 FROM public.parent_student_links l
    WHERE l.parent_username = 'parent1'
      AND l.student_username = s.username);

UPDATE public.school_students
SET    parent_name = 'Mr. Sharma', contact = '9876543210'
WHERE  class_name = 'Class 10' AND roll_number <= '02';

-- ---------------------------------------------------------------------------
-- 12. VERIFICATION
-- ---------------------------------------------------------------------------
SELECT 'students(class 10)' AS what, count(*) FROM public.school_students WHERE class_name = 'Class 10'
UNION ALL
SELECT 'teacher users (steach*)', count(*) FROM public.users WHERE username LIKE 'steach%'
UNION ALL
SELECT 'class teacher(s) of Class 10', count(*) FROM public.school_classes WHERE name = 'Class 10' AND class_teacher_id IS NOT NULL
UNION ALL
SELECT 'pending fee demands', count(*) FROM public.school_fee_payments WHERE status = 'pending'
UNION ALL
SELECT 'homework(class 10)', count(*) FROM public.school_homework WHERE class_name = 'Class 10'
UNION ALL
SELECT 'timetable slots', count(*) FROM public.school_timetable WHERE class_id = (SELECT id::text FROM public.school_classes WHERE name='Class 10' ORDER BY created_at ASC NULLS LAST LIMIT 1);

SELECT 'School seed completed successfully!' AS result;
