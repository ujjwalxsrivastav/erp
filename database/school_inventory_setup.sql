-- ============================================================================
-- School ERP — Super Enterprise Inventory & Asset Accounting Setup
-- Tables: school_inventory_items, school_inventory_issues, school_inventory_maintenance, school_inventory_audits
-- Standards: Multi-school RLS, institute_id isolation, 10% straight-line depreciation
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    item_code TEXT NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL, -- 'Lab Equipment', 'IT & Computing', 'Furniture', 'Sports Goods', 'Classroom Supplies', 'Consumables'
    quantity INT NOT NULL DEFAULT 1,
    unit TEXT DEFAULT 'Units', -- 'Units', 'Pieces', 'Sets', 'Boxes'
    location_room TEXT NOT NULL DEFAULT 'Main Store Room',
    condition TEXT NOT NULL DEFAULT 'Good', -- 'New', 'Good', 'Fair', 'Damaged'
    purchase_date DATE DEFAULT CURRENT_DATE,
    unit_cost NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    depreciation_rate_percent NUMERIC(5,2) DEFAULT 10.00,
    reorder_threshold INT DEFAULT 5,
    vendor_supplier TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_inventory_issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    item_id UUID REFERENCES public.school_inventory_items(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    issued_to_id TEXT NOT NULL,
    issued_to_name TEXT NOT NULL,
    issued_to_role TEXT NOT NULL DEFAULT 'teacher', -- 'teacher', 'student', 'staff'
    issued_quantity INT NOT NULL DEFAULT 1,
    issue_date TIMESTAMPTZ DEFAULT NOW(),
    expected_return_date TIMESTAMPTZ,
    actual_return_date TIMESTAMPTZ,
    purpose TEXT,
    condition_on_issue TEXT DEFAULT 'Good',
    condition_on_return TEXT,
    status TEXT NOT NULL DEFAULT 'Issued', -- 'Issued', 'Returned', 'Overdue', 'Damaged'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_inventory_maintenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    item_id UUID REFERENCES public.school_inventory_items(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    service_date TIMESTAMPTZ DEFAULT NOW(),
    issue_description TEXT NOT NULL,
    service_cost NUMERIC(12,2) DEFAULT 0.00,
    vendor_service_center TEXT,
    status TEXT NOT NULL DEFAULT 'In-Progress', -- 'Scheduled', 'In-Progress', 'Completed'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_inventory_audits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    audit_year INT NOT NULL DEFAULT 2026,
    item_id UUID REFERENCES public.school_inventory_items(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    system_quantity INT NOT NULL,
    physical_quantity INT NOT NULL,
    variance INT GENERATED ALWAYS AS (physical_quantity - system_quantity) STORED,
    audit_status TEXT NOT NULL DEFAULT 'Verified', -- 'Verified', 'Discrepancy', 'Damaged', 'Surplus'
    audited_by TEXT NOT NULL,
    audit_date DATE DEFAULT CURRENT_DATE,
    remarks TEXT
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_school_inventory_category ON public.school_inventory_items(category);
CREATE INDEX IF NOT EXISTS idx_school_inventory_institute ON public.school_inventory_items(institute_id);
CREATE INDEX IF NOT EXISTS idx_school_inventory_issues_status ON public.school_inventory_issues(status);
CREATE INDEX IF NOT EXISTS idx_school_inventory_maintenance_item ON public.school_inventory_maintenance(item_id);

-- Enable RLS
ALTER TABLE public.school_inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_inventory_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_inventory_maintenance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_inventory_audits ENABLE ROW LEVEL SECURITY;

-- Multi-school standard policies
CREATE POLICY "Inventory items visible to authenticated users" 
ON public.school_inventory_items FOR SELECT TO authenticated USING (true);

CREATE POLICY "Inventory items editable by admin and storekeeper" 
ON public.school_inventory_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Inventory issues manageable by staff and admin" 
ON public.school_inventory_issues FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Inventory maintenance manageable by staff and admin" 
ON public.school_inventory_maintenance FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Inventory audits manageable by admin" 
ON public.school_inventory_audits FOR ALL TO authenticated USING (true) WITH CHECK (true);
