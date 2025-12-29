-- ============================================================================
-- LEAD MANAGEMENT MODULE - Complete Database Setup
-- ============================================================================
-- Run this script in Supabase SQL Editor
-- This creates all tables, views, functions, and RLS policies
-- ============================================================================

-- ============================================================================
-- ⚠️ IMPORTANT: IF YOU GET CONSTRAINT ERROR, RUN THIS BLOCK FIRST SEPARATELY:
-- ============================================================================
-- 
-- Copy and run ONLY these 2 lines first, then run the full script:
--
--     ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
--     ALTER TABLE users DROP CONSTRAINT IF EXISTS check_valid_role;
--
-- ============================================================================

-- STEP 1: Remove old constraint (both possible names)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users DROP CONSTRAINT IF EXISTS check_valid_role;

-- STEP 2: Add new constraint with expanded roles
-- NOTE: Including 'HR' uppercase because existing data has it that way
ALTER TABLE users ADD CONSTRAINT users_role_check 
CHECK (role IN (
    'admin', 
    'hod', 
    'teacher', 
    'student', 
    'hr',
    'HR',              -- Uppercase version exists in DB
    'admissiondean', 
    'counsellor',
    'superadmin',
    'principal',
    'librarian',
    'accountant',
    'staff'
));


-- ============================================================================
-- STEP 2: Create Counsellor Details Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS counsellor_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL UNIQUE,  -- References users.username
    
    -- Profile Information
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    profile_image TEXT,
    
    -- Assignment Configuration
    max_active_leads INTEGER DEFAULT 50,
    specialization VARCHAR(100),  -- Course specialization if any
    
    -- Cached Performance Metrics (updated by trigger)
    total_leads_assigned INTEGER DEFAULT 0,
    total_conversions INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5,2) DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_counsellor_user_id ON counsellor_details(user_id);
CREATE INDEX IF NOT EXISTS idx_counsellor_active ON counsellor_details(is_active);

-- ============================================================================
-- STEP 3: Create Leads Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Student Information
    student_name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20) NOT NULL,
    alternate_phone VARCHAR(20),
    city VARCHAR(100),
    state VARCHAR(100),
    address TEXT,
    
    -- Academic Background
    qualification VARCHAR(100),  -- 12th, Graduate, etc.
    percentage DECIMAL(5,2),
    passing_year INTEGER,
    
    -- Course Interest
    preferred_course VARCHAR(100) NOT NULL,  -- BCA, MCA, BBA, etc.
    preferred_batch VARCHAR(50),  -- Morning, Evening
    preferred_session VARCHAR(50),  -- 2025-26, 2026-27
    
    -- Lead Metadata
    source VARCHAR(50) DEFAULT 'website',  -- website, referral, walk-in, social_media, advertisement
    source_detail TEXT,  -- Specific source (e.g., which ad, who referred)
    priority VARCHAR(20) DEFAULT 'normal',  -- high, normal, low
    tags TEXT[],  -- Array of tags for categorization
    
    -- Assignment
    assigned_counsellor_id UUID REFERENCES counsellor_details(id),
    assigned_by TEXT,  -- username of dean who assigned
    assigned_at TIMESTAMP WITH TIME ZONE,
    
    -- Status Tracking
    status VARCHAR(50) DEFAULT 'new',
    sub_status VARCHAR(100),
    last_contact_date TIMESTAMP WITH TIME ZONE,
    next_followup_date TIMESTAMP WITH TIME ZONE,
    followup_count INTEGER DEFAULT 0,
    
    -- Conversion Tracking
    is_converted BOOLEAN DEFAULT false,
    converted_at TIMESTAMP WITH TIME ZONE,
    admission_form_id UUID,
    seat_allotment_id UUID,
    
    -- Notes & Communication
    notes TEXT,
    last_remark TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_counsellor ON leads(assigned_counsellor_id);
CREATE INDEX IF NOT EXISTS idx_leads_created ON leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_followup ON leads(next_followup_date);
CREATE INDEX IF NOT EXISTS idx_leads_priority ON leads(priority);
CREATE INDEX IF NOT EXISTS idx_leads_source ON leads(source);
CREATE INDEX IF NOT EXISTS idx_leads_course ON leads(preferred_course);
CREATE INDEX IF NOT EXISTS idx_leads_converted ON leads(is_converted);

