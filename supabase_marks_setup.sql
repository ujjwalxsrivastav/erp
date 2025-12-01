-- ============================================
-- MARKS & ASSIGNMENTS SYSTEM SETUP
-- ============================================

-- 1. Create assignments table
CREATE TABLE IF NOT EXISTS assignments (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  file_url TEXT,
  subject_id TEXT NOT NULL REFERENCES subjects(subject_id),
  teacher_id TEXT NOT NULL REFERENCES teacher_details(teacher_id),
  due_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create marks table
CREATE TABLE IF NOT EXISTS marks (
  id SERIAL PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES student_details(student_id),
  subject_id TEXT NOT NULL REFERENCES subjects(subject_id),
  exam_type TEXT NOT NULL CHECK (exam_type IN ('Mid Term', 'End Semester', 'Quiz', 'Assignment')),
  marks_obtained NUMERIC(5,2) NOT NULL,
  total_marks NUMERIC(5,2) NOT NULL,
  teacher_id TEXT NOT NULL REFERENCES teacher_details(teacher_id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(student_id, subject_id, exam_type)
);

-- Enable RLS
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE marks ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Assignments
-- Teachers can insert/update their own assignments
CREATE POLICY "Teachers can manage own assignments" ON assignments
  FOR ALL USING (teacher_id = current_user);

-- Students can view assignments for their subjects
CREATE POLICY "Students can view assignments" ON assignments
  FOR SELECT USING (true); -- Simplified for now, ideally check student_subjects

-- RLS Policies for Marks
-- Teachers can insert/update marks
CREATE POLICY "Teachers can manage marks" ON marks
  FOR ALL USING (teacher_id = current_user);

-- Students can view their own marks
CREATE POLICY "Students can view own marks" ON marks
  FOR SELECT USING (student_id = current_user);

-- Create storage bucket for assignments
-- Note: Run this in Supabase Dashboard > Storage if not exists
-- Bucket name: assignments
-- Public: Yes

COMMENT ON TABLE assignments IS 'Stores assignment details uploaded by teachers';
COMMENT ON TABLE marks IS 'Stores student marks for different exams';
