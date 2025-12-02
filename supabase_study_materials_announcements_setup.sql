-- Create study_materials table
CREATE TABLE IF NOT EXISTS study_materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    material_type TEXT NOT NULL, -- 'Notes', 'Slides', 'Reference', 'Book', 'Other'
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    file_url TEXT NOT NULL,
    year TEXT NOT NULL,
    section TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create announcements table
CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'Normal', -- 'High', 'Normal', 'Low'
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    year TEXT NOT NULL,
    section TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_study_materials_subject ON study_materials(subject_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_teacher ON study_materials(teacher_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_year_section ON study_materials(year, section);
CREATE INDEX IF NOT EXISTS idx_study_materials_created ON study_materials(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_announcements_subject ON announcements(subject_id);
CREATE INDEX IF NOT EXISTS idx_announcements_teacher ON announcements(teacher_id);
CREATE INDEX IF NOT EXISTS idx_announcements_year_section ON announcements(year, section);
CREATE INDEX IF NOT EXISTS idx_announcements_created ON announcements(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_priority ON announcements(priority);

-- Enable Row Level Security
ALTER TABLE study_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- RLS Policies for study_materials
-- Teachers can insert their own materials
CREATE POLICY "Teachers can insert study materials"
ON study_materials FOR INSERT
WITH CHECK (auth.uid()::text = teacher_id);

-- Teachers can view their own materials
CREATE POLICY "Teachers can view their study materials"
ON study_materials FOR SELECT
USING (auth.uid()::text = teacher_id);

-- Students can view materials for their year and section
CREATE POLICY "Students can view study materials"
ON study_materials FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM student_details
        WHERE student_id = auth.uid()::text
        AND year::text = study_materials.year
        AND section = study_materials.section
    )
);

-- RLS Policies for announcements
-- Teachers can insert announcements
CREATE POLICY "Teachers can insert announcements"
ON announcements FOR INSERT
WITH CHECK (auth.uid()::text = teacher_id);

-- Teachers can view their own announcements
CREATE POLICY "Teachers can view their announcements"
ON announcements FOR SELECT
USING (auth.uid()::text = teacher_id);

-- Students can view announcements for their year and section
CREATE POLICY "Students can view announcements"
ON announcements FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM student_details
        WHERE student_id = auth.uid()::text
        AND year::text = announcements.year
        AND section = announcements.section
    )
);

-- Create storage buckets (run these in Supabase Dashboard > Storage)
-- Note: These need to be created via Supabase Dashboard or API, not SQL
-- 1. Create bucket: study-materials (public)
-- 2. Create bucket: assignments (public) - if not already exists

-- Storage policies will need to be set in Supabase Dashboard:
-- For study-materials bucket:
--   - Allow authenticated users to upload
--   - Allow public read access
-- For assignments bucket:
--   - Allow authenticated users to upload
--   - Allow public read access
