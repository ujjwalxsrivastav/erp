-- ============================================================================
-- TRIGGER: SYNC ROOM OCCUPANCY
-- ============================================================================

-- Function to update current_occupancy in hostel_rooms
CREATE OR REPLACE FUNCTION sync_room_occupancy()
RETURNS TRIGGER AS $$
BEGIN
    -- If room was changed or student removed from room
    IF (TG_OP = 'UPDATE' AND OLD.room_id IS DISTINCT FROM NEW.room_id) OR TG_OP = 'DELETE' THEN
        IF OLD.room_id IS NOT NULL THEN
            UPDATE hostel_rooms 
            SET current_occupancy = (SELECT count(*) FROM hostel_students WHERE room_id = OLD.room_id)
            WHERE id = OLD.room_id;
        END IF;
    END IF;

    -- If room was assigned or student added to room
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.room_id IS NOT NULL THEN
        UPDATE hostel_rooms 
        SET current_occupancy = (SELECT count(*) FROM hostel_students WHERE room_id = NEW.room_id)
        WHERE id = NEW.room_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on hostel_students
DROP TRIGGER IF EXISTS trg_sync_room_occupancy ON hostel_students;
CREATE TRIGGER trg_sync_room_occupancy
AFTER INSERT OR UPDATE OR DELETE ON hostel_students
FOR EACH ROW EXECUTE FUNCTION sync_room_occupancy();

-- Initial sync for existing data
UPDATE hostel_rooms r
SET current_occupancy = (SELECT count(*) FROM hostel_students s WHERE s.room_id = r.id);
