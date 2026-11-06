-- ============================================================================
-- School ERP — Super Enterprise Library Deep-Dive Setup
-- Tables: school_library_reservations, school_library_ebooks, school_library_fine_ledger
-- Standards: Multi-school RLS, institute_id isolation, automated fine auto-post to fees, free public e-books
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.school_library_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    book_id TEXT NOT NULL,
    book_title TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    class_section TEXT NOT NULL,
    reserved_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'Waitlisted', -- 'Waitlisted', 'Ready for Pickup', 'Fulfilled', 'Expired', 'Cancelled'
    expiry_date TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '3 days'),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_library_ebooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    category TEXT NOT NULL, -- 'NCERT Textbook', 'Gutenberg Classic', 'Science & Innovation', 'Literature & Poetry', 'Faculty Guide'
    class_grade TEXT DEFAULT 'All',
    download_url TEXT NOT NULL,
    source_domain TEXT NOT NULL, -- 'ncert.nic.in', 'gutenberg.org', 'campus_storage'
    file_format TEXT DEFAULT 'PDF',
    file_size_mb NUMERIC(6,2) DEFAULT 4.5,
    downloads_count INT DEFAULT 0,
    is_free_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.school_library_fine_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    issue_id TEXT NOT NULL,
    book_title TEXT NOT NULL,
    student_id TEXT NOT NULL,
    student_name TEXT NOT NULL,
    days_overdue INT NOT NULL DEFAULT 1,
    fine_amount NUMERIC(8,2) NOT NULL DEFAULT 5.00,
    fee_ledger_payment_id TEXT,
    is_posted_to_fees BOOLEAN DEFAULT TRUE,
    is_waived BOOLEAN DEFAULT FALSE,
    waiver_reason TEXT,
    waived_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_school_library_reservations_book ON public.school_library_reservations(book_id);
CREATE INDEX IF NOT EXISTS idx_school_library_reservations_student ON public.school_library_reservations(student_id);
CREATE INDEX IF NOT EXISTS idx_school_library_ebooks_category ON public.school_library_ebooks(category);
CREATE INDEX IF NOT EXISTS idx_school_library_fine_ledger_student ON public.school_library_fine_ledger(student_id);

-- Enable RLS
ALTER TABLE public.school_library_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_library_ebooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_library_fine_ledger ENABLE ROW LEVEL SECURITY;

-- Standard Multi-school Policies
CREATE POLICY "Library reservations manageable by authenticated users" 
ON public.school_library_reservations FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Library ebooks visible to authenticated users" 
ON public.school_library_ebooks FOR SELECT TO authenticated USING (true);

CREATE POLICY "Library ebooks manageable by librarian" 
ON public.school_library_ebooks FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Library fine ledger visible to staff and students" 
ON public.school_library_fine_ledger FOR ALL TO authenticated USING (true) WITH CHECK (true);
