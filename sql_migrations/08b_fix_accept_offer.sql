-- ============================================================================
-- FIX: Remove email column from accept_offer function
-- ============================================================================
-- This fixes the error: column "email" of relation "student_details" does not exist
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

-- Verification
DO $$
BEGIN
    RAISE NOTICE '✅ accept_offer function updated successfully!';
    RAISE NOTICE '   • Fixed to match actual student_details schema';
    RAISE NOTICE '   • Only inserts: student_id, name, father_name, year, semester, department, section';
    RAISE NOTICE '   • Removed non-existent columns: email, phone, dob, gender, address, city, state, course, session, marksheets';
END $$;