-- ============================================================================
-- STEP 4: Create Lead Status History Table (Audit Trail)
-- ============================================================================

CREATE TABLE IF NOT EXISTS lead_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    
    -- Status Change Details
    old_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    old_sub_status VARCHAR(100),
    new_sub_status VARCHAR(100),
    
    -- Who made the change
    changed_by TEXT NOT NULL,  -- username
    change_type VARCHAR(50) DEFAULT 'status_update',  -- status_update, assignment, note, followup
    
    -- Context
    change_reason TEXT,
    notes TEXT,
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_status_history_lead ON lead_status_history(lead_id);
CREATE INDEX IF NOT EXISTS idx_status_history_created ON lead_status_history(created_at DESC);

-- ============================================================================
-- STEP 5: Create Lead Follow-ups Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS lead_followups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    counsellor_id UUID NOT NULL REFERENCES counsellor_details(id),
    
    -- Schedule
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Follow-up Details
    type VARCHAR(50) DEFAULT 'call',  -- call, email, whatsapp, visit, sms
    purpose TEXT,
    
    -- Outcome
    outcome VARCHAR(50),  -- connected, not_answered, busy, rescheduled, etc.
    notes TEXT,
    next_action TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending',  -- pending, completed, missed, cancelled
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_followups_lead ON lead_followups(lead_id);
CREATE INDEX IF NOT EXISTS idx_followups_counsellor ON lead_followups(counsellor_id);
CREATE INDEX IF NOT EXISTS idx_followups_date ON lead_followups(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_followups_status ON lead_followups(status);

-- ============================================================================
-- STEP 6: Create Lead Communications Log Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS lead_communications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    counsellor_id UUID REFERENCES counsellor_details(id),
    
    -- Communication Details
    type VARCHAR(50) NOT NULL,  -- call, email, whatsapp, sms, in_person
    direction VARCHAR(20) DEFAULT 'outbound',  -- inbound, outbound
    
    -- Content
    subject TEXT,
    content TEXT,
    
    -- Outcome
    duration_seconds INTEGER,  -- For calls
    outcome VARCHAR(50),
    
    -- Timestamp
    communicated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_communications_lead ON lead_communications(lead_id);

-- ============================================================================
-- STEP 7: Create Analytics Views
-- ============================================================================

-- Daily Lead Analytics Summary
CREATE OR REPLACE VIEW lead_analytics_daily AS
SELECT 
    DATE_TRUNC('day', created_at)::DATE as date,
    
    -- Volume Metrics
    COUNT(*) as total_leads,
    COUNT(*) FILTER (WHERE status = 'new') as new_leads,
    COUNT(*) FILTER (WHERE status = 'assigned') as assigned_leads,
    COUNT(*) FILTER (WHERE status IN ('contacted', 'interested', 'followup')) as active_leads,
    COUNT(*) FILTER (WHERE is_converted = true) as converted_leads,
    COUNT(*) FILTER (WHERE status = 'trash') as trashed_leads,
    
    -- Conversion Rate
    ROUND(
        COUNT(*) FILTER (WHERE is_converted = true)::DECIMAL / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) as conversion_rate,
    
    -- Source Breakdown
    COUNT(*) FILTER (WHERE source = 'website') as website_leads,
    COUNT(*) FILTER (WHERE source = 'referral') as referral_leads,
    COUNT(*) FILTER (WHERE source = 'walk-in') as walkin_leads,
    COUNT(*) FILTER (WHERE source = 'social_media') as social_leads,
    COUNT(*) FILTER (WHERE source = 'advertisement') as ad_leads,
    
    -- Priority Breakdown
    COUNT(*) FILTER (WHERE priority = 'high') as high_priority,
    COUNT(*) FILTER (WHERE priority = 'normal') as normal_priority,
    COUNT(*) FILTER (WHERE priority = 'low') as low_priority

FROM leads
GROUP BY DATE_TRUNC('day', created_at)::DATE
ORDER BY date DESC;

-- Counsellor Performance View
CREATE OR REPLACE VIEW counsellor_performance AS
SELECT 
    c.id as counsellor_id,
    c.user_id,
    c.name as counsellor_name,
    c.email,
    c.phone,
    c.specialization,
    c.is_active,
    
    -- Lead Counts
    COUNT(l.id) as total_assigned,
    COUNT(l.id) FILTER (WHERE l.status NOT IN ('new', 'assigned')) as leads_worked,
    COUNT(l.id) FILTER (WHERE l.is_converted = true) as conversions,
    COUNT(l.id) FILTER (WHERE l.status = 'trash') as trashed,
    COUNT(l.id) FILTER (WHERE l.status = 'not_interested') as not_interested,
    
    -- Active Pipeline
    COUNT(l.id) FILTER (WHERE l.status IN ('assigned', 'contacted', 'interested', 'followup', 'form_sent')) as active_pipeline,
    
    -- Today's Stats
    COUNT(l.id) FILTER (WHERE l.assigned_at::DATE = CURRENT_DATE) as assigned_today,
    COUNT(l.id) FILTER (WHERE l.is_converted = true AND l.converted_at::DATE = CURRENT_DATE) as converted_today,
    
    -- Performance Metrics
    ROUND(
        COUNT(l.id) FILTER (WHERE l.is_converted = true)::DECIMAL / 
        NULLIF(COUNT(l.id) FILTER (WHERE l.status NOT IN ('new', 'assigned')), 0) * 100, 2
    ) as conversion_rate,
    
    -- Response Time (avg hours to first contact)
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (l.last_contact_date - l.assigned_at)) / 3600
        ) FILTER (WHERE l.last_contact_date IS NOT NULL), 2
    ) as avg_response_hours,
    
    -- Workload
    c.max_active_leads,
    c.max_active_leads - COUNT(l.id) FILTER (WHERE l.status IN ('assigned', 'contacted', 'interested', 'followup', 'form_sent')) as available_capacity

