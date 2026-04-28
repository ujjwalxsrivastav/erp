-- ============================================================
-- MIGRATION 19: Conductor Accounts & Bus Attendance
-- ============================================================

-- 1. Drop existing role constraint and recreate it allowing conductor
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('student', 'teacher', 'admin', 'HR', 'hod', 'admissiondean', 'counsellor', 'temp_student', 'warden', 'transport_officer', 'conductor', 'superadmin'));

-- 2. Insert 6 conductor accounts (conductor1 to conductor6)
INSERT INTO users (username, password, role) VALUES 
('conductor1', 'conductor1', 'conductor'),
('conductor2', 'conductor2', 'conductor'),
('conductor3', 'conductor3', 'conductor'),
('conductor4', 'conductor4', 'conductor'),
('conductor5', 'conductor5', 'conductor'),
('conductor6', 'conductor6', 'conductor')
ON CONFLICT (username) DO UPDATE
  SET role = EXCLUDED.role,
      password = EXCLUDED.password;

-- 3. Add conductor mapping to buses
ALTER TABLE transport_buses ADD COLUMN IF NOT EXISTS conductor_username TEXT;

-- Assign conductors to buses (assuming bus_number 1 to 6 exist)
UPDATE transport_buses SET conductor_username = 'conductor1' WHERE bus_number = 1;
UPDATE transport_buses SET conductor_username = 'conductor2' WHERE bus_number = 2;
UPDATE transport_buses SET conductor_username = 'conductor3' WHERE bus_number = 3;
UPDATE transport_buses SET conductor_username = 'conductor4' WHERE bus_number = 4;
UPDATE transport_buses SET conductor_username = 'conductor5' WHERE bus_number = 5;
UPDATE transport_buses SET conductor_username = 'conductor6' WHERE bus_number = 6;

-- 4. Create transport_attendance table
CREATE TABLE IF NOT EXISTS transport_attendance (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bus_id UUID REFERENCES transport_buses(id) ON DELETE CASCADE,
  attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
  student_id TEXT NOT NULL,
  student_name TEXT NOT NULL,
  is_present BOOLEAN DEFAULT TRUE,
  marked_by TEXT, -- conductor username
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(bus_id, attendance_date, student_id)
);

-- 5. RLS Policies for transport_attendance
ALTER TABLE transport_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read transport attendance" ON transport_attendance FOR SELECT USING (true);
CREATE POLICY "Conductors can insert transport attendance" ON transport_attendance FOR INSERT WITH CHECK (true);
CREATE POLICY "Conductors can update transport attendance" ON transport_attendance FOR UPDATE USING (true);

-- Ensure anyone can read the new conductor column in transport_buses
-- (RLS already allows reading buses, but just keeping it documented)
