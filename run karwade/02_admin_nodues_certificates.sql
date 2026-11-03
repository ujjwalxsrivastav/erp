-- ============================================================
-- 02: Admin Workflows — No-Dues, Certificates & Grievance Centre
-- Module: Admin (gap features)
-- Run in Supabase SQL Editor. Idempotent — safe to re-run.
-- Tables are self-contained: student_id stores the ERP username
-- (same convention as student_details.student_id / finance tables).
-- ============================================================

-- ------------------------------------------------------------
-- 1. NO-DUES REQUESTS (one per student per exit event)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nodues_requests (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id   TEXT NOT NULL,
    reason       TEXT NOT NULL DEFAULT 'completion'
                 CHECK (reason IN ('completion', 'tc', 'withdrawal', 'degree')),
    status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'in_progress', 'cleared', 'rejected')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE nodues_requests IS 'Admin: No-Dues case opened for a student (course completion / TC / withdrawal / degree). Cleared only when all rows in nodues_clearances are clear.';
COMMENT ON COLUMN nodues_requests.student_id IS 'ERP username of the student (matches student_details.student_id).';
COMMENT ON COLUMN nodues_requests.reason IS 'completion | tc | withdrawal | degree';

-- ------------------------------------------------------------
-- 2. NO-DUES DEPARTMENT CLEARANCES (9 departments per request)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nodues_clearances (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  UUID NOT NULL REFERENCES nodues_requests(id) ON DELETE CASCADE,
    department  TEXT NOT NULL
                CHECK (department IN ('library', 'hostel', 'transport', 'laboratory',
                                      'examination', 'finance', 'store', 'it', 'sports')),
    status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'clear', 'due')),
    due_amount  NUMERIC(12, 2) NOT NULL DEFAULT 0,
    remarks     TEXT,
    cleared_by  TEXT,
    cleared_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (request_id, department)
);

COMMENT ON TABLE nodues_clearances IS 'Admin: per-department clearance rows for a No-Dues request. One row per department; a request auto-clears when every row is clear.';
COMMENT ON COLUMN nodues_clearances.due_amount IS 'Outstanding amount for this department (0 when clear).';

-- ------------------------------------------------------------
-- 3. CERTIFICATE REQUESTS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS certificate_requests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id      TEXT NOT NULL,
    certificate_type TEXT NOT NULL
                    CHECK (certificate_type IN ('bonafide', 'character', 'transfer', 'migration',
                                                'course_completion', 'provisional', 'transcript')),
    copies          INT NOT NULL DEFAULT 1 CHECK (copies > 0),
    delivery_mode   TEXT NOT NULL DEFAULT 'collect'
                    CHECK (delivery_mode IN ('collect', 'post', 'digilocker')),
    fee_amount      NUMERIC(12, 2) NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'requested'
                    CHECK (status IN ('requested', 'processing', 'approved', 'issued', 'rejected')),
    serial_no       TEXT UNIQUE,
    requested_by    TEXT,
    approved_by     TEXT,
    issued_at       TIMESTAMPTZ,
    remarks         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE certificate_requests IS 'Admin: student certificate requests (bonafide, character, TC, migration, completion, provisional, transcript). serial_no is generated on issue in CERT-YYYY-#### format.';
COMMENT ON COLUMN certificate_requests.serial_no IS 'Unique certificate serial, assigned only when status becomes issued. NULL until issued.';

-- ------------------------------------------------------------
-- 4. GRIEVANCE TICKETS (central grievance centre incl. UGC cells)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS grievance_tickets (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raised_by      TEXT NOT NULL,
    raised_by_role TEXT NOT NULL DEFAULT 'student',
    category       TEXT NOT NULL DEFAULT 'other'
                   CHECK (category IN ('academic', 'admission', 'examination', 'hostel', 'transport',
                                       'ragging', 'icc', 'sc_st', 'fee', 'infrastructure', 'other')),
    subject        TEXT NOT NULL,
    description    TEXT,
    status         TEXT NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open', 'in_progress', 'resolved', 'escalated', 'closed')),
    sla_due_at     TIMESTAMPTZ,
    assigned_to    TEXT,
    resolution     TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at    TIMESTAMPTZ,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE grievance_tickets IS 'Admin: central grievance centre. Categories ragging / icc / sc_st map to the UGC-mandated cells; sla_due_at drives overdue escalation highlighting.';
COMMENT ON COLUMN grievance_tickets.sla_due_at IS 'Resolution deadline. A ticket past this time and not resolved/closed is treated as SLA overdue.';

-- ------------------------------------------------------------
-- 5. INDEXES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_nodues_requests_student ON nodues_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_nodues_requests_status ON nodues_requests(status);
CREATE INDEX IF NOT EXISTS idx_nodues_clearances_request ON nodues_clearances(request_id);
CREATE INDEX IF NOT EXISTS idx_nodues_clearances_status ON nodues_clearances(status);
CREATE INDEX IF NOT EXISTS idx_certificate_requests_student ON certificate_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_certificate_requests_status ON certificate_requests(status);
CREATE INDEX IF NOT EXISTS idx_grievance_tickets_status ON grievance_tickets(status);
CREATE INDEX IF NOT EXISTS idx_grievance_tickets_category ON grievance_tickets(category);
CREATE INDEX IF NOT EXISTS idx_grievance_tickets_sla ON grievance_tickets(sla_due_at);
CREATE INDEX IF NOT EXISTS idx_grievance_tickets_raised_by ON grievance_tickets(raised_by);

-- ------------------------------------------------------------
-- 6. ROW LEVEL SECURITY (repo-style permissive policies)
-- ------------------------------------------------------------
ALTER TABLE nodues_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "nodues_requests_all" ON nodues_requests;
CREATE POLICY "nodues_requests_all" ON nodues_requests
    FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE nodues_clearances ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "nodues_clearances_all" ON nodues_clearances;
CREATE POLICY "nodues_clearances_all" ON nodues_clearances
    FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE certificate_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "certificate_requests_all" ON certificate_requests;
CREATE POLICY "certificate_requests_all" ON certificate_requests
    FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE grievance_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "grievance_tickets_all" ON grievance_tickets;
CREATE POLICY "grievance_tickets_all" ON grievance_tickets
    FOR ALL USING (true) WITH CHECK (true);
