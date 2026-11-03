-- ============================================================================
-- PHASE 2: FACILITY MAPPING & MANAGEMENT
-- ============================================================================

-- 1. Update temporary_students to include facility flags
ALTER TABLE temporary_students 
ADD COLUMN IF NOT EXISTS hostel_required BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS transportation_required BOOLEAN DEFAULT false;

-- 2. Create Hostel Management Table
CREATE TABLE IF NOT EXISTS hostel_students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id VARCHAR(20) REFERENCES student_details(student_id),
    student_name VARCHAR(100) NOT NULL,
    room_number VARCHAR(20),
    block_name VARCHAR(50),
    status VARCHAR(20) DEFAULT 'allocated', -- allocated, waitlisted, vacated
    payment_status VARCHAR(20) DEFAULT 'paid', -- paid as part of admission
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create Transport Management Table
CREATE TABLE IF NOT EXISTS transport_students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id VARCHAR(20) REFERENCES student_details(student_id),
    student_name VARCHAR(100) NOT NULL,
    route_name VARCHAR(100),
    pickup_point TEXT,
    bus_number VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active',
    payment_status VARCHAR(20) DEFAULT 'paid', -- paid as part of admission
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Update create_temp_student_on_conversion to pull flags from admission_forms
CREATE OR REPLACE FUNCTION create_temp_student_on_conversion()
RETURNS TRIGGER AS $$
DECLARE
    v_temp_id VARCHAR(20);
    v_admission_form RECORD;
    v_programme VARCHAR(100);
    v_counsellor_name VARCHAR(100);
BEGIN
    -- Only trigger when status changes TO 'converted'
    IF NEW.status = 'converted' AND (OLD.status IS NULL OR OLD.status != 'converted') THEN
        
        -- Generate temp ID
        v_temp_id := generate_temp_id();
        
        -- Get admission form data if exists
        SELECT * INTO v_admission_form
        FROM admission_forms
        WHERE lead_id = NEW.id
        ORDER BY created_at DESC
        LIMIT 1;
        
        -- Get counsellor name from counsellor_details
        SELECT name INTO v_counsellor_name
        FROM counsellor_details
        WHERE id = NEW.assigned_counsellor_id;
        
        -- Determine programme from course
        SELECT pc.programme_name INTO v_programme
        FROM course_codes cc
        JOIN programme_codes pc ON cc.programme_id = pc.id
        WHERE cc.course_name ILIKE '%' || COALESCE(v_admission_form.course, NEW.preferred_course, '') || '%'
        LIMIT 1;
        
        -- Create temporary student record
        INSERT INTO temporary_students (
            temp_id, lead_id, admission_form_id,
            student_name, father_name, email, phone, dob, gender, address, city, state,
            course, programme, session,
            tenth_marksheet_url, twelfth_marksheet_url,
            assigned_counsellor,
            hostel_required, transportation_required
        ) VALUES (
            v_temp_id,
            NEW.id,
            v_admission_form.id,
            COALESCE(v_admission_form.student_name, NEW.student_name),
            v_admission_form.father_name,
            COALESCE(v_admission_form.email, NEW.email),
            COALESCE(v_admission_form.phone, NEW.phone),
            v_admission_form.dob,
            v_admission_form.gender,
            v_admission_form.address,
            v_admission_form.city,
            v_admission_form.state,
            COALESCE(v_admission_form.course, NEW.preferred_course),
            v_programme,
            v_admission_form.session,
            v_admission_form.tenth_marksheet_url,
            v_admission_form.twelfth_marksheet_url,
            v_counsellor_name,
            COALESCE(v_admission_form.hostel_required, false),
            COALESCE(v_admission_form.transportation_required, false)
        );
        
        -- Create user account for temp student
        INSERT INTO users (username, password, role)
        VALUES (v_temp_id, v_temp_id, 'temp_student')
        ON CONFLICT (username) DO NOTHING;
        
        -- Update lead with temp_student_id
        NEW.temp_student_id := v_temp_id;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update accept_offer to map to facility tables
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
    
    -- Update user account FIRST
    UPDATE users SET
        username = v_permanent_id,
        password = v_permanent_id,
        role = 'student'
    WHERE username = p_temp_id;
    
    -- Insert into student_details
    INSERT INTO student_details (
        student_id, name, father_name, year, semester, department, section, created_at, updated_at
    ) VALUES (
        v_permanent_id, v_temp_student.student_name, v_temp_student.father_name, 1, 1, 
        COALESCE(v_temp_student.programme, v_temp_student.course, 'General'), 'A', NOW(), NOW()
    );

    -- MAP FACILITIES IF REQUIRED
    
    -- Hostel mapping
    IF v_temp_student.hostel_required THEN
        INSERT INTO hostel_students (student_id, student_name, status, payment_status)
        VALUES (v_permanent_id, v_temp_student.student_name, 'allocated', 'paid');
    END IF;

    -- Transport mapping
    IF v_temp_student.transportation_required THEN
        INSERT INTO transport_students (student_id, student_name, status, payment_status)
        VALUES (v_permanent_id, v_temp_student.student_name, 'active', 'paid');
    END IF;
    
    -- Update lead status
    UPDATE leads SET
        status = 'converted',
        permanent_student_id = v_permanent_id,
        notes = COALESCE(notes, '') || E'\n[ADMISSION DONE] Student ID: ' || v_permanent_id || 
                CASE WHEN v_temp_student.hostel_required THEN ' [HOSTEL OPTED]' ELSE '' END ||
                CASE WHEN v_temp_student.transportation_required THEN ' [TRANSPORT OPTED]' ELSE '' END,
        updated_at = NOW()
    WHERE id = v_temp_student.lead_id;
    
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