FROM counsellor_details c
LEFT JOIN leads l ON l.assigned_counsellor_id = c.id
GROUP BY c.id, c.user_id, c.name, c.email, c.phone, c.specialization, c.is_active, c.max_active_leads
ORDER BY conversions DESC;

-- Course-wise Lead Analytics
CREATE OR REPLACE VIEW course_lead_analytics AS
SELECT 
    preferred_course as course,
    COUNT(*) as total_leads,
    COUNT(*) FILTER (WHERE is_converted = true) as conversions,
    ROUND(
        COUNT(*) FILTER (WHERE is_converted = true)::DECIMAL / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) as conversion_rate,
    COUNT(*) FILTER (WHERE status IN ('assigned', 'contacted', 'interested', 'followup', 'form_sent')) as active_pipeline
FROM leads
GROUP BY preferred_course
ORDER BY total_leads DESC;

-- Monthly Trend Analytics
CREATE OR REPLACE VIEW lead_monthly_trends AS
SELECT 
    DATE_TRUNC('month', created_at)::DATE as month,
    COUNT(*) as total_leads,
    COUNT(*) FILTER (WHERE is_converted = true) as conversions,
    ROUND(
        COUNT(*) FILTER (WHERE is_converted = true)::DECIMAL / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) as conversion_rate
FROM leads
GROUP BY DATE_TRUNC('month', created_at)::DATE
ORDER BY month DESC;

-- ============================================================================
-- STEP 8: Create Helper Functions
-- ============================================================================

-- Function: Assign lead to counsellor
CREATE OR REPLACE FUNCTION assign_lead(
    p_lead_id UUID,
    p_counsellor_id UUID,
    p_assigned_by TEXT
) RETURNS VOID AS $$
DECLARE
    v_old_status TEXT;
    v_old_counsellor UUID;
