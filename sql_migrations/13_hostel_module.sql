-- ============================================================================
-- PHASE 3: HOSTEL MODULE - ROOM MAPPING & WARDEN DASHBOARD
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Update role constraint to include warden
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check 
CHECK (role IN ('student', 'teacher', 'admin', 'HR', 'hod', 'admissiondean', 'counsellor', 'temp_student', 'warden'));

-- 1. Create Warden User
INSERT INTO users (username, password, role)
VALUES ('warden1', 'warden1', 'warden')
ON CONFLICT (username) DO NOTHING;

-- 2. Hostel Definitions Table
CREATE TABLE IF NOT EXISTS hostels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    total_floors INTEGER DEFAULT 3,
    rooms_per_floor INTEGER DEFAULT 15,
    capacity_per_room INTEGER DEFAULT 3,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Room Definitions Table
CREATE TABLE IF NOT EXISTS hostel_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostel_id UUID REFERENCES hostels(id) ON DELETE CASCADE,
    room_number VARCHAR(20) NOT NULL,
    floor VARCHAR(20) NOT NULL, -- GF, FF, SF
    capacity INTEGER DEFAULT 3,
    current_occupancy INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'available', -- available, full, maintenance
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(hostel_id, room_number)
);

-- 4. Update hostel_students table to link with rooms
ALTER TABLE hostel_students 
ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES hostel_rooms(id),
ADD COLUMN IF NOT EXISTS hostel_id UUID REFERENCES hostels(id);

-- 5. Helper Function to populate rooms automatically
CREATE OR REPLACE FUNCTION populate_hostel_rooms(p_hostel_name VARCHAR)
RETURNS VOID AS $$
DECLARE
    v_hostel_id UUID;
    v_floor_prefix VARCHAR;
    v_floor_label VARCHAR;
    i INTEGER;
    f INTEGER;
BEGIN
    SELECT id INTO v_hostel_id FROM hostels WHERE name = p_hostel_name;
    
    -- Ground Floor (GF), First Floor (FF), Second Floor (SF)
    FOR f IN 0..2 LOOP
        IF f = 0 THEN v_floor_prefix := 'GF'; v_floor_label := 'Ground';
        ELSIF f = 1 THEN v_floor_prefix := 'FF'; v_floor_label := 'First';
        ELSE v_floor_prefix := 'SF'; v_floor_label := 'Second';
        END IF;
        
        FOR i IN 1..15 LOOP
            INSERT INTO hostel_rooms (hostel_id, room_number, floor, capacity)
            VALUES (v_hostel_id, v_floor_prefix || LPAD(i::text, 2, '0'), v_floor_label, 3)
            ON CONFLICT (hostel_id, room_number) DO NOTHING;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 6. Initial Data Seeding
INSERT INTO hostels (name, total_floors, rooms_per_floor, capacity_per_room)
VALUES 
('Newton Hostel', 3, 15, 3),
('CV Raman Hostel', 3, 15, 3)
ON CONFLICT (name) DO NOTHING;

-- Populate rooms for both hostels
SELECT populate_hostel_rooms('Newton Hostel');
SELECT populate_hostel_rooms('CV Raman Hostel');

-- 7. View for Warden Dashboard to see Room Details and Occupants
DROP VIEW IF EXISTS room_occupancy_view;
CREATE VIEW room_occupancy_view AS
SELECT 
    h.id as hostel_id,
    h.name as hostel_name,
    r.room_number,
    r.floor,
    r.capacity,
    r.current_occupancy,
    r.status,
    r.id as room_id,
    COALESCE(
        json_agg(
            json_build_object(
                'student_id', s.student_id,
                'student_name', s.student_name
            )
        ) FILTER (WHERE s.student_id IS NOT NULL),
        '[]'
    ) as occupants
FROM hostel_rooms r
JOIN hostels h ON r.hostel_id = h.id
LEFT JOIN hostel_students s ON s.room_id = r.id
GROUP BY h.id, h.name, r.room_number, r.floor, r.capacity, r.current_occupancy, r.status, r.id;
