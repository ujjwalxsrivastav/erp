/// Role-Based Access Control (RBAC) Guard
///
/// Security Features:
/// 1. Role verification before operations
/// 2. Permission checking
/// 3. Action logging for audit trail
/// 4. Hierarchical role support

import '../security/secure_logger.dart';

/// User roles in the system
enum UserRole {
  student,
  teacher,
  hod,
  hr,
  admin,
  admissiondean,
  counsellor,
}

/// Permissions for different actions
enum Permission {
  // Student permissions
  viewOwnGrades,
  viewOwnTimetable,
  submitAssignment,
  viewAnnouncements,
  viewStudyMaterials,
  updateOwnProfile,

  // Teacher permissions
  viewStudents,
  uploadMarks,
  uploadAssignments,
  uploadStudyMaterials,
  makeAnnouncements,
  viewOwnClasses,

  // HOD permissions
  viewDepartmentTeachers,
  approveLeaveDepartment,
  manageTimetable,
  viewDepartmentReports,

  // HR permissions
  viewAllStaff,
  manageStaff,
  manageSalary,
  approveLeaveAll,
  uploadDocuments,
  viewHRReports,

  // Admin permissions
  createUsers,
  deleteUsers,
  manageRoles,
  viewAllData,
  systemSettings,
  databaseBackup,
  viewSecurityLogs,
}

/// Result of permission check
class PermissionResult {
  final bool allowed;
  final String? reason;
  final String? requiredRole;

  const PermissionResult._({
    required this.allowed,
    this.reason,
    this.requiredRole,
  });

  factory PermissionResult.allowed() {
    return const PermissionResult._(allowed: true);
  }

  factory PermissionResult.denied(String reason, {String? requiredRole}) {
    return PermissionResult._(
      allowed: false,
      reason: reason,
      requiredRole: requiredRole,
    );
  }
}

/// Role Guard for access control
class RoleGuard {
  static final RoleGuard _instance = RoleGuard._internal();
  factory RoleGuard() => _instance;
  RoleGuard._internal();

  /// Current user's role (should be set after login)
  UserRole? _currentRole;
  String? _currentUsername;

  /// Role hierarchy (higher index = more privileges)
  static const List<UserRole> _roleHierarchy = [
    UserRole.student,
    UserRole.teacher,
    UserRole.counsellor,
    UserRole.hod,
    UserRole.admissiondean,
    UserRole.hr,
    UserRole.admin,
  ];

