-- ============================================================================
-- ADMISSION FORMS - Migration Script
-- ============================================================================
-- Creates table for storing student admission form data
-- Includes file storage setup and lead linking
-- ============================================================================

-- ============================================================================
-- STEP 1: Create Admission Forms Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS admission_forms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
    phone VARCHAR(15) NOT NULL,
    
    -- Personal Details
    student_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    dob DATE,
    gender VARCHAR(20),
    category VARCHAR(20) DEFAULT 'general',
    aadhar VARCHAR(12),
    address TEXT,
    city VARCHAR(50),
    state VARCHAR(50),
    
    -- Guardian Details
    father_name VARCHAR(100),
    father_occupation VARCHAR(100),
    mother_name VARCHAR(100),
    mother_occupation VARCHAR(100),
    guardian_contact VARCHAR(15),
    guardian_email VARCHAR(100),
    
    -- 10th Class Details
    tenth_school VARCHAR(200),
    tenth_board VARCHAR(50),
    tenth_year INTEGER,
    tenth_percentage VARCHAR(20),
    tenth_marksheet_url TEXT,
    
    -- 12th Class Details
    twelfth_school VARCHAR(200),
    twelfth_board VARCHAR(50),
    twelfth_stream VARCHAR(50),
    twelfth_year INTEGER,
    twelfth_percentage VARCHAR(20),
    twelfth_marksheet_url TEXT,
    
    -- Course Selection
    course VARCHAR(50),
    session VARCHAR(20),
    batch VARCHAR(20),
    
    -- Payment Details
    payment_id VARCHAR(100),
    payment_status VARCHAR(20) DEFAULT 'pending',
    payment_amount DECIMAL(10, 2) DEFAULT 1000,
    
    -- Verification
    is_verified BOOLEAN DEFAULT false,
    verified_by VARCHAR(100),
    verified_at TIMESTAMP WITH TIME ZONE,
    verification_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_admission_forms_phone ON admission_forms(phone);
CREATE INDEX IF NOT EXISTS idx_admission_forms_lead ON admission_forms(lead_id);
CREATE INDEX IF NOT EXISTS idx_admission_forms_verified ON admission_forms(is_verified);
CREATE INDEX IF NOT EXISTS idx_admission_forms_payment ON admission_forms(payment_status);

-- ============================================================================
-- STEP 2: Create Storage Bucket for Documents
-- ============================================================================

-- Note: Run this in Supabase Dashboard SQL or Storage settings
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('admission-documents', 'admission-documents', true);

-- ============================================================================
-- STEP 3: RLS Policies
-- ============================================================================

ALTER TABLE admission_forms ENABLE ROW LEVEL SECURITY;

-- Allow public insert (for form submission)
DROP POLICY IF EXISTS "admission_forms_insert" ON admission_forms;
CREATE POLICY "admission_forms_insert" ON admission_forms 
    FOR INSERT WITH CHECK (true);

-- Allow authenticated users to read
DROP POLICY IF EXISTS "admission_forms_select" ON admission_forms;
CREATE POLICY "admission_forms_select" ON admission_forms 
    FOR SELECT USING (true);

-- Allow authenticated users to update
DROP POLICY IF EXISTS "admission_forms_update" ON admission_forms;
CREATE POLICY "admission_forms_update" ON admission_forms 
    FOR UPDATE USING (true);

-- ============================================================================
-- STEP 4: Function to Get Form by Phone
-- ============================================================================

CREATE OR REPLACE FUNCTION get_admission_form_by_phone(p_phone TEXT)
RETURNS SETOF admission_forms AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM admission_forms 
    WHERE phone = p_phone 
    ORDER BY created_at DESC 
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 5: Function to Get Form by Lead ID
-- ============================================================================

CREATE OR REPLACE FUNCTION get_admission_form_by_lead(p_lead_id UUID)
RETURNS SETOF admission_forms AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM admission_forms 
    WHERE lead_id = p_lead_id 
    ORDER BY created_at DESC 
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 6: Trigger to Update Lead Status on Form Submit
-- ============================================================================

CREATE OR REPLACE FUNCTION update_lead_on_form_submit()
RETURNS TRIGGER AS $$
BEGIN
    -- Update lead status if lead_id is set
    IF NEW.lead_id IS NOT NULL THEN
        UPDATE leads SET
            status = 'form_filled',
            admission_form_id = NEW.id,
            updated_at = NOW()
        WHERE id = NEW.lead_id;
        
        -- Log status change
        INSERT INTO lead_status_history (lead_id, old_status, new_status, changed_by, change_type, notes)
        SELECT 
            NEW.lead_id,
            l.status,
            'form_filled',
            'system',
            'form_submitted',
            'Admission form submitted with payment'
        FROM leads l WHERE l.id = NEW.lead_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_lead_on_form ON admission_forms;
CREATE TRIGGER trigger_update_lead_on_form
    AFTER INSERT ON admission_forms
    FOR EACH ROW
    EXECUTE FUNCTION update_lead_on_form_submit();

-- ============================================================================
-- STEP 7: Function to Verify Form
-- ============================================================================

CREATE OR REPLACE FUNCTION verify_admission_form(
    p_form_id UUID,
    p_verified_by TEXT,
    p_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE admission_forms SET
        is_verified = true,
        verified_by = p_verified_by,
        verified_at = NOW(),
        verification_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_form_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Admission Forms Migration Applied!';
    RAISE NOTICE '📊 Features:';
    RAISE NOTICE '   • admission_forms table created';
    RAISE NOTICE '   • RLS policies for public insert, authenticated read/update';
    RAISE NOTICE '   • Auto-update lead status on form submission';
    RAISE NOTICE '   • Form verification function';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT: Create storage bucket manually:';
    RAISE NOTICE '   1. Go to Supabase Dashboard > Storage';
    RAISE NOTICE '   2. Create bucket: admission-documents';
    RAISE NOTICE '   3. Make it PUBLIC';
END $$;
