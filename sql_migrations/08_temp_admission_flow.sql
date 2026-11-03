-- ============================================================================
-- TEMPORARY STUDENT ADMISSION FLOW - Complete Migration
-- ============================================================================
-- Creates tables and functions for:
-- 1. Temporary student accounts (temp01, temp02, etc.)
-- 2. Dead admissions (rejected offers)
-- 3. Permanent ID generation (YYPBBSAS format)
-- 4. Auto-trigger on lead conversion
-- ============================================================================

-- ============================================================================
-- STEP 1: Programme & Course Code Tables
-- ============================================================================

-- Programme codes (1-9)
CREATE TABLE IF NOT EXISTS programme_codes (
    id SERIAL PRIMARY KEY,
    programme_name VARCHAR(100) UNIQUE NOT NULL,
    code CHAR(1) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert programme codes
INSERT INTO programme_codes (programme_name, code) VALUES
    ('B.Tech', '1'),
    ('COP', '2'),
    ('Management', '3'),
    ('B.Sc', '4'),
    ('Polytechnic', '5'),
    ('Education', '6'),
    ('Computer Application', '7')
ON CONFLICT (programme_name) DO NOTHING;

-- Course/Branch codes (01-99)
CREATE TABLE IF NOT EXISTS course_codes (
    id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) UNIQUE NOT NULL,
    code CHAR(2) NOT NULL UNIQUE,
    programme_id INTEGER REFERENCES programme_codes(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert course codes
INSERT INTO course_codes (course_name, code, programme_id) VALUES
    ('CSE', '01', (SELECT id FROM programme_codes WHERE code = '1')),
    ('CSE (AIML)', '02', (SELECT id FROM programme_codes WHERE code = '1')),
    ('CSE (DS)', '03', (SELECT id FROM programme_codes WHERE code = '1')),
    ('ECE', '04', (SELECT id FROM programme_codes WHERE code = '1')),
    ('ME', '05', (SELECT id FROM programme_codes WHERE code = '1')),
    ('CE', '06', (SELECT id FROM programme_codes WHERE code = '1')),
    ('B.Pharma', '07', (SELECT id FROM programme_codes WHERE code = '5')),
    ('D.Pharma', '08', (SELECT id FROM programme_codes WHERE code = '5')),
    ('BBA', '09', (SELECT id FROM programme_codes WHERE code = '3')),
    ('MBA', '10', (SELECT id FROM programme_codes WHERE code = '3')),
    ('B.Sc Agriculture', '11', (SELECT id FROM programme_codes WHERE code = '4')),
    ('B.Ed', '12', (SELECT id FROM programme_codes WHERE code = '6')),
    ('BCA', '13', (SELECT id FROM programme_codes WHERE code = '7')),
    ('Computer Science', '14', (SELECT id FROM programme_codes WHERE code = '7')),
    ('B.Sc IT', '15', (SELECT id FROM programme_codes WHERE code = '4')),
    ('B.Sc Animation & Multimedia', '16', (SELECT id FROM programme_codes WHERE code = '4')),
    ('M.Sc Agronomy', '17', (SELECT id FROM programme_codes WHERE code = '4')),
    ('M.Sc Horticulture', '18', (SELECT id FROM programme_codes WHERE code = '4'))
ON CONFLICT (course_name) DO NOTHING;

-- ============================================================================
-- STEP 2: Admission Sequence Tracker (for SAS - 001 to 999)
-- ============================================================================

CREATE TABLE IF NOT EXISTS admission_sequences (
    id SERIAL PRIMARY KEY,
    year CHAR(2) NOT NULL,           -- e.g., '25' for 2025
    programme_code CHAR(1) NOT NULL,  -- e.g., '1' for B.Tech
    course_code CHAR(2) NOT NULL,     -- e.g., '04' for ECE
    last_sequence INTEGER DEFAULT 0,  -- Last used sequence number
    UNIQUE(year, programme_code, course_code)
);

-- ============================================================================
-- STEP 3: Temporary Students Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS temporary_students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    temp_id VARCHAR(20) UNIQUE NOT NULL,  -- temp01, temp02, etc.
    lead_id UUID REFERENCES leads(id),
    admission_form_id UUID REFERENCES admission_forms(id),
    
    -- Basic Info (from admission form)
    student_name VARCHAR(100) NOT NULL,
    father_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(15) NOT NULL,
    dob DATE,
    gender VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    state VARCHAR(50),
    
    -- Course Info
    course VARCHAR(50) NOT NULL,
    programme VARCHAR(100),
    session VARCHAR(20),
    
    -- Marksheet URLs
    tenth_marksheet_url TEXT,
    twelfth_marksheet_url TEXT,
    
    -- Status
    offer_status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, rejected
    offer_sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    offer_response_at TIMESTAMP WITH TIME ZONE,
    
    -- Payment (for acceptance)
    acceptance_payment_id VARCHAR(100),
    acceptance_payment_amount DECIMAL(10,2) DEFAULT 25000,
    
    -- Assigned counsellor
    assigned_counsellor VARCHAR(100),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_temp_students_temp_id ON temporary_students(temp_id);
CREATE INDEX IF NOT EXISTS idx_temp_students_lead ON temporary_students(lead_id);
CREATE INDEX IF NOT EXISTS idx_temp_students_status ON temporary_students(offer_status);

-- ============================================================================
-- STEP 4: Dead Admissions Table (Rejected Offers)
-- ============================================================================

CREATE TABLE IF NOT EXISTS dead_admissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    temp_id VARCHAR(20),
    lead_id UUID,
    admission_form_id UUID,
    
    -- Student Info
    student_name VARCHAR(100),
    father_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(15),
    
    -- Course Info
    course VARCHAR(50),
    programme VARCHAR(100),
    session VARCHAR(20),
    
    -- Rejection Details
    rejection_reason TEXT,
    rejected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Assigned counsellor (for visibility)
    assigned_counsellor VARCHAR(100),
    
    -- Original timestamps
    original_created_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dead_admissions_counsellor ON dead_admissions(assigned_counsellor);
CREATE INDEX IF NOT EXISTS idx_dead_admissions_date ON dead_admissions(rejected_at);

-- ============================================================================
-- STEP 5: Temp ID Sequence
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS temp_student_seq START 1;

-- ============================================================================
-- STEP 6: Function to Generate Next Temp ID
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_temp_id()
RETURNS VARCHAR(20) AS $$
DECLARE
    next_num INTEGER;
    temp_id VARCHAR(20);
BEGIN
    next_num := nextval('temp_student_seq');
    temp_id := 'temp' || LPAD(next_num::TEXT, 2, '0');
    RETURN temp_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 7: Function to Generate Permanent ID (YYPBBSAS)
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_permanent_id(
    p_course VARCHAR,
    p_year INTEGER DEFAULT NULL
) RETURNS VARCHAR(8) AS $$
DECLARE
    v_year CHAR(2);
    v_programme_code CHAR(1);
    v_course_code CHAR(2);
    v_sequence INTEGER;
    v_permanent_id VARCHAR(8);
BEGIN
    -- Get year (default to current year)
    IF p_year IS NULL THEN
        v_year := SUBSTRING(EXTRACT(YEAR FROM NOW())::TEXT FROM 3 FOR 2);
    ELSE
        v_year := SUBSTRING(p_year::TEXT FROM 3 FOR 2);
    END IF;
    
    -- Get course code
    SELECT code INTO v_course_code
    FROM course_codes
    WHERE course_name = p_course OR course_name ILIKE '%' || p_course || '%'
    LIMIT 1;
    
    IF v_course_code IS NULL THEN
        -- Default to BCA if not found
        v_course_code := '13';
    END IF;
    
    -- Get programme code from course
    SELECT pc.code INTO v_programme_code
    FROM course_codes cc
    JOIN programme_codes pc ON cc.programme_id = pc.id
    WHERE cc.code = v_course_code
    LIMIT 1;
    
    IF v_programme_code IS NULL THEN
        v_programme_code := '7'; -- Default to Computer Application
    END IF;
    
    -- Get next sequence number
    INSERT INTO admission_sequences (year, programme_code, course_code, last_sequence)
    VALUES (v_year, v_programme_code, v_course_code, 1)
    ON CONFLICT (year, programme_code, course_code)
    DO UPDATE SET last_sequence = admission_sequences.last_sequence + 1
    RETURNING last_sequence INTO v_sequence;
    
    -- Build the permanent ID: YYPBBSAS (8 characters)
    v_permanent_id := v_year || v_programme_code || v_course_code || LPAD(v_sequence::TEXT, 3, '0');
    
    RETURN v_permanent_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 8: Trigger Function - Create Temp Student on Lead Conversion
-- ============================================================================

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
            assigned_counsellor
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
            v_counsellor_name
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


-- Create trigger
DROP TRIGGER IF EXISTS trigger_create_temp_student ON leads;
CREATE TRIGGER trigger_create_temp_student
    BEFORE UPDATE ON leads
    FOR EACH ROW
    EXECUTE FUNCTION create_temp_student_on_conversion();

-- ============================================================================
-- STEP 9: Function to Reject Offer (Move to Dead Admissions)
-- ============================================================================

CREATE OR REPLACE FUNCTION reject_offer(
    p_temp_id VARCHAR,
    p_reason TEXT DEFAULT 'Student rejected the offer'
) RETURNS BOOLEAN AS $$
DECLARE
    v_temp_student RECORD;
BEGIN
    -- Get temp student data
    SELECT * INTO v_temp_student
    FROM temporary_students
    WHERE temp_id = p_temp_id;
    
    IF v_temp_student IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Move to dead_admissions (without marksheets)
    INSERT INTO dead_admissions (
        temp_id, lead_id, admission_form_id,
        student_name, father_name, email, phone,
        course, programme, session,
        rejection_reason, assigned_counsellor,
        original_created_at
    ) VALUES (
        v_temp_student.temp_id,
        v_temp_student.lead_id,
        v_temp_student.admission_form_id,
        v_temp_student.student_name,
        v_temp_student.father_name,
        v_temp_student.email,
        v_temp_student.phone,
        v_temp_student.course,
        v_temp_student.programme,
        v_temp_student.session,
        p_reason,
        v_temp_student.assigned_counsellor,
        v_temp_student.created_at
    );
    
    -- Delete from temporary_students
    DELETE FROM temporary_students WHERE temp_id = p_temp_id;
    
    -- Delete user account
    DELETE FROM users WHERE username = p_temp_id;
    
    -- Update lead status
    UPDATE leads SET 
        status = 'not_interested',
        notes = COALESCE(notes, '') || E'\n[OFFER REJECTED] ' || p_reason,
        updated_at = NOW()
    WHERE id = v_temp_student.lead_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 10: Function to Accept Offer (Migrate to Permanent Student)
-- ============================================================================

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
    
    -- Insert into student_details (ONLY columns that exist in the table)
    INSERT INTO student_details (
        student_id,
        name,
        father_name,
        year,
        semester,
        department,
        section,
        created_at,
        updated_at
    ) VALUES (
        v_permanent_id,
        v_temp_student.student_name,
        v_temp_student.father_name,
        1,  -- First year
        1,  -- First semester
        COALESCE(v_temp_student.programme, v_temp_student.course, 'General'),  -- department (use programme, fallback to course, or 'General')
        'A', -- Default section
        NOW(),
        NOW()
    );
    
    -- Update lead status to admission_done
    UPDATE leads SET
        status = 'converted',
        permanent_student_id = v_permanent_id,
        notes = COALESCE(notes, '') || E'\n[ADMISSION DONE] Student ID: ' || v_permanent_id,
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

-- ============================================================================
-- STEP 11: Add columns to leads table if missing
-- ============================================================================

ALTER TABLE leads ADD COLUMN IF NOT EXISTS temp_student_id VARCHAR(20);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS permanent_student_id VARCHAR(20);

-- ============================================================================
-- STEP 12: Add columns to student_details if missing
-- ============================================================================
-- NOTE: These columns are NOT actually in the student_details table schema
-- The table only has: student_id, name, father_name, year, semester, department, section, profile_photo_url, created_at, updated_at
-- Commenting out to avoid confusion

-- ALTER TABLE student_details ADD COLUMN IF NOT EXISTS tenth_marksheet_url TEXT;
-- ALTER TABLE student_details ADD COLUMN IF NOT EXISTS twelfth_marksheet_url TEXT;
-- ALTER TABLE student_details ADD COLUMN IF NOT EXISTS admission_year INTEGER;
-- ALTER TABLE student_details ADD COLUMN IF NOT EXISTS city VARCHAR(50);
-- ALTER TABLE student_details ADD COLUMN IF NOT EXISTS state VARCHAR(50);
-- ALTER TABLE student_details ADD COLUMN IF NOT EXISTS address TEXT;

-- ============================================================================
-- STEP 13: RLS Policies
-- ============================================================================

ALTER TABLE temporary_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE dead_admissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE admission_sequences ENABLE ROW LEVEL SECURITY;

-- Allow read access to all tables
CREATE POLICY "allow_select_temp_students" ON temporary_students FOR SELECT USING (true);
CREATE POLICY "allow_select_dead_admissions" ON dead_admissions FOR SELECT USING (true);
CREATE POLICY "allow_select_programme_codes" ON programme_codes FOR SELECT USING (true);
CREATE POLICY "allow_select_course_codes" ON course_codes FOR SELECT USING (true);
CREATE POLICY "allow_select_admission_sequences" ON admission_sequences FOR SELECT USING (true);

-- Allow insert/update for authenticated
CREATE POLICY "allow_insert_temp_students" ON temporary_students FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_temp_students" ON temporary_students FOR UPDATE USING (true);
CREATE POLICY "allow_insert_dead_admissions" ON dead_admissions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_insert_admission_sequences" ON admission_sequences FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_admission_sequences" ON admission_sequences FOR UPDATE USING (true);

-- ============================================================================
-- STEP 14: Helper Functions
-- ============================================================================

-- Get temp student details by temp_id
CREATE OR REPLACE FUNCTION get_temp_student_details(p_temp_id VARCHAR)
RETURNS SETOF temporary_students AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM temporary_students WHERE temp_id = p_temp_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get dead admissions for a counsellor
CREATE OR REPLACE FUNCTION get_dead_admissions_for_counsellor(p_counsellor VARCHAR)
RETURNS SETOF dead_admissions AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM dead_admissions 
    WHERE assigned_counsellor = p_counsellor
    ORDER BY rejected_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get all dead admissions (for dean)
CREATE OR REPLACE FUNCTION get_all_dead_admissions()
RETURNS SETOF dead_admissions AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM dead_admissions 
    ORDER BY rejected_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Temporary Admission Flow Migration Complete!';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tables Created:';
    RAISE NOTICE '   • programme_codes (7 programmes)';
    RAISE NOTICE '   • course_codes (18 courses)';
    RAISE NOTICE '   • temporary_students';
    RAISE NOTICE '   • dead_admissions';
    RAISE NOTICE '   • admission_sequences';
    RAISE NOTICE '';
    RAISE NOTICE '⚙️ Functions Created:';
    RAISE NOTICE '   • generate_temp_id() - Creates temp01, temp02...';
    RAISE NOTICE '   • generate_permanent_id() - Creates YYPBBSAS format';
    RAISE NOTICE '   • create_temp_student_on_conversion() - Auto trigger';
    RAISE NOTICE '   • reject_offer() - Moves to dead_admissions';
    RAISE NOTICE '   • accept_offer() - Migrates to student_details';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Flow:';
    RAISE NOTICE '   1. Mark lead as "converted" → temp student created';
    RAISE NOTICE '   2. Student logs in with tempXX/tempXX';
    RAISE NOTICE '   3. Accept (pay ₹25k) → permanent student ID';
    RAISE NOTICE '   4. Reject → data moved to dead_admissions';
END $$;
