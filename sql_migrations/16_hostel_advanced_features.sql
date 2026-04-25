-- ============================================================================
-- PHASE 4: HOSTEL ADVANCED FEATURES & PREMIUM MODULES
-- ============================================================================

-- 1. Add state and city to student_details
ALTER TABLE student_details
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS city VARCHAR(100);

-- 2. Add state, city, and bed_number to hostel_students
ALTER TABLE hostel_students
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS bed_number VARCHAR(10);

-- 3. Fix and Update accept_offer to handle facility mapping and new columns correctly
CREATE OR REPLACE FUNCTION accept_offer(
    p_temp_id VARCHAR,
    p_payment_id VARCHAR,
    p_payment_amount DECIMAL DEFAULT 25000
) RETURNS TABLE(
    success BOOLEAN,
    permanent_id VARCHAR,
    message TEXT
) AS $$
DECLARE
    v_temp_student RECORD;
    v_permanent_id VARCHAR(8);
    v_year INTEGER;
BEGIN
    -- Get temp student data
    SELECT * INTO v_temp_student
    FROM temporary_students
    WHERE temp_id = p_temp_id;
    
    IF v_temp_student IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::VARCHAR, 'Temporary student not found'::TEXT;
        RETURN;
    END IF;
    
    -- Generate permanent ID
    v_year := EXTRACT(YEAR FROM NOW())::INTEGER;
    v_permanent_id := generate_permanent_id(v_temp_student.course, v_year);
    
    -- Update user account FIRST: change username and role (MUST be before student_details insert due to FK constraint)
    UPDATE users SET
        username = v_permanent_id,
        password = v_permanent_id,  -- password = username
        role = 'student'
    WHERE username = p_temp_id;
    
    -- Insert into student_details
    INSERT INTO student_details (
        student_id, name, father_name, year, semester, department, section, created_at, updated_at, state, city
    ) VALUES (
        v_permanent_id, v_temp_student.student_name, v_temp_student.father_name, 1, 1, 
        COALESCE(v_temp_student.programme, v_temp_student.course, 'General'), 'A', NOW(), NOW(),
        v_temp_student.state, v_temp_student.city
    );
    
    -- MAP FACILITIES IF REQUIRED
    
    -- Hostel mapping
    IF v_temp_student.hostel_required THEN
        INSERT INTO hostel_students (student_id, student_name, status, payment_status, state, city)
        VALUES (v_permanent_id, v_temp_student.student_name, 'allocated', 'paid', v_temp_student.state, v_temp_student.city);
    END IF;

    -- Transport mapping
    IF v_temp_student.transportation_required THEN
        INSERT INTO transport_students (student_id, student_name, status, payment_status)
        VALUES (v_permanent_id, v_temp_student.student_name, 'active', 'paid');
    END IF;
    
    -- Update lead status to admission_done
    UPDATE leads SET
        status = 'converted',
        permanent_student_id = v_permanent_id,
        notes = COALESCE(notes, '') || E'\n[ADMISSION DONE] Student ID: ' || v_permanent_id || 
                CASE WHEN v_temp_student.hostel_required THEN ' [HOSTEL OPTED]' ELSE '' END ||
                CASE WHEN v_temp_student.transportation_required THEN ' [TRANSPORT OPTED]' ELSE '' END,
        updated_at = NOW()
    WHERE id = v_temp_student.lead_id;
    
    -- Clear marksheets from admission_forms to save storage
    UPDATE admission_forms SET
        tenth_marksheet_url = NULL,
        twelfth_marksheet_url = NULL,
        updated_at = NOW()
    WHERE id = v_temp_student.admission_form_id;
    
    -- Update temp student record before deleting
    UPDATE temporary_students SET
        offer_status = 'accepted',
        offer_response_at = NOW(),
        acceptance_payment_id = p_payment_id,
        acceptance_payment_amount = p_payment_amount
    WHERE temp_id = p_temp_id;
    
    -- Delete from temporary_students
    DELETE FROM temporary_students WHERE temp_id = p_temp_id;
    
    RETURN QUERY SELECT TRUE, v_permanent_id, 'Admission completed successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Premium Extra Feature 1: Digital Gatepass System
CREATE TABLE IF NOT EXISTS hostel_gatepasses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id VARCHAR(20) REFERENCES student_details(student_id) ON DELETE CASCADE,
    student_name VARCHAR(100) NOT NULL,
    reason TEXT NOT NULL,
    out_time TIMESTAMP WITH TIME ZONE NOT NULL,
    expected_in_time TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_in_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected, completed
    reviewed_by VARCHAR(50),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Premium Extra Feature 2: Night Attendance System
CREATE TABLE IF NOT EXISTS hostel_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES hostel_rooms(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    absent_students JSONB DEFAULT '[]', -- Array of student_ids
    marked_by VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(room_id, attendance_date)
);