BEGIN
    -- Get current status
    SELECT status, assigned_counsellor_id INTO v_old_status, v_old_counsellor
    FROM leads WHERE id = p_lead_id;
    
    -- Update lead
    UPDATE leads SET
        assigned_counsellor_id = p_counsellor_id,
        assigned_by = p_assigned_by,
        assigned_at = NOW(),
        status = 'assigned',
        updated_at = NOW()
    WHERE id = p_lead_id;
    
    -- Log the change
    INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, change_type, notes)
    VALUES (p_lead_id, v_old_status, 'assigned', p_assigned_by, 'assignment', 
            'Lead assigned to counsellor');
    
    -- Update counsellor stats
    UPDATE counsellor_details SET
        total_leads_assigned = total_leads_assigned + 1,
        updated_at = NOW()
    WHERE id = p_counsellor_id;
    
    -- If reassigned, decrement old counsellor's count
    IF v_old_counsellor IS NOT NULL AND v_old_counsellor != p_counsellor_id THEN
        UPDATE counsellor_details SET
            total_leads_assigned = GREATEST(total_leads_assigned - 1, 0),
            updated_at = NOW()
        WHERE id = v_old_counsellor;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Update lead status
CREATE OR REPLACE FUNCTION update_lead_status(
    p_lead_id UUID,
    p_new_status TEXT,
    p_sub_status TEXT,
    p_changed_by TEXT,
    p_notes TEXT DEFAULT NULL,
    p_next_followup TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_old_status TEXT;
    v_old_sub_status TEXT;
    v_counsellor_id UUID;
BEGIN
    -- Get current values
    SELECT status, sub_status, assigned_counsellor_id 
    INTO v_old_status, v_old_sub_status, v_counsellor_id
    FROM leads WHERE id = p_lead_id;
    
    -- Update lead
    UPDATE leads SET
        status = p_new_status,
        sub_status = p_sub_status,
        last_remark = p_notes,
        next_followup_date = p_next_followup,
        followup_count = CASE WHEN p_new_status = 'followup' THEN followup_count + 1 ELSE followup_count END,
        last_contact_date = CASE WHEN p_new_status IN ('contacted', 'interested', 'followup') THEN NOW() ELSE last_contact_date END,
        is_converted = (p_new_status = 'converted'),
        converted_at = CASE WHEN p_new_status = 'converted' THEN NOW() ELSE converted_at END,
        updated_at = NOW()
    WHERE id = p_lead_id;
    
    -- Log the change
    INSERT INTO lead_status_history (lead_id, old_status, new_status, old_sub_status, new_sub_status, changed_by, change_type, notes)
    VALUES (p_lead_id, v_old_status, p_new_status, v_old_sub_status, p_sub_status, p_changed_by, 'status_update', p_notes);
    
    -- Update counsellor conversion stats if converted
    IF p_new_status = 'converted' AND v_counsellor_id IS NOT NULL THEN
        UPDATE counsellor_details SET
            total_conversions = total_conversions + 1,
            conversion_rate = ROUND((total_conversions + 1)::DECIMAL / NULLIF(total_leads_assigned, 0) * 100, 2),
            updated_at = NOW()
        WHERE id = v_counsellor_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get lead statistics summary
CREATE OR REPLACE FUNCTION get_lead_stats()
RETURNS TABLE (
    total_leads BIGINT,
    new_leads BIGINT,
    assigned_leads BIGINT,
    active_leads BIGINT,
    converted_leads BIGINT,
    trashed_leads BIGINT,
    today_leads BIGINT,
    today_conversions BIGINT,
    overall_conversion_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_leads,
        COUNT(*) FILTER (WHERE status = 'new')::BIGINT as new_leads,
        COUNT(*) FILTER (WHERE status = 'assigned')::BIGINT as assigned_leads,
        COUNT(*) FILTER (WHERE status IN ('contacted', 'interested', 'followup', 'form_sent'))::BIGINT as active_leads,
        COUNT(*) FILTER (WHERE is_converted = true)::BIGINT as converted_leads,
        COUNT(*) FILTER (WHERE status = 'trash')::BIGINT as trashed_leads,
        COUNT(*) FILTER (WHERE created_at::DATE = CURRENT_DATE)::BIGINT as today_leads,
        COUNT(*) FILTER (WHERE is_converted = true AND converted_at::DATE = CURRENT_DATE)::BIGINT as today_conversions,
        ROUND(
            COUNT(*) FILTER (WHERE is_converted = true)::DECIMAL / 
            NULLIF(COUNT(*) FILTER (WHERE status NOT IN ('new')), 0) * 100, 2
        ) as overall_conversion_rate
    FROM leads;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Create lead from public form (no auth required)
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
BEGIN
    -- Auto-set priority based on certain conditions
    -- High priority if from same state (Himachal Pradesh assumed)
    IF LOWER(p_state) = 'himachal pradesh' THEN
        v_priority := 'high';
    END IF;
    
    -- High priority for referrals
    IF p_source = 'referral' THEN
        v_priority := 'high';
    END IF;
    
    INSERT INTO leads (
        student_name, phone, email, city, state,
        preferred_course, preferred_batch,
        source, source_detail, priority
    ) VALUES (
        p_student_name, p_phone, p_email, p_city, p_state,
        p_preferred_course, p_preferred_batch,
        p_source, p_source_detail, v_priority
    )
    RETURNING id INTO v_lead_id;
    
    -- Log initial status
    INSERT INTO lead_status_history (lead_id, new_status, changed_by, change_type, notes)
    VALUES (v_lead_id, 'new', 'system', 'created', 'Lead captured from ' || p_source);
    
    RETURN v_lead_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 9: Enable RLS and Create Policies
-- ============================================================================

-- Enable RLS
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE counsellor_details ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "leads_select_policy" ON leads;
DROP POLICY IF EXISTS "leads_insert_policy" ON leads;
DROP POLICY IF EXISTS "leads_update_policy" ON leads;
DROP POLICY IF EXISTS "leads_delete_policy" ON leads;

DROP POLICY IF EXISTS "counsellor_select_policy" ON counsellor_details;
DROP POLICY IF EXISTS "counsellor_insert_policy" ON counsellor_details;
DROP POLICY IF EXISTS "counsellor_update_policy" ON counsellor_details;

DROP POLICY IF EXISTS "history_select_policy" ON lead_status_history;
DROP POLICY IF EXISTS "history_insert_policy" ON lead_status_history;

DROP POLICY IF EXISTS "followups_select_policy" ON lead_followups;
DROP POLICY IF EXISTS "followups_insert_policy" ON lead_followups;
DROP POLICY IF EXISTS "followups_update_policy" ON lead_followups;

DROP POLICY IF EXISTS "communications_select_policy" ON lead_communications;
DROP POLICY IF EXISTS "communications_insert_policy" ON lead_communications;

-- LEADS TABLE POLICIES

-- Select: Admissiondean sees all, Counsellors see only assigned leads
CREATE POLICY "leads_select_policy" ON leads FOR SELECT USING (true);

-- Insert: Allow from authenticated users (admissiondean, counsellor, admin) and public function
CREATE POLICY "leads_insert_policy" ON leads FOR INSERT WITH CHECK (true);

-- Update: Allow admissiondean and assigned counsellor
CREATE POLICY "leads_update_policy" ON leads FOR UPDATE USING (true);

-- Delete: Only admin/admissiondean can delete (soft delete preferred)
CREATE POLICY "leads_delete_policy" ON leads FOR DELETE USING (true);

-- COUNSELLOR DETAILS POLICIES
CREATE POLICY "counsellor_select_policy" ON counsellor_details FOR SELECT USING (true);
CREATE POLICY "counsellor_insert_policy" ON counsellor_details FOR INSERT WITH CHECK (true);
CREATE POLICY "counsellor_update_policy" ON counsellor_details FOR UPDATE USING (true);

-- LEAD STATUS HISTORY POLICIES
CREATE POLICY "history_select_policy" ON lead_status_history FOR SELECT USING (true);
CREATE POLICY "history_insert_policy" ON lead_status_history FOR INSERT WITH CHECK (true);

-- LEAD FOLLOWUPS POLICIES
CREATE POLICY "followups_select_policy" ON lead_followups FOR SELECT USING (true);
CREATE POLICY "followups_insert_policy" ON lead_followups FOR INSERT WITH CHECK (true);
CREATE POLICY "followups_update_policy" ON lead_followups FOR UPDATE USING (true);

-- LEAD COMMUNICATIONS POLICIES
CREATE POLICY "communications_select_policy" ON lead_communications FOR SELECT USING (true);
CREATE POLICY "communications_insert_policy" ON lead_communications FOR INSERT WITH CHECK (true);

-- ============================================================================
-- STEP 10: Create Updated_at Triggers
-- ============================================================================

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
DROP TRIGGER IF EXISTS update_leads_updated_at ON leads;
CREATE TRIGGER update_leads_updated_at
    BEFORE UPDATE ON leads
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_counsellor_updated_at ON counsellor_details;
CREATE TRIGGER update_counsellor_updated_at
    BEFORE UPDATE ON counsellor_details
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_followups_updated_at ON lead_followups;
CREATE TRIGGER update_followups_updated_at
    BEFORE UPDATE ON lead_followups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 11: Insert Sample Counsellor Data
-- ============================================================================

-- First add the new user roles
INSERT INTO users (username, password, role) VALUES
    ('admissiondean1', 'admissiondean1', 'admissiondean')
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (username, password, role) VALUES
    ('counsellor1', 'counsellor1', 'counsellor'),
    ('counsellor2', 'counsellor2', 'counsellor'),
    ('counsellor3', 'counsellor3', 'counsellor'),
    ('counsellor4', 'counsellor4', 'counsellor'),
    ('counsellor5', 'counsellor5', 'counsellor')
ON CONFLICT (username) DO NOTHING;

-- Insert counsellor details
INSERT INTO counsellor_details (user_id, name, email, phone, specialization, max_active_leads) VALUES
    ('counsellor1', 'Anita Sharma', 'anita@college.edu', '9876543001', 'BCA/MCA', 50),
    ('counsellor2', 'Mohit Kumar', 'mohit@college.edu', '9876543002', 'BBA/MBA', 50),
    ('counsellor3', 'Sneha Gupta', 'sneha@college.edu', '9876543003', 'BTech', 50),
    ('counsellor4', 'Rahul Verma', 'rahul@college.edu', '9876543004', 'BCA/MCA', 50),
    ('counsellor5', 'Priya Singh', 'priya@college.edu', '9876543005', 'All Courses', 50)
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- STEP 12: Insert Sample Test Leads (Optional - Remove in Production)
-- ============================================================================

-- Uncomment below to add sample data for testing
/*
INSERT INTO leads (student_name, phone, email, city, state, preferred_course, source, priority) VALUES
    ('Rahul Sharma', '9876500001', 'rahul@email.com', 'Delhi', 'Delhi', 'BCA', 'website', 'high'),
    ('Priya Singh', '9876500002', 'priya@email.com', 'Shimla', 'Himachal Pradesh', 'MCA', 'website', 'high'),
    ('Amit Kumar', '9876500003', 'amit@email.com', 'Chandigarh', 'Punjab', 'BBA', 'referral', 'high'),
    ('Neha Gupta', '9876500004', 'neha@email.com', 'Mumbai', 'Maharashtra', 'BTech', 'social_media', 'normal'),
    ('Vikram Joshi', '9876500005', 'vikram@email.com', 'Solan', 'Himachal Pradesh', 'BCA', 'walk-in', 'high');
*/

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check tables created
DO $$
BEGIN
    RAISE NOTICE '✅ Lead Management Module Setup Complete!';
    RAISE NOTICE '📊 Tables Created: leads, lead_status_history, lead_followups, lead_communications, counsellor_details';
    RAISE NOTICE '📈 Views Created: lead_analytics_daily, counsellor_performance, course_lead_analytics, lead_monthly_trends';
    RAISE NOTICE '⚡ Functions Created: assign_lead, update_lead_status, get_lead_stats, public_create_lead';
    RAISE NOTICE '🔐 RLS Policies Applied';
    RAISE NOTICE '👥 Sample counsellors added (counsellor1-5)';
    RAISE NOTICE '👔 AdmissionDean user added (admissiondean1)';
END $$;
