-- ============================================================================
-- LEAD MANAGEMENT ENHANCEMENTS V2 - Migration Script
-- ============================================================================
-- Features: Manual Lead Tracking, Referral Sources, Duplicate Detection, Delete Lead
-- ============================================================================

-- ============================================================================
-- STEP 1: Add Referral Tracking Columns
-- ============================================================================

ALTER TABLE leads ADD COLUMN IF NOT EXISTS is_manual_entry BOOLEAN DEFAULT false;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS referral_type VARCHAR(50);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS referrer_name VARCHAR(100);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS referrer_id VARCHAR(50);
ALTER TABLE leads ADD COLUMN IF NOT EXISTS entered_by VARCHAR(100);

-- Index for analytics queries
CREATE INDEX IF NOT EXISTS idx_leads_manual_entry ON leads(is_manual_entry);
CREATE INDEX IF NOT EXISTS idx_leads_referral_type ON leads(referral_type);

-- ============================================================================
-- STEP 2: Create Unique Constraint on Phone (for duplicate detection)
-- ============================================================================

-- First remove any existing duplicates by keeping latest
DO $$
DECLARE
    dup_phone TEXT;
BEGIN
    -- Find and delete older duplicate entries
    FOR dup_phone IN 
        SELECT phone FROM leads 
        GROUP BY phone 
        HAVING COUNT(*) > 1
    LOOP
        DELETE FROM leads 
        WHERE phone = dup_phone 
        AND id NOT IN (
            SELECT id FROM leads 
            WHERE phone = dup_phone 
            ORDER BY created_at DESC 
            LIMIT 1
        );
        RAISE NOTICE 'Removed duplicates for phone: %', dup_phone;
    END LOOP;
END $$;

-- Now add unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_lead_phone'
    ) THEN
        ALTER TABLE leads ADD CONSTRAINT unique_lead_phone UNIQUE (phone);
        RAISE NOTICE '✅ Unique phone constraint added';
    END IF;
EXCEPTION
    WHEN duplicate_table THEN NULL;
    WHEN OTHERS THEN RAISE NOTICE 'Could not add unique constraint: %', SQLERRM;
END $$;

-- ============================================================================
-- STEP 3: Function to Check Duplicate Lead
-- ============================================================================

CREATE OR REPLACE FUNCTION check_duplicate_lead(p_phone TEXT)
RETURNS TABLE (
    lead_id UUID,
    student_name TEXT,
    phone TEXT,
    status TEXT,
    assigned_to TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.student_name,
        l.phone,
        l.status,
        cd.name,
        l.created_at
    FROM leads l
    LEFT JOIN counsellor_details cd ON l.assigned_counsellor_id = cd.id
    WHERE l.phone = p_phone;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 4: Update public_create_lead for Manual Entries
-- ============================================================================

CREATE OR REPLACE FUNCTION public_create_lead(
    p_student_name TEXT,
    p_phone TEXT,
    p_email TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_state TEXT DEFAULT NULL,
    p_preferred_course TEXT DEFAULT NULL,
    p_preferred_batch TEXT DEFAULT NULL,
    p_source TEXT DEFAULT 'website',
    p_source_detail TEXT DEFAULT NULL,
    p_is_manual_entry BOOLEAN DEFAULT false,
    p_referral_type TEXT DEFAULT NULL,
    p_referrer_name TEXT DEFAULT NULL,
    p_referrer_id TEXT DEFAULT NULL,
    p_entered_by TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_lead_id UUID;
    v_priority TEXT := 'normal';
    v_assigned_counsellor UUID;
    v_source_to_use TEXT;
BEGIN
    -- Check for duplicate
    IF EXISTS (SELECT 1 FROM leads WHERE phone = p_phone) THEN
        RAISE EXCEPTION 'DUPLICATE_LEAD: A lead with this phone number already exists';
    END IF;
    
    -- Auto-set priority based on certain conditions
    IF LOWER(COALESCE(p_state, '')) = 'himachal pradesh' THEN
        v_priority := 'high';
    END IF;
    
    IF p_source = 'referral' OR p_referral_type IN ('student', 'faculty') THEN
        v_priority := 'high';
    END IF;
    
    -- Determine correct source
    IF p_is_manual_entry THEN
        v_source_to_use := 'manual';
    ELSE
        v_source_to_use := p_source;
    END IF;
    
    -- Create the lead
    INSERT INTO leads (
        student_name, phone, email, city, state,
        preferred_course, preferred_batch,
        source, source_detail, priority,
        is_manual_entry, referral_type, referrer_name, referrer_id, entered_by
    ) VALUES (
        p_student_name, p_phone, p_email, p_city, p_state,
        COALESCE(p_preferred_course, 'Not Specified'), p_preferred_batch,
        v_source_to_use, p_source_detail, v_priority,
        p_is_manual_entry, p_referral_type, p_referrer_name, p_referrer_id, p_entered_by
    )
    RETURNING id INTO v_lead_id;
    
    -- Log initial status
    INSERT INTO lead_status_history (lead_id, new_status, changed_by, change_type, notes)
    VALUES (v_lead_id, 'new', COALESCE(p_entered_by, 'system'), 'created', 
            CASE 
                WHEN p_is_manual_entry THEN 'Manual entry by ' || COALESCE(p_entered_by, 'unknown') || 
                    CASE 
                        WHEN p_referral_type = 'student' THEN ' via student referral (' || COALESCE(p_referrer_name, 'unknown') || ')'
                        WHEN p_referral_type = 'faculty' THEN ' via faculty referral (' || COALESCE(p_referrer_name, 'unknown') || ')'
                        WHEN p_referral_type = 'website_call' THEN ' via website call'
                        ELSE ''
                    END
                ELSE 'Lead captured from ' || v_source_to_use
            END);
    
    -- Auto-assign based on region
    v_assigned_counsellor := auto_assign_lead(v_lead_id);
    
    RETURN v_lead_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 5: Create Delete Lead Function (Dean Only)
-- ============================================================================

CREATE OR REPLACE FUNCTION delete_lead_permanent(
    p_lead_id UUID,
    p_deleted_by TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_lead_name TEXT;
    v_lead_phone TEXT;
BEGIN
    -- Get lead info for logging
    SELECT student_name, phone INTO v_lead_name, v_lead_phone
    FROM leads WHERE id = p_lead_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lead not found';
    END IF;
    
    -- Delete followups first
    DELETE FROM lead_followups WHERE lead_id = p_lead_id;
    
    -- Delete status history
    DELETE FROM lead_status_history WHERE lead_id = p_lead_id;
    
    -- Delete the lead
    DELETE FROM leads WHERE id = p_lead_id;
    
    -- Log deletion (we could create an audit table for this in future)
    RAISE NOTICE 'Lead deleted: % (%) by %', v_lead_name, v_lead_phone, p_deleted_by;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Lead Management V2 Enhancements Applied!';
    RAISE NOTICE '📊 New Features:';
    RAISE NOTICE '   • Manual entry tracking with referral types';
    RAISE NOTICE '   • Duplicate phone detection';
    RAISE NOTICE '   • Permanent delete function for deans';
END $$;
