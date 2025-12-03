# 🎓 HOD (Head of Department) Dashboard - Complete Implementation Plan

## 📋 Overview

The **HOD (Head of Department)** role is a crucial middle-management position that bridges the gap between teachers and administration. The HOD has department-level oversight and management capabilities.

---

## 🎯 HOD Role Responsibilities

### Academic Management
- Monitor department performance
- Oversee faculty in their department
- Review and approve course materials
- Track student performance in department courses
- Manage department timetable

### Faculty Management
- View all teachers in the department
- Monitor teacher performance and attendance
- Review teacher activity logs
- Approve/reject study materials before publishing

### Student Oversight
- View all students enrolled in department courses
- Monitor department-wide attendance trends
- Track academic performance across department
- Identify at-risk students

### Reporting & Analytics
- Department performance dashboards
- Faculty performance reports
- Student success metrics
- Course completion rates

---

## 🎨 HOD Dashboard Design

### Color Scheme
```dart
Primary: Teal/Cyan (#0891B2, #06B6D4)
Secondary: Dark Teal (#0E7490)
Accent: Light Cyan (#67E8F9)
Background: White with teal accents
```

### Dashboard Layout

#### Top Section - Department Overview
- **Department Name & HOD Info**
- **Quick Stats Cards:**
  - Total Faculty Members
  - Total Students in Department
  - Active Courses
  - Department Attendance Average

#### Main Grid - Management Cards

1. **Faculty Management** 🧑‍🏫
   - View all department teachers
   - Teacher performance metrics
   - Teacher attendance tracking
   - Activity logs

2. **Student Analytics** 📊
   - Department-wide student list
   - Performance trends
   - Attendance analytics
   - At-risk student identification

3. **Course Management** 📚
   - View all department courses
   - Course enrollment stats
   - Course performance metrics
   - Timetable overview

4. **Study Materials Review** 📝
   - Pending approvals
   - Approve/reject materials
   - Published materials history

5. **Announcements** 📢
   - Create department announcements
   - View announcement history
   - Target specific courses or all department

6. **Reports & Analytics** 📈
   - Department performance reports
   - Faculty comparison charts
   - Student success metrics
   - Export reports (PDF/Excel)

7. **Attendance Overview** ✅
   - Department attendance trends
   - Class-wise attendance
   - Defaulter lists
   - Monthly reports

8. **Timetable Management** 📅
   - View department timetable
   - Identify conflicts
   - Suggest optimizations

---

## 🗄️ Database Requirements

### New Tables Needed

