// ERP Mode Configuration - Central mode/feature flag system
enum ERPMode { college, school }

enum ERPRole {
  student,
  teacher,
  admin,
  parent,
  HR,
  hod,
  accountant,
  receptionist,
  transport,
  librarian,
  superAdmin,
}

class ERPConfig {
  final ERPMode mode;
  final ERPRole role;
  final String username;
  final String? instituteId;
  final String? instituteName;

  const ERPConfig({
    required this.mode,
    required this.role,
    required this.username,
    this.instituteId,
    this.instituteName,
  });

  bool get isSchool => mode == ERPMode.school;
  bool get isCollege => mode == ERPMode.college;

  // Feature flags
  bool get hasHomework => isSchool;
  bool get hasReportCard => isSchool;
  bool get hasParentPortal => isSchool;
  bool get hasTransport => isSchool;
  bool get hasHOD => isCollege;
  bool get hasSemesters => isCollege;
  bool get hasClasses => isSchool;
  bool get hasCirculars => true; // both
  bool get hasNotices => true;   // both
  bool get hasFees => true;      // both
  bool get hasTimetable => true; // both
  bool get hasAttendance => true; // both
  bool get hasHR => true;         // both
  bool get hasLibrary => true;    // both

  // Label overrides based on mode
  String get semesterOrClassLabel => isSchool ? 'Class' : 'Semester';
  String get batchOrSectionLabel => isSchool ? 'Section' : 'Batch';
  String get subjectOrSubjectLabel => 'Subject'; // same
  String get assignmentOrHomeworkLabel => isSchool ? 'Homework' : 'Assignment';
  String get courseOrClassLabel => isSchool ? 'Class' : 'Course';
  String get departmentOrStreamLabel => isSchool ? 'Stream' : 'Department';
  String get gradeOrCGPALabel => isSchool ? 'Grade' : 'CGPA';
  String get examOrTestLabel => isSchool ? 'Test' : 'Exam';
  String get instituteLabel => isSchool ? 'School' : 'College';

  // Role display name
  String get roleDisplayName {
    switch (role) {
      case ERPRole.student: return isSchool ? 'Student' : 'Student';
      case ERPRole.teacher: return isSchool ? 'Teacher' : 'Faculty';
      case ERPRole.admin: return isSchool ? 'Principal' : 'Admin';
      case ERPRole.parent: return 'Parent';
      case ERPRole.HR: return 'HR';
      case ERPRole.hod: return 'HOD';
      case ERPRole.accountant: return 'Accountant';
      case ERPRole.receptionist: return 'Receptionist';
      case ERPRole.transport: return 'Transport Staff';
      case ERPRole.librarian: return 'Librarian';
      case ERPRole.superAdmin: return 'Super Admin';
    }
  }

  static ERPMode modeFromString(String? s) {
    if (s == 'school') return ERPMode.school;
    return ERPMode.college;
  }

  static ERPRole roleFromString(String? s) {
    switch (s) {
      case 'student': return ERPRole.student;
      case 'teacher': return ERPRole.teacher;
      case 'admin': return ERPRole.admin;
      case 'parent': return ERPRole.parent;
      case 'HR': return ERPRole.HR;
      case 'hod': return ERPRole.hod;
      case 'accountant': return ERPRole.accountant;
      case 'receptionist': return ERPRole.receptionist;
      case 'transport': return ERPRole.transport;
      case 'librarian': return ERPRole.librarian;
      case 'super_admin': return ERPRole.superAdmin;
      default: return ERPRole.student;
    }
  }
}
