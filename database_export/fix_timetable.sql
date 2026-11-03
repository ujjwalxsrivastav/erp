-- ============================================
-- FIX: Insert timetable data
-- Run this in Supabase SQL Editor AFTER fix_subjects.sql
-- ============================================

-- First, let's get class IDs
-- Class 1A: 8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd
-- Class 1B: 7364690c-7a5b-4fdb-a546-64d07041d03a

-- Insert timetable for Class 1A (Year 1, Section A)
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number, class_id) VALUES
-- MONDAY
('Monday', 'Slot 1', '09:00', '10:30', 'SUB001', 'teacher1', 'Room 101', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Monday', 'Slot 2', '10:45', '12:15', 'SUB002', 'teacher2', 'Room 102', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Monday', 'Slot 3', '13:00', '14:30', 'SUB003', 'teacher3', 'Room 103', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Monday', 'Slot 4', '14:45', '16:15', 'SUB004', 'teacher4', 'Room 104', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),

-- TUESDAY
('Tuesday', 'Slot 1', '09:00', '10:30', 'SUB002', 'teacher2', 'Room 102', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Tuesday', 'Slot 2', '10:45', '12:15', 'SUB003', 'teacher3', 'Room 103', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Tuesday', 'Slot 3', '13:00', '14:30', 'SUB004', 'teacher4', 'Room 104', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Tuesday', 'Slot 4', '14:45', '16:15', 'SUB001', 'teacher1', 'Room 101', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),

-- WEDNESDAY
('Wednesday', 'Slot 1', '09:00', '10:30', 'SUB003', 'teacher3', 'Room 103', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Wednesday', 'Slot 2', '10:45', '12:15', 'SUB004', 'teacher4', 'Room 104', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Wednesday', 'Slot 3', '13:00', '14:30', 'SUB001', 'teacher1', 'Room 101', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Wednesday', 'Slot 4', '14:45', '16:15', 'SUB002', 'teacher2', 'Room 102', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),

-- THURSDAY
('Thursday', 'Slot 1', '09:00', '10:30', 'SUB004', 'teacher4', 'Room 104', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Thursday', 'Slot 2', '10:45', '12:15', 'SUB001', 'teacher1', 'Room 101', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Thursday', 'Slot 3', '13:00', '14:30', 'SUB002', 'teacher2', 'Room 102', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Thursday', 'Slot 4', '14:45', '16:15', 'SUB003', 'teacher3', 'Room 103', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),

-- FRIDAY
('Friday', 'Slot 1', '09:00', '10:30', 'SUB001', 'teacher1', 'Room 101', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Friday', 'Slot 2', '10:45', '12:15', 'SUB002', 'teacher2', 'Room 102', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Friday', 'Slot 3', '13:00', '14:30', 'SUB003', 'teacher3', 'Room 103', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd'),
('Friday', 'Slot 4', '14:45', '16:15', 'SUB004', 'teacher4', 'Room 104', '8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd')

ON CONFLICT DO NOTHING;

-- Insert timetable for Class 1B (Year 1, Section B)
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number, class_id) VALUES
-- MONDAY
('Monday', 'Slot 1', '09:00', '10:30', 'SUB002', 'teacher2', 'Room 201', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Monday', 'Slot 2', '10:45', '12:15', 'SUB001', 'teacher1', 'Room 202', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Monday', 'Slot 3', '13:00', '14:30', 'SUB004', 'teacher4', 'Room 203', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Monday', 'Slot 4', '14:45', '16:15', 'SUB003', 'teacher3', 'Room 204', '7364690c-7a5b-4fdb-a546-64d07041d03a'),

-- TUESDAY
('Tuesday', 'Slot 1', '09:00', '10:30', 'SUB003', 'teacher3', 'Room 201', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Tuesday', 'Slot 2', '10:45', '12:15', 'SUB004', 'teacher4', 'Room 202', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Tuesday', 'Slot 3', '13:00', '14:30', 'SUB001', 'teacher1', 'Room 203', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Tuesday', 'Slot 4', '14:45', '16:15', 'SUB002', 'teacher2', 'Room 204', '7364690c-7a5b-4fdb-a546-64d07041d03a'),

-- WEDNESDAY
('Wednesday', 'Slot 1', '09:00', '10:30', 'SUB004', 'teacher4', 'Room 201', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Wednesday', 'Slot 2', '10:45', '12:15', 'SUB003', 'teacher3', 'Room 202', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Wednesday', 'Slot 3', '13:00', '14:30', 'SUB002', 'teacher2', 'Room 203', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Wednesday', 'Slot 4', '14:45', '16:15', 'SUB001', 'teacher1', 'Room 204', '7364690c-7a5b-4fdb-a546-64d07041d03a'),

-- THURSDAY
('Thursday', 'Slot 1', '09:00', '10:30', 'SUB001', 'teacher1', 'Room 201', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Thursday', 'Slot 2', '10:45', '12:15', 'SUB002', 'teacher2', 'Room 202', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Thursday', 'Slot 3', '13:00', '14:30', 'SUB003', 'teacher3', 'Room 203', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Thursday', 'Slot 4', '14:45', '16:15', 'SUB004', 'teacher4', 'Room 204', '7364690c-7a5b-4fdb-a546-64d07041d03a'),

-- FRIDAY
('Friday', 'Slot 1', '09:00', '10:30', 'SUB002', 'teacher2', 'Room 201', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Friday', 'Slot 2', '10:45', '12:15', 'SUB001', 'teacher1', 'Room 202', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Friday', 'Slot 3', '13:00', '14:30', 'SUB004', 'teacher4', 'Room 203', '7364690c-7a5b-4fdb-a546-64d07041d03a'),
('Friday', 'Slot 4', '14:45', '16:15', 'SUB003', 'teacher3', 'Room 204', '7364690c-7a5b-4fdb-a546-64d07041d03a')

ON CONFLICT DO NOTHING;

-- Verify
SELECT COUNT(*) as total_timetable_entries FROM timetable;
