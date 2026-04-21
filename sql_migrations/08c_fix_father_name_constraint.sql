-- ============================================================================
-- FIX: Allow NULL father_name in student_details
-- ============================================================================
-- Error: "null value in column "father_name" of relation "student_details" 
--         violates not-null constraint"
-- 
-- Root Cause: father_name is nullable in temporary_students but NOT NULL in
-- student_details. When a temp student is created from a lead conversion,
-- father_name may not be provided (e.g., counsellor didn't fill it in the
-- admission form). When accept_offer copies the data, it fails.
--
-- Fix: Make father_name nullable in student_details. Students can update
-- their profile later via the student profile screen.
-- ============================================================================

-- Step 1: Remove the NOT NULL constraint from father_name
ALTER TABLE student_details ALTER COLUMN father_name DROP NOT NULL;

-- Step 2: Update accept_offer to use COALESCE as a safety net
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
        v_temp_student.father_name,  -- Now allowed to be NULL
        1,  -- First year
        1,  -- First semester
        COALESCE(v_temp_student.programme, v_temp_student.course, 'General'),
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
    RAISE NOTICE '✅ father_name constraint fix applied!';
    RAISE NOTICE '   • student_details.father_name is now NULLABLE';
    RAISE NOTICE '   • accept_offer function updated';
    RAISE NOTICE '   • Students can fill in father_name later via profile';
END $$;
