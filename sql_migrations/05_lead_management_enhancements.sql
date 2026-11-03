-- ============================================================================
-- LEAD MANAGEMENT ENHANCEMENTS - Migration Script
-- ============================================================================
-- Run this after the initial lead_management_setup.sql
-- Features: Auto-assignment, Transfer, Activity Feed, SLA Monitoring
-- ============================================================================

-- ============================================================================
-- STEP 1: Create Counsellor Regions Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS counsellor_regions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    counsellor_id UUID NOT NULL REFERENCES counsellor_details(id) ON DELETE CASCADE,
    region_name VARCHAR(100) NOT NULL,
    states TEXT[] NOT NULL,  -- Array of state names
    is_default BOOLEAN DEFAULT false,  -- Fallback for unmatched states
    priority INTEGER DEFAULT 1,  -- Lower = higher priority for matching
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_counsellor_regions_counsellor ON counsellor_regions(counsellor_id);
CREATE INDEX IF NOT EXISTS idx_counsellor_regions_default ON counsellor_regions(is_default);

-- ============================================================================
-- STEP 2: Insert Default Region Mappings
-- ============================================================================

-- Get counsellor IDs and insert regions
DO $$
DECLARE
    v_counsellor1_id UUID;
    v_counsellor2_id UUID;
    v_counsellor3_id UUID;
    v_counsellor4_id UUID;
    v_counsellor5_id UUID;
BEGIN
    -- Get counsellor IDs
    SELECT id INTO v_counsellor1_id FROM counsellor_details WHERE user_id = 'counsellor1';
    SELECT id INTO v_counsellor2_id FROM counsellor_details WHERE user_id = 'counsellor2';
    SELECT id INTO v_counsellor3_id FROM counsellor_details WHERE user_id = 'counsellor3';
    SELECT id INTO v_counsellor4_id FROM counsellor_details WHERE user_id = 'counsellor4';
    SELECT id INTO v_counsellor5_id FROM counsellor_details WHERE user_id = 'counsellor5';

    -- Counsellor 1: North Hills (HP, J&K, Ladakh)
    IF v_counsellor1_id IS NOT NULL THEN
        INSERT INTO counsellor_regions (counsellor_id, region_name, states, priority)
        VALUES (v_counsellor1_id, 'North Hills', 
                ARRAY['Himachal Pradesh', 'Jammu & Kashmir', 'Jammu and Kashmir', 'Ladakh', 'HP', 'J&K'], 1)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Counsellor 2: North Plains (Punjab, Haryana, Delhi, Chandigarh)
    IF v_counsellor2_id IS NOT NULL THEN
        INSERT INTO counsellor_regions (counsellor_id, region_name, states, priority)
        VALUES (v_counsellor2_id, 'North Plains', 
                ARRAY['Punjab', 'Haryana', 'Delhi', 'Chandigarh', 'New Delhi'], 1)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Counsellor 3: Uttarakhand
    IF v_counsellor3_id IS NOT NULL THEN
        INSERT INTO counsellor_regions (counsellor_id, region_name, states, priority)
        VALUES (v_counsellor3_id, 'Uttarakhand', 
                ARRAY['Uttarakhand', 'Uttaranchal'], 1)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Counsellor 4: Central/West (UP, Rajasthan, MP, Gujarat)
    IF v_counsellor4_id IS NOT NULL THEN
        INSERT INTO counsellor_regions (counsellor_id, region_name, states, priority)
        VALUES (v_counsellor4_id, 'Central West', 
                ARRAY['Uttar Pradesh', 'UP', 'Rajasthan', 'Madhya Pradesh', 'MP', 'Gujarat', 'Chhattisgarh'], 1)
        ON CONFLICT DO NOTHING;
    END IF;

    -- Counsellor 5: East/South (All others - Default)
    IF v_counsellor5_id IS NOT NULL THEN
        INSERT INTO counsellor_regions (counsellor_id, region_name, states, is_default, priority)
        VALUES (v_counsellor5_id, 'East South', 
                ARRAY['Bihar', 'Jharkhand', 'West Bengal', 'Odisha', 'Maharashtra', 'Goa', 
                      'Karnataka', 'Kerala', 'Tamil Nadu', 'Andhra Pradesh', 'Telangana',
                      'Assam', 'Sikkim', 'Meghalaya', 'Arunachal Pradesh', 'Nagaland',
                      'Manipur', 'Mizoram', 'Tripura'], true, 99)
        ON CONFLICT DO NOTHING;
    END IF;

    RAISE NOTICE 'Region mappings created successfully';
