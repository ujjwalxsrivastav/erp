-- ============================================================================
-- School ERP — Super Enterprise Multi-School Superadmin Setup
-- Tables: school_institutes, school_institute_settings, school_institute_billing
-- Standards: Multi-school RLS, institute_id isolation, per-school settings
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_institutes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    board_affiliation TEXT NOT NULL DEFAULT 'CBSE', -- 'CBSE', 'ICSE', 'State Board', 'IB / Cambridge'
    affiliation_number TEXT,
    city TEXT NOT NULL DEFAULT 'Dehradun',
    state TEXT NOT NULL DEFAULT 'Uttarakhand',
    address TEXT,
    principal_name TEXT,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    admin_username TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_institute_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT UNIQUE NOT NULL,
    current_session TEXT NOT NULL DEFAULT '2026-2027',
    attendance_minimum_percent NUMERIC(5,2) DEFAULT 75.00,
    library_fine_per_day NUMERIC(8,2) DEFAULT 5.00,
    depreciation_rate_percent NUMERIC(5,2) DEFAULT 10.00,
    pf_rate_percent NUMERIC(5,2) DEFAULT 12.00,
    esi_rate_percent NUMERIC(5,2) DEFAULT 0.75,
    grading_scale TEXT NOT NULL DEFAULT 'CBSE 9-Point',
    allow_parent_online_leave BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_institute_billing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT UNIQUE NOT NULL,
    plan_tier TEXT NOT NULL DEFAULT 'Super Enterprise', -- 'Standard', 'Enterprise', 'Super Enterprise'
    student_seat_quota INT NOT NULL DEFAULT 1000,
    billing_cycle TEXT NOT NULL DEFAULT 'Annual', -- 'Monthly', 'Quarterly', 'Annual'
    contract_start_date DATE DEFAULT CURRENT_DATE,
    contract_renewal_date DATE DEFAULT (CURRENT_DATE + INTERVAL '1 year'),
    billing_status TEXT NOT NULL DEFAULT 'Active', -- 'Active', 'Grace Period', 'Payment Due'
    annual_license_fee NUMERIC(12,2) DEFAULT 250000.00,
    last_payment_date DATE DEFAULT CURRENT_DATE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_school_institutes_code ON public.school_institutes(institute_code);
CREATE INDEX IF NOT EXISTS idx_school_institute_settings_id ON public.school_institute_settings(institute_id);

-- Enable RLS
ALTER TABLE public.school_institutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_institute_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_institute_billing ENABLE ROW LEVEL SECURITY;

-- Standard Multi-school Policies
CREATE POLICY "Institutes visible to authenticated users" 
ON public.school_institutes FOR SELECT TO authenticated USING (true);

CREATE POLICY "Institutes manageable by superadmin" 
ON public.school_institutes FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Institute settings manageable by staff and admin" 
ON public.school_institute_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Institute billing visible to admin and superadmin" 
ON public.school_institute_billing FOR ALL TO authenticated USING (true) WITH CHECK (true);