-- 6. Premium Extra Feature 3: Disciplinary/Incident Logs
CREATE TABLE IF NOT EXISTS hostel_incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id VARCHAR(20) REFERENCES student_details(student_id) ON DELETE CASCADE,
    student_name VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    severity VARCHAR(20) DEFAULT 'low', -- low, medium, high, severe
    reported_by VARCHAR(50),
    incident_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- 7. Advanced RPC: Auto Allocate Hostel Rooms based on State/City Grouping
CREATE OR REPLACE FUNCTION auto_allocate_hostel_rooms()
RETURNS JSONB AS $$
DECLARE
    v_student RECORD;
    v_room RECORD;
    v_allocated_count INTEGER := 0;
    v_total_unallocated INTEGER := 0;
    v_bed_index INTEGER;
    v_bed_char VARCHAR(1);
BEGIN
    SELECT COUNT(*) INTO v_total_unallocated FROM hostel_students WHERE room_id IS NULL;

    -- Loop through unallocated students, grouped by state and city implicitly by order
    FOR v_student IN (
        SELECT * FROM hostel_students 
        WHERE room_id IS NULL 
        ORDER BY state NULLS LAST, city NULLS LAST
    ) LOOP
        -- Attempt to find a room that already has students from the same city/state AND is not full
        SELECT r.* INTO v_room
        FROM hostel_rooms r
        JOIN hostel_students hs ON hs.room_id = r.id
        WHERE hs.state = v_student.state 
          AND hs.city = v_student.city
          AND r.current_occupancy < r.capacity
          AND r.status = 'available'
        LIMIT 1;

        -- If not found, fall back to any room with same state
        IF v_room IS NULL THEN
            SELECT r.* INTO v_room
            FROM hostel_rooms r
            JOIN hostel_students hs ON hs.room_id = r.id
            WHERE hs.state = v_student.state 
              AND r.current_occupancy < r.capacity
              AND r.status = 'available'
            LIMIT 1;
        END IF;

        -- If still not found, just get ANY available room
        IF v_room IS NULL THEN
            SELECT r.* INTO v_room
            FROM hostel_rooms r
            WHERE r.current_occupancy < r.capacity
              AND r.status = 'available'
            LIMIT 1;
        END IF;

        -- If a room is available, allocate
        IF v_room IS NOT NULL THEN
            -- Assign a bed character (A, B, C...)
            v_bed_index := v_room.current_occupancy;
            v_bed_char := CHR(65 + v_bed_index); -- ASCII 65 is 'A'
            
            -- Update student
            UPDATE hostel_students 
            SET room_id = v_room.id, 
                room_number = v_room.room_number,
                block_name = v_room.hostel_id::text, -- Simplified for block name tracking
                bed_number = v_bed_char
            WHERE id = v_student.id;
            
            -- Update room occupancy
            UPDATE hostel_rooms
            SET current_occupancy = current_occupancy + 1,
                status = CASE WHEN current_occupancy + 1 >= capacity THEN 'full' ELSE 'available' END
            WHERE id = v_room.id;
            
            v_allocated_count := v_allocated_count + 1;
        END IF;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'allocated', v_allocated_count,
        'total_unallocated_before', v_total_unallocated
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update existing students without state and city with random dummy data or from temporary_students if achievable
-- Doing this safely:
UPDATE hostel_students hs
SET state = s.state, city = s.city
FROM temporary_students s
WHERE hs.student_id = s.temp_id AND (hs.state IS NULL OR hs.city IS NULL);

-- Grant privileges for new tables (both anon and authenticated)
GRANT ALL ON hostel_gatepasses TO anon, authenticated;
GRANT ALL ON hostel_attendance TO anon, authenticated;
GRANT ALL ON hostel_incidents TO anon, authenticated;

-- Apply Row Level Security
ALTER TABLE hostel_gatepasses ENABLE ROW LEVEL SECURITY;
ALTER TABLE hostel_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE hostel_incidents ENABLE ROW LEVEL SECURITY;

-- Idempotent RLS policies
DROP POLICY IF EXISTS gatepasses_policy ON hostel_gatepasses;
DROP POLICY IF EXISTS attendance_policy ON hostel_attendance;
DROP POLICY IF EXISTS incidents_policy ON hostel_incidents;

CREATE POLICY gatepasses_policy ON hostel_gatepasses FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY attendance_policy ON hostel_attendance FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY incidents_policy ON hostel_incidents FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- Grant execute on new RPC
GRANT EXECUTE ON FUNCTION auto_allocate_hostel_rooms TO anon, authenticated;

SELECT '✅ Migration 16 complete! Tables: hostel_gatepasses, hostel_attendance, hostel_incidents' AS status;
