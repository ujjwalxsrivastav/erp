-- ============================================================================
-- SHIVALIK INTERNATIONAL SCHOOL (SHIV-SCH) — VERIFIED SEED SQL
-- Client: K-12 CBSE Affiliated School, Dehradun, Uttarakhand
-- Dual-Mode Education ERP
-- Matches live database schema exactly
-- ============================================================================

-- 1. INSTITUTES
INSERT INTO institutes (id, code, name, type, address, contact_email)
VALUES (
    '26af828e-5034-466c-b9dd-a9227ded9aa8',
    'SHIV-SCH',
    'Shivalik International School',
    'school',
    'Chakrata Road, Dehradun, Uttarakhand - 248001',
    'principal@shivalikschool.edu.in'
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    address = EXCLUDED.address,
    contact_email = EXCLUDED.contact_email;

-- 2. SCHOOL STUDENTS
INSERT INTO school_students (id, username, name, class_id, class_name, roll_number, admission_no, parent_name, contact)
VALUES
    ('SCH-01', 'sstudent1', 'Aarav Sharma', 'cls-10a', 'Class 10-A', '01', 'ADM202601', 'Rajesh Sharma', '9876543210'),
    ('SCH-02', 'sstudent2', 'Priya Patel', 'cls-10a', 'Class 10-A', '02', 'ADM202602', 'Sanjay Patel', '9876543211'),
    ('SCH-03', 'student3', 'Rohan Gupta', 'cls-10a', 'Class 10-A', '03', 'ADM202603', 'Manoj Gupta', '9876543212'),
    ('SCH-04', 'student4', 'Sneha Singh', 'cls-10a', 'Class 10-A', '04', 'ADM202604', 'Vikram Singh', '9876543213'),
    ('SCH-05', 'student5', 'Vikram Kumar', 'cls-10a', 'Class 10-A', '05', 'ADM202605', 'Alok Kumar', '9876543214'),
    ('SCH-06', 'student6', 'Ananya Verma', 'cls-10a', 'Class 10-A', '06', 'ADM202606', 'Sunil Verma', '9876543215'),
    ('SCH-07', 'student7', 'Aryan Sharma', 'cls-9a', 'Class 9-A', '01', 'ADM202607', 'Rajesh Sharma', '9876543210')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    class_id = EXCLUDED.class_id,
    class_name = EXCLUDED.class_name,
    roll_number = EXCLUDED.roll_number,
    parent_name = EXCLUDED.parent_name,
    contact = EXCLUDED.contact;

-- 3. PARENT-STUDENT LINKS (Parent Rajesh Sharma linked to Aarav in 10-A and Aryan in 9-A)
INSERT INTO parent_student_links (id, parent_username, student_username, relation)
VALUES
    ('8c378ff2-2351-4bd2-99ba-25afeca6d925', 'parent1', 'sstudent1', 'Father'),
    ('8c378ff2-2351-4bd2-99ba-25afeca6d926', 'parent1', 'student7', 'Father'),
    ('8c378ff2-2351-4bd2-99ba-25afeca6d927', 'parent2', 'sstudent2', 'Mother')
ON CONFLICT (id) DO UPDATE SET
    relation = EXCLUDED.relation;

-- 4. SUBJECTS
INSERT INTO school_subjects (id, name, code, class_id)
VALUES
    ('sub-1', 'Mathematics', 'MATH10', 'cls-10a'),
    ('sub-2', 'Science', 'SCI10', 'cls-10a'),
    ('sub-3', 'English', 'ENG10', 'cls-10a'),
    ('sub-4', 'Social Studies', 'SST10', 'cls-10a'),
    ('sub-5', 'Hindi', 'HIN10', 'cls-10a'),
    ('sub-6', 'Computer Science', 'CS10', 'cls-10a')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    code = EXCLUDED.code;

-- 5. LIBRARY BOOKS
INSERT INTO school_library (id, title, author, category, isbn, copies, available, location)
VALUES
    ('BK-001', 'Mathematics Textbook Grade 10', 'R.D. Sharma', 'Mathematics', '978-81-131-0234-5', 15, 12, 'Shelf A-2'),
    ('BK-002', 'Physics: Concepts and Principles', 'H.C. Verma', 'Science', '978-81-239-1819-2', 12, 8, 'Shelf B-1'),
    ('BK-003', 'Indian History: Medieval Period', 'Bipin Chandra', 'History', '978-81-250-1759-3', 8, 8, 'Shelf C-3'),
    ('BK-004', 'English Grammar and Composition', 'Wren & Martin', 'Literature', '978-93-5097-026-3', 20, 15, 'Shelf A-5'),
    ('BK-005', 'Introduction to Computer Science', 'Sumita Arora', 'Computer', '978-93-5057-555-4', 10, 7, 'Shelf D-1'),
    ('BK-006', 'Wings of Fire', 'Dr. A.P.J. Abdul Kalam', 'Biography', '978-81-7371-146-6', 6, 5, 'Shelf E-1')
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    copies = EXCLUDED.copies,
    available = EXCLUDED.available;

-- 6. CERTIFICATE REQUESTS
INSERT INTO school_certificate_requests (id, student_name, class, cert_type, reason, status, username)
VALUES
    ('cert-01', 'Aarav Sharma', 'Class 10-A', 'Bonafide Certificate', 'Passport application requirement', 'Approved', 'sstudent1'),
    ('cert-02', 'Priya Patel', 'Class 10-A', 'Study Certificate', 'State talent scholarship verification', 'Under Review', 'sstudent2'),
    ('cert-03', 'Rohan Gupta', 'Class 10-A', 'Transfer Certificate', 'Relocation to another state', 'Ready for Collection', 'student3')
ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status;

-- 7. FEE PAYMENTS
INSERT INTO school_fee_payments (student_id, class_id, amount, paid_amount, due_date, payment_mode, receipt_no, status, head)
VALUES
    ('sstudent1', 'cls-10a', 24500.00, 24500.00, '2026-10-15', 'UPI', 'RCT-2026-001', 'paid', 'Quarter 2 Tuition Fee'),
    ('sstudent1', 'cls-10a', 6500.00, 6500.00, '2026-10-15', 'Net Banking', 'RCT-2026-002', 'paid', 'Annual Activity & Lab Fee'),
    ('sstudent2', 'cls-10a', 24500.00, 24500.00, '2026-10-18', 'Counter Cash', 'RCT-2026-003', 'paid', 'Quarter 2 Tuition Fee'),
    ('student3', 'cls-10a', 24500.00, 0.00, '2026-11-15', 'Pending', null, 'pending', 'Quarter 2 Tuition Fee');

-- 8. ATTENDANCE
INSERT INTO school_attendance (student_id, student_name, class_name, section, class_id, date, status, marked_by)
VALUES
    ('sstudent1', 'Aarav Sharma', 'Class 10', 'A', 'cls-10a', CURRENT_DATE, 'present', 'steacher1'),
    ('sstudent2', 'Priya Patel', 'Class 10', 'A', 'cls-10a', CURRENT_DATE, 'present', 'steacher1'),
    ('student3', 'Rohan Gupta', 'Class 10', 'A', 'cls-10a', CURRENT_DATE, 'absent', 'steacher1'),
    ('student4', 'Sneha Singh', 'Class 10', 'A', 'cls-10a', CURRENT_DATE, 'present', 'steacher1'),
    ('student5', 'Vikram Kumar', 'Class 10', 'A', 'cls-10a', CURRENT_DATE, 'present', 'steacher1'),
    ('student6', 'Ananya Verma', 'Class 10', 'A', 'cls-10a', CURRENT_DATE, 'present', 'steacher1');

-- 9. TIMETABLE
INSERT INTO school_timetable (class_id, day, period, start_time, end_time, subject, teacher_username, room)
VALUES
    -- Class 10-A
    ('cls-10a', 'Monday', 1, '08:00 AM', '08:45 AM', 'Mathematics', 'steacher1', 'Room 101'),
    ('cls-10a', 'Monday', 2, '08:45 AM', '09:30 AM', 'Physics', 'steacher1', 'Physics Lab'),
    ('cls-10a', 'Monday', 3, '09:45 AM', '10:30 AM', 'Chemistry', 'mrs_gupta', 'Chem Lab'),
    ('cls-10a', 'Monday', 4, '10:30 AM', '11:15 AM', 'English', 'ms_verma', 'Room 101'),
    ('cls-10a', 'Monday', 5, '11:45 AM', '12:30 PM', 'Social Science', 'mr_singh', 'Room 101'),
    ('cls-10a', 'Monday', 6, '12:30 PM', '01:15 PM', 'Computer Science', 'ms_nair', 'Computer Lab'),
    ('cls-10a', 'Tuesday', 1, '08:00 AM', '08:45 AM', 'English', 'ms_verma', 'Room 101'),
    ('cls-10a', 'Tuesday', 2, '08:45 AM', '09:30 AM', 'Mathematics', 'steacher1', 'Room 101'),
    ('cls-10a', 'Tuesday', 3, '09:45 AM', '10:30 AM', 'Biology', 'mrs_gupta', 'Bio Lab'),
    ('cls-10a', 'Tuesday', 4, '10:30 AM', '11:15 AM', 'Hindi', 'mr_singh', 'Room 101'),
    ('cls-10a', 'Tuesday', 5, '11:45 AM', '12:30 PM', 'Social Science', 'mr_singh', 'Room 101'),
    ('cls-10a', 'Tuesday', 6, '12:30 PM', '01:15 PM', 'Physical Education', 'coach_rana', 'Sports Ground'),
    ('cls-10a', 'Wednesday', 1, '08:00 AM', '08:45 AM', 'Physics', 'steacher1', 'Physics Lab'),
    ('cls-10a', 'Wednesday', 2, '08:45 AM', '09:30 AM', 'Mathematics', 'steacher1', 'Room 101'),
    ('cls-10a', 'Wednesday', 3, '09:45 AM', '10:30 AM', 'English', 'ms_verma', 'Room 101'),
    ('cls-10a', 'Wednesday', 4, '10:30 AM', '11:15 AM', 'Chemistry', 'mrs_gupta', 'Chem Lab'),
    ('cls-10a', 'Wednesday', 5, '11:45 AM', '12:30 PM', 'Computer Science', 'ms_nair', 'Computer Lab'),
    ('cls-10a', 'Wednesday', 6, '12:30 PM', '01:15 PM', 'Art & Music', 'mr_roy', 'Activity Hall'),
    -- Class 9-A
    ('cls-9a', 'Monday', 1, '08:00 AM', '08:45 AM', 'English', 'ms_verma', 'Room 102'),
    ('cls-9a', 'Monday', 2, '08:45 AM', '09:30 AM', 'Social Studies', 'mr_singh', 'Room 102'),
    ('cls-9a', 'Monday', 3, '09:45 AM', '10:30 AM', 'Mathematics', 'steacher1', 'Room 102'),
    ('cls-9a', 'Monday', 4, '10:30 AM', '11:15 AM', 'Science', 'mrs_gupta', 'Room 102');

-- 10. ADMISSIONS
INSERT INTO school_admissions (student_name, parent_name, phone, email, class_applying, status)
VALUES
    ('Reyansh Kapoor', 'Varun Kapoor', '9812345678', 'varun.kapoor@gmail.com', 'Class 1', 'approved'),
    ('Myra Joshi', 'Dr. Ashish Joshi', '9823456789', 'ashish.joshi@maxhealthcare.com', 'Class 6', 'pending'),
    ('Devansh Rawat', 'Harish Rawat', '9834567890', 'harish.rawat@gov.in', 'Class 9', 'pending');

-- 11. CBSE SCHOLASTIC MARKS
INSERT INTO school_marks (institute_code, student_id, student_name, class_id, class_name, section, subject, exam_type, marks_obtained, total_marks, grade, remarks)
VALUES
    ('SHIV-SCH', 'sstudent1', 'Aarav Sharma', 'cls-10a', 'Class 10', 'A', 'Mathematics', 'Annual', 92, 100, 'A1', 'Exemplary algebraic problem solving'),
    ('SHIV-SCH', 'sstudent1', 'Aarav Sharma', 'cls-10a', 'Class 10', 'A', 'Science', 'Annual', 86, 100, 'A2', 'Great laboratory inquiry'),
    ('SHIV-SCH', 'sstudent1', 'Aarav Sharma', 'cls-10a', 'Class 10', 'A', 'English Language & Lit', 'Annual', 88, 100, 'A2', 'Fluent writing and critical expression'),
    ('SHIV-SCH', 'sstudent1', 'Aarav Sharma', 'cls-10a', 'Class 10', 'A', 'Social Science', 'Annual', 84, 100, 'A2', 'In-depth historical analysis'),
    ('SHIV-SCH', 'sstudent1', 'Aarav Sharma', 'cls-10a', 'Class 10', 'A', 'Hindi Course-A', 'Annual', 81, 100, 'A2', 'Good vocabulary and literature appreciation'),
    ('SHIV-SCH', 'sstudent1', 'Aarav Sharma', 'cls-10a', 'Class 10', 'A', 'Computer Applications', 'Annual', 95, 100, 'A1', 'Superior coding and project implementation'),
    ('SHIV-SCH', 'sstudent2', 'Priya Patel', 'cls-10a', 'Class 10', 'A', 'Mathematics', 'Annual', 89, 100, 'A2', 'Consistent performance'),
    ('SHIV-SCH', 'sstudent2', 'Priya Patel', 'cls-10a', 'Class 10', 'A', 'Science', 'Annual', 91, 100, 'A1', 'Outstanding science projects'),
    ('SHIV-SCH', 'sstudent2', 'Priya Patel', 'cls-10a', 'Class 10', 'A', 'English Language & Lit', 'Annual', 85, 100, 'A2', 'Very good communication'),
    ('SHIV-SCH', 'sstudent2', 'Priya Patel', 'cls-10a', 'Class 10', 'A', 'Social Science', 'Annual', 87, 100, 'A2', 'Active participant'),
    ('SHIV-SCH', 'sstudent2', 'Priya Patel', 'cls-10a', 'Class 10', 'A', 'Hindi Course-A', 'Annual', 88, 100, 'A2', 'Great essays'),
    ('SHIV-SCH', 'sstudent2', 'Priya Patel', 'cls-10a', 'Class 10', 'A', 'Computer Applications', 'Annual', 93, 100, 'A1', 'Proficient programmer');
