-- ============================================
-- SIMPLIFIED CLASS-BASED TIMETABLE SYSTEM
-- ============================================
-- No dependencies on departments table

-- Step 1: Create classes table (simplified - no department reference)
CREATE TABLE IF NOT EXISTS classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_name VARCHAR(50) NOT NULL UNIQUE, -- e.g., '1A', '1B', '2A', '2B', etc.
  year INTEGER NOT NULL CHECK (year BETWEEN 1 AND 4),
  section VARCHAR(1) NOT NULL CHECK (section IN ('A', 'B')),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(year, section)
);

-- Step 2: Add class_id column to timetable table (if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'timetable' AND column_name = 'class_id'
  ) THEN
    ALTER TABLE timetable ADD COLUMN class_id UUID REFERENCES classes(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Step 3: Drop old unique constraint if exists and add new one with class_id
ALTER TABLE timetable DROP CONSTRAINT IF EXISTS timetable_day_of_week_time_slot_key;
ALTER TABLE timetable DROP CONSTRAINT IF EXISTS timetable_unique_slot;
ALTER TABLE timetable ADD CONSTRAINT timetable_unique_slot 
  UNIQUE(class_id, day_of_week, time_slot);

-- Step 4: Add class_id to student_details table (if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'student_details' AND column_name = 'class_id'
  ) THEN
    ALTER TABLE student_details ADD COLUMN class_id UUID REFERENCES classes(id);
  END IF;
END $$;

-- Step 5: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_timetable_class ON timetable(class_id);
CREATE INDEX IF NOT EXISTS idx_student_details_class ON student_details(class_id);

-- Step 6: Enable RLS on classes table
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

-- Step 7: RLS Policies for classes (simplified - all authenticated users can read)
DROP POLICY IF EXISTS "Allow read access to all users" ON classes;
CREATE POLICY "Allow read access to all users" ON classes FOR SELECT 
TO authenticated
USING (true);

DROP POLICY IF EXISTS "HOD and Admin can manage classes" ON classes;
CREATE POLICY "HOD and Admin can manage classes" ON classes FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role IN ('admin', 'hod')
  )
);

-- Step 8: Insert 8 classes (4 years × 2 sections)
INSERT INTO classes (class_name, year, section) VALUES
  ('1A', 1, 'A'),
  ('1B', 1, 'B'),
  ('2A', 2, 'A'),
  ('2B', 2, 'B'),
  ('3A', 3, 'A'),
  ('3B', 3, 'B'),
  ('4A', 4, 'A'),
  ('4B', 4, 'B')
ON CONFLICT (class_name) DO NOTHING;

-- Step 9: Update existing students to assign them to classes
-- Assuming BT24CSE154-159 are in Year 1, Section A
UPDATE student_details 
SET class_id = (SELECT id FROM classes WHERE class_name = '1A' LIMIT 1)
WHERE student_id IN ('BT24CSE154', 'BT24CSE155', 'BT24CSE156', 'BT24CSE157', 'BT24CSE158', 'BT24CSE159')
AND class_id IS NULL;

-- Assuming BT24CSE160-164 are in Year 1, Section B
UPDATE student_details 
SET class_id = (SELECT id FROM classes WHERE class_name = '1B' LIMIT 1)
WHERE student_id IN ('BT24CSE160', 'BT24CSE161', 'BT24CSE162', 'BT24CSE163', 'BT24CSE164')
AND class_id IS NULL;

-- Step 10: Update existing timetable entries to assign to Class 1A
UPDATE timetable 
SET class_id = (SELECT id FROM classes WHERE class_name = '1A' LIMIT 1)
WHERE class_id IS NULL;

-- Step 11: Create sample timetable for Class 1B (copy from 1A with different rooms)
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number, class_id)
SELECT 
  day_of_week,
  time_slot,
  start_time,
  end_time,
  subject_id,
  teacher_id,
  CASE 
    WHEN room_number = 'Room 101' THEN 'Room 201'
    WHEN room_number = 'Room 102' THEN 'Room 202'
    WHEN room_number = 'Room 103' THEN 'Room 203'
    WHEN room_number = 'Room 104' THEN 'Room 204'
    WHEN room_number = 'Room 105' THEN 'Room 205'
    ELSE room_number
  END as room_number,
  (SELECT id FROM classes WHERE class_name = '1B' LIMIT 1) as class_id
FROM timetable
WHERE class_id = (SELECT id FROM classes WHERE class_name = '1A' LIMIT 1)
ON CONFLICT (class_id, day_of_week, time_slot) DO NOTHING;

-- Step 12: Create view for easy class timetable access
CREATE OR REPLACE VIEW class_timetable_view AS
SELECT 
  c.class_name,
  c.year,
  c.section,
  t.day_of_week,
  t.time_slot,
  t.start_time,
  t.end_time,
  s.subject_name,
  td.name as teacher_name,
  t.room_number,
  t.id as timetable_id,
  t.class_id
FROM timetable t
JOIN classes c ON t.class_id = c.id
JOIN subjects s ON t.subject_id = s.subject_id
JOIN teacher_details td ON t.teacher_id = td.teacher_id
ORDER BY c.class_name, 
  CASE t.day_of_week
    WHEN 'Monday' THEN 1
    WHEN 'Tuesday' THEN 2
    WHEN 'Wednesday' THEN 3
    WHEN 'Thursday' THEN 4
    WHEN 'Friday' THEN 5
  END,
  t.start_time;

-- Step 13: Grant permissions
GRANT SELECT ON class_timetable_view TO authenticated;

-- Verification queries
SELECT 'Classes created:' as info, class_name FROM classes ORDER BY year, section;
SELECT 'Timetable entries per class:' as info, class_name, COUNT(*) as entries 
FROM class_timetable_view 
GROUP BY class_name 
ORDER BY class_name;
SELECT 'Students per class:' as info, c.class_name, COUNT(sd.student_id) as student_count 
FROM classes c 
LEFT JOIN student_details sd ON c.id = sd.class_id 
GROUP BY c.class_name 
ORDER BY c.class_name;

-- Success message
SELECT '✅ Class-based timetable system setup complete!' as status;