END $$;

-- ============================================================================
-- STEP 3: Create Auto-Assignment Function
-- ============================================================================

CREATE OR REPLACE FUNCTION auto_assign_lead(p_lead_id UUID)
RETURNS UUID AS $$
DECLARE
    v_state TEXT;
    v_counsellor_id UUID;
    v_least_loaded_id UUID;
BEGIN
    -- Get the lead's state
    SELECT state INTO v_state FROM leads WHERE id = p_lead_id;
    
    -- If no state, use default counsellor
    IF v_state IS NULL OR v_state = '' THEN
        SELECT counsellor_id INTO v_counsellor_id 
        FROM counsellor_regions 
        WHERE is_default = true 
        ORDER BY priority LIMIT 1;
    ELSE
        -- Find counsellor whose region contains this state
        SELECT cr.counsellor_id INTO v_counsellor_id
        FROM counsellor_regions cr
        JOIN counsellor_details cd ON cr.counsellor_id = cd.id
        WHERE cd.is_active = true
          AND (
              v_state = ANY(cr.states) OR
              LOWER(v_state) = ANY(SELECT LOWER(unnest(cr.states)))
          )
        ORDER BY cr.priority
        LIMIT 1;
    END IF;
    
    -- If still no match, find least loaded active counsellor
    IF v_counsellor_id IS NULL THEN
        SELECT cd.id INTO v_counsellor_id
        FROM counsellor_details cd
        LEFT JOIN leads l ON l.assigned_counsellor_id = cd.id 
            AND l.status IN ('assigned', 'contacted', 'interested', 'followup', 'form_sent')
        WHERE cd.is_active = true
        GROUP BY cd.id, cd.max_active_leads
        HAVING COUNT(l.id) < cd.max_active_leads
        ORDER BY COUNT(l.id) ASC
        LIMIT 1;
    END IF;
    
    -- If we found a counsellor, assign the lead
    IF v_counsellor_id IS NOT NULL THEN
        UPDATE leads SET
            assigned_counsellor_id = v_counsellor_id,
            assigned_by = 'system_auto',
            assigned_at = NOW(),
            status = 'assigned',
            updated_at = NOW()
        WHERE id = p_lead_id;
        
        -- Log the auto-assignment
        INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, change_type, notes)
        VALUES (p_lead_id, 'new', 'assigned', 'system', 'auto_assignment', 
                'Lead auto-assigned based on region: ' || COALESCE(v_state, 'Unknown'));
        
        -- Update counsellor stats
        UPDATE counsellor_details SET
            total_leads_assigned = total_leads_assigned + 1,
            updated_at = NOW()
        WHERE id = v_counsellor_id;
    END IF;
    
    RETURN v_counsellor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 4: Update public_create_lead to Auto-Assign
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
    p_source_detail TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_lead_id UUID;
    v_priority TEXT := 'normal';
    v_assigned_counsellor UUID;
BEGIN
    -- Auto-set priority based on certain conditions
    IF LOWER(COALESCE(p_state, '')) = 'himachal pradesh' THEN
        v_priority := 'high';
    END IF;
    
    IF p_source = 'referral' THEN
        v_priority := 'high';
    END IF;
    
    -- Create the lead
    INSERT INTO leads (
        student_name, phone, email, city, state,
        preferred_course, preferred_batch,
        source, source_detail, priority
    ) VALUES (
        p_student_name, p_phone, p_email, p_city, p_state,
        COALESCE(p_preferred_course, 'Not Specified'), p_preferred_batch,
        p_source, p_source_detail, v_priority
    )
    RETURNING id INTO v_lead_id;
    
    -- Log initial status
    INSERT INTO lead_status_history (lead_id, new_status, changed_by, change_type, notes)
    VALUES (v_lead_id, 'new', 'system', 'created', 'Lead captured from ' || p_source);
    
    -- Auto-assign based on region
    v_assigned_counsellor := auto_assign_lead(v_lead_id);
    
    RETURN v_lead_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 5: Create Transfer Lead Function
-- ============================================================================

