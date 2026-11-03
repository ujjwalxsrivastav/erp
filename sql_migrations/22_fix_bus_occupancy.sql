-- ============================================================
-- MIGRATION 22: Fix Bus Occupancy Mismatch
-- ============================================================

-- Recalculate and update the current_occupancy for all buses
-- based on the actual number of active, approved transport requests.

UPDATE transport_buses b
SET current_occupancy = (
    SELECT COUNT(*)
    FROM student_transport_requests r
    WHERE r.bus_id = b.id AND r.status = 'approved' AND r.is_active = true
);
