-- ============================================================================
-- FIX: Create leads for orphan admission forms (forms with no linked lead)
-- ============================================================================
-- Problem: Demo admission form was inserting into admission_forms without
-- creating a lead first when the phone didn't match any existing lead.
-- This meant the dean couldn't see them and no counsellor was auto-assigned.
--
-- Fix: Create leads for any admission_forms that have lead_id = NULL,
-- then link them back.
-- ============================================================================

DO $$
DECLARE
    v_form RECORD;
    v_lead_id UUID;
    v_assigned_counsellor UUID;
BEGIN
    RAISE NOTICE '🔍 Searching for orphan admission forms (no linked lead)...';
    
    FOR v_form IN 
        SELECT * FROM admission_forms 
        WHERE lead_id IS NULL 
        ORDER BY created_at DESC
    LOOP
        RAISE NOTICE '  Found orphan form: % (phone: %)', v_form.student_name, v_form.phone;
        
        -- Check if a lead with this phone already exists
        SELECT id INTO v_lead_id FROM leads WHERE phone = v_form.phone LIMIT 1;
        
        IF v_lead_id IS NOT NULL THEN
            -- Link existing lead to the form
            RAISE NOTICE '    → Linking to existing lead: %', v_lead_id;
            
            UPDATE admission_forms 
            SET lead_id = v_lead_id, updated_at = NOW() 
            WHERE id = v_form.id;
            
            UPDATE leads SET 
                status = 'form_filled',
                admission_form_id = v_form.id,
                updated_at = NOW()
            WHERE id = v_lead_id;
        ELSE
            -- Create a new lead for this form
            INSERT INTO leads (
                student_name, phone, email, city, state,
                preferred_course, source, source_detail, priority,
                status, admission_form_id
            ) VALUES (
                v_form.student_name,
                v_form.phone,
                v_form.email,
                v_form.city,
                v_form.state,
                COALESCE(v_form.course, 'Not Specified'),
                'admission_form',
                'Created from orphan admission form',
                'normal',
                'form_filled',
                v_form.id
            )
            RETURNING id INTO v_lead_id;
            
            RAISE NOTICE '    → Created new lead: %', v_lead_id;
            
            -- Link the form to the new lead
            UPDATE admission_forms 
            SET lead_id = v_lead_id, updated_at = NOW() 
            WHERE id = v_form.id;
            
            -- Log status history
            INSERT INTO lead_status_history (lead_id, new_status, changed_by, change_type, notes)
            VALUES (v_lead_id, 'form_filled', 'system', 'created', 
                    'Auto-created from orphan admission form submission');
            
            -- Auto-assign to a counsellor
            BEGIN
                v_assigned_counsellor := auto_assign_lead(v_lead_id);
                IF v_assigned_counsellor IS NOT NULL THEN
                    RAISE NOTICE '    → Auto-assigned to counsellor: %', v_assigned_counsellor;
                ELSE
                    RAISE NOTICE '    → No counsellor available for auto-assignment';
                END IF;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE '    → Auto-assignment failed: %', SQLERRM;
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Orphan admission forms fix complete!';
END $$;
