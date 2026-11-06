-- School ERP Super Enterprise: Hostel, Infirmary & Cafeteria Suite Setup
-- Conforming to Part C Item 3 (S3.1 - S3.4) & Part C-X4 (RLS Pattern)

-- ============================================================================
-- 1. HOSTEL MODULE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_hostels (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    name TEXT NOT NULL,
    gender TEXT NOT NULL DEFAULT 'Boys', -- Boys, Girls, Co-ed
    capacity INTEGER NOT NULL DEFAULT 100,
    warden_name TEXT NOT NULL,
    warden_contact TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_hostel_rooms (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    hostel_id TEXT NOT NULL REFERENCES public.school_hostels(id) ON DELETE CASCADE,
    room_number TEXT NOT NULL,
    floor INTEGER NOT NULL DEFAULT 1,
    capacity INTEGER NOT NULL DEFAULT 3,
    occupied INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'Available', -- Available, Full, Maintenance
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_hostel_allocations (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    hostel_id TEXT NOT NULL REFERENCES public.school_hostels(id) ON DELETE CASCADE,
    room_id TEXT NOT NULL REFERENCES public.school_hostel_rooms(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL, -- student username e.g. sstudent1
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    bed_number TEXT DEFAULT 'Bed 1',
    allocated_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'Active', -- Active, Vacated
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_gate_passes (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    hostel_id TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    out_time TIMESTAMPTZ NOT NULL,
    expected_in_time TIMESTAMPTZ NOT NULL,
    actual_in_time TIMESTAMPTZ,
    reason TEXT NOT NULL,
    parent_status TEXT NOT NULL DEFAULT 'Approved', -- Pending, Approved, Rejected
    warden_status TEXT NOT NULL DEFAULT 'Approved', -- Pending, Approved, Rejected
    parent_approved_at TIMESTAMPTZ,
    warden_approved_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'Active', -- Pending, Active, Closed, Rejected
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_hostel_attendance (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    hostel_id TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    room_number TEXT NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'Present', -- Present, NightOut, Absent
    marked_by TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 2. INFIRMARY MODULE (Sensitive Health Records)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_infirmary_records (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    student_id TEXT NOT NULL UNIQUE, -- username
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    blood_group TEXT DEFAULT 'B+',
    allergies TEXT DEFAULT 'None Reported',
    chronic_conditions TEXT DEFAULT 'None Reported',
    dietary_restrictions TEXT DEFAULT 'None',
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    medical_insurance_policy TEXT DEFAULT 'Standard Institutional Coverage',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_infirmary_visits (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    visit_time TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    symptoms TEXT NOT NULL,
    diagnosis TEXT NOT NULL,
    treatment TEXT NOT NULL,
    medicine_given TEXT DEFAULT 'Paracetamol / Rest',
    dosage TEXT DEFAULT 'Single Dose',
    temperature NUMERIC(4, 1) DEFAULT 98.6,
    admitted_to_bed BOOLEAN NOT NULL DEFAULT false,
    parent_notified BOOLEAN NOT NULL DEFAULT true,
    status TEXT NOT NULL DEFAULT 'Discharged', -- Under Observation, Discharged, Referred to Hospital
    handled_by TEXT NOT NULL DEFAULT 'Campus Nurse',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_medicine_stock (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Analgesic',
    unit TEXT NOT NULL DEFAULT 'Tablets',
    quantity INTEGER NOT NULL DEFAULT 100,
    minimum_alert_level INTEGER NOT NULL DEFAULT 20,
    expiry_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 3. CAFETERIA MODULE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_cafeteria_menus (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    day_of_week TEXT NOT NULL, -- Monday, Tuesday, ... Sunday
    meal_type TEXT NOT NULL, -- Breakfast, Lunch, Snacks, Dinner
    item_name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'Veg', -- Veg, Non-Veg
    price NUMERIC(8, 2) NOT NULL DEFAULT 50.00,
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_meal_plans (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    plan_name TEXT NOT NULL, -- Full Boarding Meal Plan, Day Scholar Lunch Plan
    monthly_fee NUMERIC(8, 2) NOT NULL DEFAULT 2500.00,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'Active', -- Active, Expired, Cancelled
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.school_canteen_orders (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    total_amount NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    paid_from_wallet BOOLEAN NOT NULL DEFAULT true,
    status TEXT NOT NULL DEFAULT 'Completed',
    order_time TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_hostel_alloc_student ON public.school_hostel_allocations (student_id);
CREATE INDEX IF NOT EXISTS idx_gate_passes_student ON public.school_gate_passes (student_id);
CREATE INDEX IF NOT EXISTS idx_infirmary_visits_student ON public.school_infirmary_visits (student_id);
CREATE INDEX IF NOT EXISTS idx_canteen_orders_student ON public.school_canteen_orders (student_id);

-- Enable RLS
ALTER TABLE public.school_hostels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_hostel_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_hostel_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_gate_passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_hostel_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_infirmary_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_infirmary_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_medicine_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_cafeteria_menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_canteen_orders ENABLE ROW LEVEL SECURITY;

-- Transparent Access Policies
CREATE POLICY "school_hostels_all" ON public.school_hostels FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_hostel_rooms_all" ON public.school_hostel_rooms FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_hostel_allocations_all" ON public.school_hostel_allocations FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_gate_passes_all" ON public.school_gate_passes FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_hostel_attendance_all" ON public.school_hostel_attendance FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_infirmary_records_all" ON public.school_infirmary_records FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_infirmary_visits_all" ON public.school_infirmary_visits FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_medicine_stock_all" ON public.school_medicine_stock FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_cafeteria_menus_all" ON public.school_cafeteria_menus FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_meal_plans_all" ON public.school_meal_plans FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY "school_canteen_orders_all" ON public.school_canteen_orders FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