#### 1. `hod_assignments` Table
```sql
CREATE TABLE hod_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    department_id UUID REFERENCES departments(id),
    assigned_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### 2. `study_materials` Table (if not exists)
```sql
CREATE TABLE study_materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES courses(id),
    teacher_id UUID REFERENCES staff(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_url TEXT,
    material_type VARCHAR(50), -- 'notes', 'assignment', 'reference'
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    hod_approved_by UUID REFERENCES users(id),
    hod_approval_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### 3. `department_announcements` Table
```sql
CREATE TABLE department_announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_id UUID REFERENCES departments(id),
    created_by UUID REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    target_audience VARCHAR(50), -- 'all', 'students', 'faculty', 'specific_course'
    target_course_id UUID REFERENCES courses(id),
    priority VARCHAR(20) DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);
```

### Sample Data

```sql
-- Insert HOD assignment
INSERT INTO hod_assignments (user_id, department_id) 
SELECT u.id, d.id 
FROM users u, departments d 
WHERE u.username = 'hod1' AND d.name = 'Computer Science';

-- Insert sample study materials
INSERT INTO study_materials (course_id, teacher_id, title, description, material_type, status)
VALUES 
    ((SELECT id FROM courses WHERE code = 'CSE101'), 
     (SELECT id FROM staff WHERE email = 'teacher1@shivalik.edu'), 
     'Data Structures - Week 1 Notes', 
     'Introduction to Arrays and Linked Lists',
     'notes',
     'pending'),
    ((SELECT id FROM courses WHERE code = 'CSE102'), 
     (SELECT id FROM staff WHERE email = 'teacher2@shivalik.edu'), 
     'DBMS Assignment 1', 
     'Normalization and ER Diagrams',
     'assignment',
     'approved');
```

---

## 💻 Service Layer - `hod_service.dart`

### Core Methods

#### Department Overview
```dart
// Get HOD's department info
Future<Map<String, dynamic>> getHODDepartment(String userId)

// Get department statistics
Future<Map<String, dynamic>> getDepartmentStats(String departmentId)
```

#### Faculty Management
```dart
// Get all faculty in department
Future<List<Map<String, dynamic>>> getDepartmentFaculty(String departmentId)

// Get faculty performance metrics
Future<Map<String, dynamic>> getFacultyPerformance(String facultyId)

// Get faculty attendance
Future<List<Map<String, dynamic>>> getFacultyAttendance(String facultyId, DateTime startDate, DateTime endDate)
```

#### Student Analytics
```dart
// Get all students in department courses
Future<List<Map<String, dynamic>>> getDepartmentStudents(String departmentId)

// Get student performance in department
Future<Map<String, dynamic>> getStudentDepartmentPerformance(String studentId, String departmentId)

// Get at-risk students
Future<List<Map<String, dynamic>>> getAtRiskStudents(String departmentId)

// Get department attendance trends
Future<Map<String, dynamic>> getDepartmentAttendanceTrends(String departmentId)
```

#### Course Management
```dart
// Get all department courses
Future<List<Map<String, dynamic>>> getDepartmentCourses(String departmentId)

// Get course statistics
Future<Map<String, dynamic>> getCourseStats(String courseId)

// Get course enrollment details
Future<List<Map<String, dynamic>>> getCourseEnrollments(String courseId)
```

#### Study Materials Review
```dart
// Get pending study materials for approval
Future<List<Map<String, dynamic>>> getPendingStudyMaterials(String departmentId)

// Approve study material
Future<void> approveStudyMaterial(String materialId, String hodUserId)

// Reject study material
Future<void> rejectStudyMaterial(String materialId, String hodUserId, String reason)

// Get approved materials history
Future<List<Map<String, dynamic>>> getApprovedMaterials(String departmentId)
```

#### Announcements
```dart
// Create department announcement
Future<void> createDepartmentAnnouncement({
    required String departmentId,
    required String createdBy,
    required String title,
    required String content,
    String targetAudience = 'all',
    String? targetCourseId,
    String priority = 'normal',
    DateTime? expiresAt,
})

// Get department announcements
Future<List<Map<String, dynamic>>> getDepartmentAnnouncements(String departmentId)

// Update announcement
Future<void> updateAnnouncement(String announcementId, Map<String, dynamic> updates)

// Delete announcement
Future<void> deleteAnnouncement(String announcementId)
```

#### Reports & Analytics
```dart
// Get department performance report
Future<Map<String, dynamic>> getDepartmentPerformanceReport(String departmentId)

// Get faculty comparison report
Future<List<Map<String, dynamic>>> getFacultyComparisonReport(String departmentId)

// Get student success metrics
Future<Map<String, dynamic>> getStudentSuccessMetrics(String departmentId)

// Export report as PDF
Future<void> exportReportPDF(String reportType, String departmentId)
```

---

## 🎨 UI Components

### 1. HOD Dashboard Screen
**File:** `lib/features/dashboard/hod_dashboard.dart`

**Features:**
- Glassmorphic header with department info
- Quick stats cards with animations
- Grid of management cards
- Smooth page transitions
- Pull-to-refresh functionality

### 2. Faculty Management Screen
**File:** `lib/features/hod/faculty_management_screen.dart`

**Features:**
- List of all department faculty
- Search and filter options
- Faculty performance cards
- Tap to view detailed analytics
- Activity timeline

### 3. Student Analytics Screen
**File:** `lib/features/hod/student_analytics_screen.dart`

**Features:**
- Department student list
- Performance charts (fl_chart)
- Attendance heatmap
- At-risk student alerts
- Export options

### 4. Study Materials Review Screen
**File:** `lib/features/hod/study_materials_review_screen.dart`

**Features:**
- Pending materials queue
- Material preview
- Approve/Reject buttons
- Approval history
- Filter by course/teacher

### 5. Department Announcements Screen
**File:** `lib/features/hod/department_announcements_screen.dart`

**Features:**
- Create announcement form
- Rich text editor
- Target audience selector
- Priority badges
- Announcement timeline

### 6. Reports Dashboard Screen
**File:** `lib/features/hod/reports_dashboard_screen.dart`

**Features:**
- Interactive charts
- Date range selectors
- Export buttons (PDF/Excel)
- Comparison views
- Trend analysis

---

## 🔐 Security & Permissions

### Row Level Security (RLS) Policies

```sql
-- HOD can view all faculty in their department
CREATE POLICY "HOD can view department faculty"
ON staff FOR SELECT
USING (
    department_id IN (
        SELECT department_id FROM hod_assignments 
        WHERE user_id = auth.uid() AND is_active = true
    )
);

-- HOD can view students in department courses
CREATE POLICY "HOD can view department students"
ON students FOR SELECT
USING (
    id IN (
        SELECT student_id FROM enrollments 
        WHERE course_id IN (
            SELECT id FROM courses 
            WHERE department_id IN (
                SELECT department_id FROM hod_assignments 
                WHERE user_id = auth.uid() AND is_active = true
            )
        )
    )
);

-- HOD can approve/reject study materials
CREATE POLICY "HOD can manage study materials"
ON study_materials FOR ALL
USING (
    course_id IN (
        SELECT id FROM courses 
        WHERE department_id IN (
            SELECT department_id FROM hod_assignments 
            WHERE user_id = auth.uid() AND is_active = true
        )
    )
);
```

---

## 🚀 Implementation Steps

### Phase 1: Database Setup
1. ✅ Add 'hod' role to users table constraint
2. ✅ Insert hod1 user in users_rows.sql
3. Create hod_assignments table
4. Create study_materials table
5. Create department_announcements table
6. Add RLS policies
7. Insert sample data

### Phase 2: Service Layer
1. Create `hod_service.dart`
2. Implement all core methods
3. Add error handling
4. Test all queries

### Phase 3: UI Development
1. Create HOD dashboard screen
2. Create faculty management screen
3. Create student analytics screen
4. Create study materials review screen
5. Create announcements screen
6. Create reports dashboard

### Phase 4: Integration
1. Update router to include HOD routes
2. Update login flow to recognize HOD role
3. Add navigation guards
4. Test complete flow

### Phase 5: Polish
1. Add animations
2. Add loading states
3. Add error handling
4. Add empty states
5. Test on multiple devices

---

## 📊 Key Features Summary

### ✅ What HOD Can Do:
- ✅ View all faculty in their department
- ✅ Monitor faculty performance and attendance
- ✅ View all students in department courses
- ✅ Track student performance and attendance
- ✅ Approve/reject study materials
- ✅ Create department announcements
- ✅ Generate department reports
- ✅ View department timetable
- ✅ Identify at-risk students
- ✅ Export analytics and reports

### ❌ What HOD Cannot Do:
- ❌ Modify student records (admin only)
- ❌ Add/remove faculty (admin only)
- ❌ Change course structure (admin only)
- ❌ Access other departments' data
- ❌ Modify salary information (HR only)
- ❌ Approve leave requests (HR only)

---

## 🎯 Success Metrics

### Performance
- Dashboard load time < 2 seconds
- Smooth 60 FPS animations
- Efficient database queries with proper indexes

### User Experience
- Intuitive navigation
- Clear visual hierarchy
- Responsive design
- Helpful error messages
- Quick actions accessible

### Functionality
- All CRUD operations working
- Real-time data updates
- Accurate analytics
- Reliable exports

---

## 📝 Next Steps

1. **Run the SQL migration** to add HOD role constraint
2. **Create database tables** for HOD-specific features
3. **Implement HOD service** with all methods
4. **Design and build UI screens** with premium aesthetics
5. **Integrate with routing** and authentication
6. **Test thoroughly** with sample data
7. **Polish and optimize** for production

---

## 🎨 Design Inspiration

The HOD dashboard should feel:
- **Professional** - Clean, organized layouts
- **Powerful** - Rich analytics and insights
- **Efficient** - Quick access to key functions
- **Modern** - Glassmorphism, smooth animations
- **Trustworthy** - Clear data visualization

**Color Psychology:**
- Teal/Cyan conveys trust, professionalism, and clarity
- Perfect for an academic leadership role
- Distinguishes from Student (Blue), Teacher (Green), Admin (Purple), HR (Orange)

---

**Status:** Ready for implementation! 🚀
**Priority:** High - Key management role
**Estimated Time:** 2-3 days for complete implementation