CREATE OR REPLACE FUNCTION transfer_lead(
    p_lead_id UUID,
    p_new_counsellor_id UUID,
    p_transferred_by TEXT,
    p_reason TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_old_counsellor_id UUID;
    v_old_counsellor_name TEXT;
    v_new_counsellor_name TEXT;
    v_current_status TEXT;
BEGIN
    -- Get current assignment and status
    SELECT assigned_counsellor_id, status INTO v_old_counsellor_id, v_current_status
    FROM leads WHERE id = p_lead_id;
    
    -- Get counsellor names for logging
    SELECT name INTO v_old_counsellor_name FROM counsellor_details WHERE id = v_old_counsellor_id;
    SELECT name INTO v_new_counsellor_name FROM counsellor_details WHERE id = p_new_counsellor_id;
    
    -- Update the lead (preserve current status)
    UPDATE leads SET
        assigned_counsellor_id = p_new_counsellor_id,
        assigned_by = p_transferred_by,
        assigned_at = NOW(),
        updated_at = NOW()
        -- Note: status is NOT changed
    WHERE id = p_lead_id;
    
    -- Log the transfer
    INSERT INTO lead_status_history (
        lead_id, old_status, new_status, changed_by, change_type, notes
    ) VALUES (
        p_lead_id, 
        v_current_status, 
        v_current_status,  -- Status preserved
        p_transferred_by, 
        'transfer',
        'Lead transferred from ' || COALESCE(v_old_counsellor_name, 'Unassigned') || 
        ' to ' || v_new_counsellor_name || 
        CASE WHEN p_reason IS NOT NULL THEN '. Reason: ' || p_reason ELSE '' END
    );
    
    -- Update old counsellor stats (decrement)
    IF v_old_counsellor_id IS NOT NULL THEN
        UPDATE counsellor_details SET
            total_leads_assigned = GREATEST(total_leads_assigned - 1, 0),
            updated_at = NOW()
        WHERE id = v_old_counsellor_id;
    END IF;
    
    -- Update new counsellor stats (increment)
    UPDATE counsellor_details SET
        total_leads_assigned = total_leads_assigned + 1,
        updated_at = NOW()
    WHERE id = p_new_counsellor_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 6: Create Activity Feed View
-- ============================================================================

CREATE OR REPLACE VIEW lead_activity_feed AS
SELECT 
    h.id,
    h.lead_id,
    l.student_name,
    l.phone,
    l.preferred_course,
    h.old_status,
    h.new_status,
    h.change_type,
    h.changed_by,
    h.notes,
    h.created_at,
    c.id as counsellor_id,
    c.name as counsellor_name,
    l.priority
FROM lead_status_history h
JOIN leads l ON h.lead_id = l.id
LEFT JOIN counsellor_details c ON l.assigned_counsellor_id = c.id
ORDER BY h.created_at DESC;

-- ============================================================================
-- STEP 7: Create SLA Violations View
-- ============================================================================

CREATE OR REPLACE VIEW sla_violations AS
SELECT 
    l.id,
    l.student_name,
    l.phone,
    l.email,
    l.preferred_course,
    l.status,
    l.priority,
    l.created_at,
    l.updated_at,
    l.next_followup_date,
    l.assigned_counsellor_id,
    c.name as counsellor_name,
    c.user_id as counsellor_user_id,
    CASE 
        WHEN l.status = 'new' AND l.created_at < NOW() - INTERVAL '8 hours' THEN 'critical_no_contact'
        WHEN l.status = 'new' AND l.created_at < NOW() - INTERVAL '4 hours' THEN 'warning_no_contact'
        WHEN l.status = 'assigned' AND l.assigned_at < NOW() - INTERVAL '4 hours' THEN 'warning_not_contacted'
        WHEN l.status = 'assigned' AND l.assigned_at < NOW() - INTERVAL '8 hours' THEN 'critical_not_contacted'
        WHEN l.next_followup_date IS NOT NULL AND l.next_followup_date < NOW() - INTERVAL '2 days' THEN 'critical_overdue'
        WHEN l.next_followup_date IS NOT NULL AND l.next_followup_date < NOW() THEN 'warning_overdue'
        WHEN l.updated_at < NOW() - INTERVAL '7 days' AND l.status NOT IN ('converted', 'trash', 'not_interested') THEN 'stale_lead'
        WHEN l.priority = 'high' AND l.updated_at < NOW() - INTERVAL '24 hours' AND l.status NOT IN ('converted', 'trash', 'not_interested') THEN 'critical_high_priority'
        ELSE NULL
    END as violation_type,
    CASE 
        WHEN l.status = 'new' AND l.created_at < NOW() - INTERVAL '8 hours' THEN 'Critical: Not contacted for 8+ hours'
        WHEN l.status = 'new' AND l.created_at < NOW() - INTERVAL '4 hours' THEN 'Warning: Not contacted for 4+ hours'
        WHEN l.status = 'assigned' AND l.assigned_at < NOW() - INTERVAL '8 hours' THEN 'Critical: Assigned but not contacted for 8+ hours'
        WHEN l.status = 'assigned' AND l.assigned_at < NOW() - INTERVAL '4 hours' THEN 'Warning: Assigned but not contacted for 4+ hours'
        WHEN l.next_followup_date IS NOT NULL AND l.next_followup_date < NOW() - INTERVAL '2 days' THEN 'Critical: Follow-up overdue by 2+ days'
        WHEN l.next_followup_date IS NOT NULL AND l.next_followup_date < NOW() THEN 'Warning: Follow-up overdue'
        WHEN l.updated_at < NOW() - INTERVAL '7 days' THEN 'Stale: No activity for 7+ days'
        WHEN l.priority = 'high' AND l.updated_at < NOW() - INTERVAL '24 hours' THEN 'Critical: High priority lead inactive for 24+ hours'
        ELSE NULL
    END as violation_message
FROM leads l
LEFT JOIN counsellor_details c ON l.assigned_counsellor_id = c.id
WHERE l.status NOT IN ('converted', 'trash', 'not_interested')
  AND (
    (l.status = 'new' AND l.created_at < NOW() - INTERVAL '4 hours') OR
    (l.status = 'assigned' AND l.assigned_at < NOW() - INTERVAL '4 hours') OR
    (l.next_followup_date IS NOT NULL AND l.next_followup_date < NOW()) OR
    (l.updated_at < NOW() - INTERVAL '7 days') OR
    (l.priority = 'high' AND l.updated_at < NOW() - INTERVAL '24 hours')
  );

-- ============================================================================
-- STEP 8: Create Function to Get Counsellor by Region
-- ============================================================================

CREATE OR REPLACE FUNCTION get_counsellor_by_state(p_state TEXT)
RETURNS TABLE (
    counsellor_id UUID,
    counsellor_name TEXT,
    region_name TEXT,
    is_default BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cr.counsellor_id,
        cd.name as counsellor_name,
        cr.region_name,
        cr.is_default
    FROM counsellor_regions cr
    JOIN counsellor_details cd ON cr.counsellor_id = cd.id
    WHERE cd.is_active = true
      AND (
          p_state = ANY(cr.states) OR
          LOWER(p_state) = ANY(SELECT LOWER(unnest(cr.states))) OR
          cr.is_default = true
      )
    ORDER BY 
        CASE WHEN p_state = ANY(cr.states) OR LOWER(p_state) = ANY(SELECT LOWER(unnest(cr.states))) 
             THEN 0 ELSE 1 END,
        cr.priority
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 9: Create Function to Get SLA Stats
-- ============================================================================

CREATE OR REPLACE FUNCTION get_sla_stats()
RETURNS TABLE (
    total_violations BIGINT,
    critical_count BIGINT,
    warning_count BIGINT,
    stale_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_violations,
        COUNT(*) FILTER (WHERE violation_type LIKE 'critical%')::BIGINT as critical_count,
        COUNT(*) FILTER (WHERE violation_type LIKE 'warning%')::BIGINT as warning_count,
        COUNT(*) FILTER (WHERE violation_type = 'stale_lead')::BIGINT as stale_count
    FROM sla_violations;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 10: RLS Policies for New Tables
-- ============================================================================

ALTER TABLE counsellor_regions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "counsellor_regions_select" ON counsellor_regions;
DROP POLICY IF EXISTS "counsellor_regions_insert" ON counsellor_regions;
DROP POLICY IF EXISTS "counsellor_regions_update" ON counsellor_regions;
DROP POLICY IF EXISTS "counsellor_regions_delete" ON counsellor_regions;

CREATE POLICY "counsellor_regions_select" ON counsellor_regions FOR SELECT USING (true);
CREATE POLICY "counsellor_regions_insert" ON counsellor_regions FOR INSERT WITH CHECK (true);
CREATE POLICY "counsellor_regions_update" ON counsellor_regions FOR UPDATE USING (true);
CREATE POLICY "counsellor_regions_delete" ON counsellor_regions FOR DELETE USING (true);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Lead Management Enhancements Applied Successfully!';
    RAISE NOTICE '📊 New Features:';
    RAISE NOTICE '   • Auto-assignment by region';
    RAISE NOTICE '   • Lead transfer with status preservation';
    RAISE NOTICE '   • Activity feed view';
    RAISE NOTICE '   • SLA violations monitoring';
    RAISE NOTICE '   • Region-counsellor mapping';
END $$;