  /// Permission matrix - which roles have which permissions
  static final Map<Permission, Set<UserRole>> _permissionMatrix = {
    // Student permissions
    Permission.viewOwnGrades: {
      UserRole.student,
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.viewOwnTimetable: {
      UserRole.student,
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.submitAssignment: {UserRole.student},
    Permission.viewAnnouncements: {
      UserRole.student,
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.viewStudyMaterials: {
      UserRole.student,
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.updateOwnProfile: {
      UserRole.student,
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },

    // Teacher permissions
    Permission.viewStudents: {
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.uploadMarks: {UserRole.teacher, UserRole.hod, UserRole.admin},
    Permission.uploadAssignments: {
      UserRole.teacher,
      UserRole.hod,
      UserRole.admin
    },
    Permission.uploadStudyMaterials: {
      UserRole.teacher,
      UserRole.hod,
      UserRole.admin
    },
    Permission.makeAnnouncements: {
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.viewOwnClasses: {
      UserRole.teacher,
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },

    // HOD permissions
    Permission.viewDepartmentTeachers: {
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.approveLeaveDepartment: {
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },
    Permission.manageTimetable: {UserRole.hod, UserRole.admin},
    Permission.viewDepartmentReports: {
      UserRole.hod,
      UserRole.hr,
      UserRole.admin
    },

    // HR permissions
    Permission.viewAllStaff: {UserRole.hr, UserRole.admin},
    Permission.manageStaff: {UserRole.hr, UserRole.admin},
    Permission.manageSalary: {UserRole.hr, UserRole.admin},
    Permission.approveLeaveAll: {UserRole.hr, UserRole.admin},
    Permission.uploadDocuments: {UserRole.hr, UserRole.admin},
    Permission.viewHRReports: {UserRole.hr, UserRole.admin},

    // Admin permissions
    Permission.createUsers: {UserRole.admin},
    Permission.deleteUsers: {UserRole.admin},
    Permission.manageRoles: {UserRole.admin},
    Permission.viewAllData: {UserRole.admin},
    Permission.systemSettings: {UserRole.admin},
    Permission.databaseBackup: {UserRole.admin},
    Permission.viewSecurityLogs: {UserRole.admin},
  };

  /// Set current user after login
  void setCurrentUser(String username, String roleString) {
    _currentUsername = username;
    _currentRole = _parseRole(roleString);
    SecureLogger.security(
        'RoleGuard', 'User role set: $username -> $_currentRole');
  }

  /// Clear current user on logout
  void clearCurrentUser() {
    final oldUser = _currentUsername;
    _currentUsername = null;
    _currentRole = null;
    SecureLogger.security('RoleGuard', 'User cleared: $oldUser');
  }

  /// Parse role string to enum
  UserRole? _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'teacher':
        return UserRole.teacher;
      case 'hod':
        return UserRole.hod;
      case 'hr':
        return UserRole.hr;
      case 'admin':
        return UserRole.admin;
      case 'admissiondean':
        return UserRole.admissiondean;
      case 'counsellor':
        return UserRole.counsellor;
      default:
        SecureLogger.warning('RoleGuard', 'Unknown role: $roleString');
        return null;
    }
  }

  /// Get current user's role
  UserRole? get currentRole => _currentRole;
  String? get currentUsername => _currentUsername;

  /// Check if current user has a specific permission
  PermissionResult checkPermission(Permission permission) {
    if (_currentRole == null) {
      SecureLogger.security(
          'RoleGuard', 'Permission denied: No user logged in');
      return PermissionResult.denied('Not logged in');
    }

    final allowedRoles = _permissionMatrix[permission];
    if (allowedRoles == null) {
      SecureLogger.warning('RoleGuard', 'Unknown permission: $permission');
      return PermissionResult.denied('Unknown permission');
    }

    if (!allowedRoles.contains(_currentRole)) {
      SecureLogger.security(
        'RoleGuard',
        'Permission denied: $_currentUsername tried to access $permission with role $_currentRole',
      );
      return PermissionResult.denied(
        'Insufficient permissions for this action',
        requiredRole: allowedRoles.first.name,
      );
    }

    return PermissionResult.allowed();
  }

  /// Check if current user has at least the given role level
  bool hasRoleLevel(UserRole minimumRole) {
    if (_currentRole == null) return false;

    final currentIndex = _roleHierarchy.indexOf(_currentRole!);
    final requiredIndex = _roleHierarchy.indexOf(minimumRole);

    return currentIndex >= requiredIndex;
  }

  /// Check if current user has exact role
  bool hasExactRole(UserRole role) {
    return _currentRole == role;
  }

  /// Check if current user has any of the given roles
  bool hasAnyRole(List<UserRole> roles) {
    if (_currentRole == null) return false;
    return roles.contains(_currentRole);
  }

  /// Guard a function call - throws if permission denied
  Future<T> guard<T>(Permission permission, Future<T> Function() action) async {
    final result = checkPermission(permission);
    if (!result.allowed) {
      throw PermissionDeniedException(
        permission: permission,
        reason: result.reason ?? 'Permission denied',
        currentRole: _currentRole,
        requiredRole: result.requiredRole,
      );
    }
    return action();
  }

  /// Guard a function call - returns null if permission denied
  Future<T?> guardOrNull<T>(
      Permission permission, Future<T> Function() action) async {
    final result = checkPermission(permission);
    if (!result.allowed) {
      SecureLogger.debug(
          'RoleGuard', 'Action blocked due to permission: $permission');
      return null;
    }
    return action();
  }

  /// Log an action for audit trail
  void logAction(String action, {Map<String, dynamic>? details}) {
    SecureLogger.security(
      'AUDIT',
      'User: $_currentUsername | Role: $_currentRole | Action: $action | Details: $details',
    );
  }
}

/// Exception thrown when permission is denied
class PermissionDeniedException implements Exception {
  final Permission permission;
  final String reason;
  final UserRole? currentRole;
  final String? requiredRole;

  const PermissionDeniedException({
    required this.permission,
    required this.reason,
    this.currentRole,
    this.requiredRole,
  });

  @override
  String toString() {
    return 'PermissionDeniedException: $reason (permission: $permission, '
        'current role: $currentRole, required: $requiredRole)';
  }
}

/// Singleton instance for easy access
final roleGuard = RoleGuard();
