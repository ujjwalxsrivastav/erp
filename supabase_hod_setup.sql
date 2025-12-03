-- ========================================
-- HOD (Head of Department) Database Setup
-- ========================================

-- Step 1: Update users table role constraint to include 'hod'
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check 
CHECK (role IN ('student', 'teacher', 'admin', 'staff', 'HR', 'hod'));

-- Step 2: Create hod_assignments table
CREATE TABLE IF NOT EXISTS hod_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    assigned_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, department_id)
);

-- Step 3: Create study_materials table
CREATE TABLE IF NOT EXISTS study_materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES staff(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_url TEXT,
    material_type VARCHAR(50) DEFAULT 'notes', -- 'notes', 'assignment', 'reference', 'video', 'other'
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    hod_approved_by UUID REFERENCES users(id),
    hod_approval_date TIMESTAMP,
    rejection_reason TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Step 4: Create department_announcements table
CREATE TABLE IF NOT EXISTS department_announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    target_audience VARCHAR(50) DEFAULT 'all', -- 'all', 'students', 'faculty', 'specific_course'
    target_course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    priority VARCHAR(20) DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
    is_active BOOLEAN DEFAULT true,
    views_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

-- Step 5: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hod_assignments_user ON hod_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_hod_assignments_dept ON hod_assignments(department_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_course ON study_materials(course_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_teacher ON study_materials(teacher_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_status ON study_materials(status);
CREATE INDEX IF NOT EXISTS idx_dept_announcements_dept ON department_announcements(department_id);
CREATE INDEX IF NOT EXISTS idx_dept_announcements_active ON department_announcements(is_active);

-- Step 6: Add Row Level Security (RLS) Policies

-- Enable RLS on new tables
ALTER TABLE hod_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE department_announcements ENABLE ROW LEVEL SECURITY;

-- HOD Assignments Policies
CREATE POLICY "HOD can view their own assignment"
ON hod_assignments FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "Admin can manage HOD assignments"
ON hod_assignments FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Study Materials Policies
CREATE POLICY "Teachers can create study materials"
ON study_materials FOR INSERT
WITH CHECK (
    teacher_id IN (
        SELECT id FROM staff WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Teachers can view their own materials"
ON study_materials FOR SELECT
USING (
    teacher_id IN (
        SELECT id FROM staff WHERE user_id = auth.uid()
    )
);

CREATE POLICY "HOD can view department materials"
ON study_materials FOR SELECT
USING (
    course_id IN (
        SELECT id FROM courses 
        WHERE department_id IN (
            SELECT department_id FROM hod_assignments 
            WHERE user_id = auth.uid() AND is_active = true
        )
    )
);

CREATE POLICY "HOD can approve/reject materials"
ON study_materials FOR UPDATE
USING (
    course_id IN (
        SELECT id FROM courses 
        WHERE department_id IN (
            SELECT department_id FROM hod_assignments 
            WHERE user_id = auth.uid() AND is_active = true
        )
    )
);

CREATE POLICY "Students can view approved materials"
ON study_materials FOR SELECT
USING (
    status = 'approved' AND
    course_id IN (
        SELECT course_id FROM enrollments 
        WHERE student_id IN (
            SELECT id FROM students WHERE user_id = auth.uid()
        )
    )
);

-- Department Announcements Policies
CREATE POLICY "HOD can manage department announcements"
ON department_announcements FOR ALL
USING (
    department_id IN (
        SELECT department_id FROM hod_assignments 
        WHERE user_id = auth.uid() AND is_active = true
    )
);

CREATE POLICY "Faculty can view department announcements"
ON department_announcements FOR SELECT
USING (
    is_active = true AND
    (target_audience IN ('all', 'faculty') OR
    department_id IN (
        SELECT department_id FROM staff WHERE user_id = auth.uid()
    ))
);

CREATE POLICY "Students can view relevant announcements"
ON department_announcements FOR SELECT
USING (
    is_active = true AND
    (target_audience IN ('all', 'students') OR
    target_course_id IN (
        SELECT course_id FROM enrollments 
        WHERE student_id IN (
            SELECT id FROM students WHERE user_id = auth.uid()
        )
    ))
);

-- Step 7: Insert sample data

-- Assign hod1 to Computer Science department
INSERT INTO hod_assignments (user_id, department_id) 
SELECT u.id, d.id 
FROM users u, departments d 
WHERE u.username = 'hod1' AND d.name = 'Computer Science'
ON CONFLICT (user_id, department_id) DO NOTHING;

-- Insert sample study materials
INSERT INTO study_materials (course_id, teacher_id, title, description, material_type, status)
SELECT 
    c.id,
    s.id,
    'Introduction to Data Structures',
    'Comprehensive notes covering arrays, linked lists, stacks, and queues',
    'notes',
    'pending'
FROM courses c
CROSS JOIN staff s
WHERE c.code = 'CSE101' AND s.email = 'teacher1@shivalik.edu'
ON CONFLICT DO NOTHING;

INSERT INTO study_materials (course_id, teacher_id, title, description, material_type, status)
SELECT 
    c.id,
    s.id,
    'Database Management Systems - Assignment 1',
    'Practice problems on normalization and ER diagrams',
    'assignment',
    'approved'
FROM courses c
CROSS JOIN staff s
WHERE c.code = 'CSE102' AND s.email = 'teacher2@shivalik.edu'
ON CONFLICT DO NOTHING;

INSERT INTO study_materials (course_id, teacher_id, title, description, material_type, status)
SELECT 
    c.id,
    s.id,
    'Operating Systems Video Lectures',
    'Video series on process management and scheduling',
    'video',
    'pending'
FROM courses c
CROSS JOIN staff s
WHERE c.code = 'CSE103' AND s.email = 'teacher3@shivalik.edu'
ON CONFLICT DO NOTHING;

-- Insert sample department announcements
INSERT INTO department_announcements (department_id, created_by, title, content, target_audience, priority)
SELECT 
    d.id,
    u.id,
    'Mid-Semester Examination Schedule',
    'The mid-semester examinations for all CSE courses will be conducted from March 15-20, 2024. Please check the detailed timetable on the notice board.',
    'all',
    'high'
FROM departments d
CROSS JOIN users u
WHERE d.name = 'Computer Science' AND u.username = 'hod1'
ON CONFLICT DO NOTHING;

INSERT INTO department_announcements (department_id, created_by, title, content, target_audience, priority)
SELECT 
    d.id,
    u.id,
    'Faculty Meeting - March 10',
    'All faculty members are requested to attend the department meeting on March 10, 2024 at 2:00 PM in Conference Room A.',
    'faculty',
    'normal'
FROM departments d
CROSS JOIN users u
WHERE d.name = 'Computer Science' AND u.username = 'hod1'
ON CONFLICT DO NOTHING;

INSERT INTO department_announcements (department_id, created_by, title, content, target_audience, priority, expires_at)
SELECT 
    d.id,
    u.id,
    'Workshop on Machine Learning',
    'A two-day workshop on Machine Learning fundamentals will be conducted on March 25-26. Registration is mandatory.',
    'students',
    'high',
    NOW() + INTERVAL '30 days'
FROM departments d
CROSS JOIN users u
WHERE d.name = 'Computer Science' AND u.username = 'hod1'
ON CONFLICT DO NOTHING;

-- Step 8: Create helpful views for HOD dashboard

-- View: Department Overview Stats
CREATE OR REPLACE VIEW hod_department_overview AS
SELECT 
    d.id as department_id,
    d.name as department_name,
    ha.user_id as hod_user_id,
    COUNT(DISTINCT s.id) as total_faculty,
    COUNT(DISTINCT c.id) as total_courses,
    COUNT(DISTINCT e.student_id) as total_students
FROM departments d
LEFT JOIN hod_assignments ha ON d.id = ha.department_id AND ha.is_active = true
LEFT JOIN staff s ON d.id = s.department_id
LEFT JOIN courses c ON d.id = c.department_id
LEFT JOIN enrollments e ON c.id = e.course_id
GROUP BY d.id, d.name, ha.user_id;

-- View: Pending Study Materials Count
CREATE OR REPLACE VIEW hod_pending_materials_count AS
SELECT 
    c.department_id,
    COUNT(*) as pending_count
FROM study_materials sm
JOIN courses c ON sm.course_id = c.id
WHERE sm.status = 'pending'
GROUP BY c.department_id;

-- Step 9: Create functions for common HOD operations

-- Function: Get department attendance average
CREATE OR REPLACE FUNCTION get_department_attendance_avg(dept_id UUID, start_date DATE, end_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    avg_attendance NUMERIC;
BEGIN
    SELECT AVG(
        CASE WHEN a.status = 'present' THEN 100.0 ELSE 0.0 END
    ) INTO avg_attendance
    FROM attendance a
    JOIN enrollments e ON a.enrollment_id = e.id
    JOIN courses c ON e.course_id = c.id
    WHERE c.department_id = dept_id
    AND a.date BETWEEN start_date AND end_date;
    
    RETURN COALESCE(avg_attendance, 0);
END;
$$ LANGUAGE plpgsql;

-- Function: Get at-risk students in department
CREATE OR REPLACE FUNCTION get_at_risk_students(dept_id UUID, attendance_threshold NUMERIC DEFAULT 75.0)
RETURNS TABLE (
    student_id UUID,
    student_name VARCHAR,
    attendance_percentage NUMERIC,
    courses_below_threshold INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.full_name,
        AVG(CASE WHEN a.status = 'present' THEN 100.0 ELSE 0.0 END) as attendance_pct,
        COUNT(DISTINCT e.course_id)::INTEGER as courses_count
    FROM students s
    JOIN enrollments e ON s.id = e.student_id
    JOIN courses c ON e.course_id = c.id
    LEFT JOIN attendance a ON e.id = a.enrollment_id
    WHERE c.department_id = dept_id
    GROUP BY s.id, s.full_name
    HAVING AVG(CASE WHEN a.status = 'present' THEN 100.0 ELSE 0.0 END) < attendance_threshold
    ORDER BY attendance_pct ASC;
END;
$$ LANGUAGE plpgsql;

-- Step 10: Grant necessary permissions
GRANT SELECT ON hod_department_overview TO authenticated;
GRANT SELECT ON hod_pending_materials_count TO authenticated;
GRANT EXECUTE ON FUNCTION get_department_attendance_avg TO authenticated;
GRANT EXECUTE ON FUNCTION get_at_risk_students TO authenticated;

-- ========================================
-- Setup Complete! 🎉
-- ========================================

-- Verification Queries:
-- SELECT * FROM hod_assignments;
-- SELECT * FROM study_materials;
-- SELECT * FROM department_announcements;
-- SELECT * FROM hod_department_overview;
-- SELECT * FROM hod_pending_materials_count;
