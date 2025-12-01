# Admin Panel Implementation Plan

## Requirements Summary (Hindi to English)
1. **Total Users** - Show correct data from backend (students + teachers count)
2. **Remove "Active Now"** - Replace with something useful
3. **System Analytics** - Show correct user distribution data from backend
4. **Add User Button** - Opens screen with options: Add Teacher, Add Staff, Add Student
5. **Add Teacher Flow**:
   - Auto-generate teacher ID (e.g., if last is teacher10, next should be teacher11)
   - Auto-generate password (same as teacher ID)
   - Admin can edit both
   - Teacher details form
   - Teacher role selection: Teacher, HOD, Class Coordinator, Dean
   - Save to backend in both `users` and `teacher_details` tables
   - Teacher should be able to login with generated credentials

## Database Tables
- `users` - For authentication (username, password, role)
- `teacher_details` - For teacher information (teacher_id, name, employee_id, subject, department, phone, email, qualification, role)

## Implementation Steps

### 1. Create Admin Service
- `lib/services/admin_service.dart`
- Methods:
  - `getTotalUsers()` - Get count of all users
  - `getStudentCount()` - Get count of students
  - `getTeacherCount()` - Get count of teachers  
  - `getStaffCount()` - Get count of staff
  - `getAdminCount()` - Get count of admins
  - `getNextTeacherId()` - Get next available teacher ID
  - `addTeacher()` - Add teacher to both tables

### 2. Update Admin Dashboard
- Fetch real data using admin service
- Replace "Active Now" with "Total Teachers" or "Pending Approvals"
- Update System Analytics with real counts

### 3. Create Add User Selection Screen
- `lib/features/admin/add_user_screen.dart`
- Three options: Add Teacher, Add Staff, Add Student

### 4. Create Add Teacher Screen
- `lib/features/admin/add_teacher_screen.dart`
- Auto-generate teacher ID and password
- Form fields: name, employee_id, subject, department, phone, email, qualification
- Role dropdown: Teacher, HOD, Class Coordinator, Dean
- Submit button to save to backend

### 5. Add Routes
- `/admin/add-user`
- `/admin/add-teacher`
- `/admin/add-staff` (future)
- `/admin/add-student` (future)

## Files to Create/Modify
1. ✅ Create: `lib/services/admin_service.dart`
2. ✅ Create: `lib/features/admin/add_user_screen.dart`
3. ✅ Create: `lib/features/admin/add_teacher_screen.dart`
4. ✅ Modify: `lib/features/dashboard/admin_dashboard.dart`
5. ✅ Modify: `lib/routes/app_router.dart`
