import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'school_payroll_service.dart';
import 'auth_service.dart';

enum AccessLevel { none, view, edit, approve }

class SchoolPermissionService {
  static final SchoolPermissionService _instance =
      SchoolPermissionService._internal();
  factory SchoolPermissionService() => _instance;
  SchoolPermissionService._internal();

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolPayrollService _payroll = SchoolPayrollService();

  static const List<String> supportedRoles = [
    'superadmin',
    'sadmin',
    'principal',
    'teacher',
    'class_teacher',
    'parent',
    'student',
    'librarian',
    'warden',
    'nurse',
    'accountant',
    'driver',
    'conductor',
    'attendant',
    'alumni',
    'staff',
  ];

  static const List<String> supportedFeatures = [
    'attendance',
    'marks',
    'fees',
    'payroll',
    'hostel',
    'infirmary',
    'library',
    'discipline',
    'inventory',
    'reports',
    'admissions',
    'transport',
    'circulars',
    'homework',
    'timetable',
    'leave',
  ];

  // ==========================================
  // 1. PERMISSION MATRIX MANAGEMENT
  // ==========================================

  Future<List<Map<String, dynamic>>> getMatrix(
      {String instituteId = 'SHIV-SCH'}) async {
    try {
      final res = await _supabase
          .from('school_role_permissions')
          .select()
          .eq('institute_id', instituteId);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}

    // Resilient fallback or circulars check
    try {
      final circRes = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'RolePermission')
          .order('published_at', ascending: false);
      final circList = List<Map<String, dynamic>>.from(circRes);
      if (circList.isNotEmpty) {
        final Map<String, Map<String, dynamic>> latestMap = {};
        for (var c in circList) {
          try {
            final data = jsonDecode(c['content']?.toString() ?? '{}')
                as Map<String, dynamic>;
            final key = '${data['role']}_${data['feature']}';
            latestMap.putIfAbsent(key, () => data);
          } catch (_) {}
        }
        if (latestMap.isNotEmpty) {
          return latestMap.values.toList();
        }
      }
    } catch (_) {}

    return _getDefaultMatrix(instituteId);
  }

  Future<void> updatePermission({
    required String role,
    required String feature,
    required String permission,
    required String updatedBy,
    String instituteId = 'SHIV-SCH',
  }) async {
    final payload = {
      'id': '${instituteId}_${role}_$feature',
      'institute_id': instituteId,
      'role': role,
      'feature': feature,
      'permission': permission,
      'updated_by': updatedBy,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_role_permissions').upsert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'Permission Update: $role -> $feature ($permission)',
        'content': jsonEncode(payload),
        'category': 'RolePermission',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payroll.logAudit(
      actorUsername: updatedBy,
      action: 'update_role_permission',
      entity: 'school_role_permissions',
      entityId: '${role}_$feature',
      newValue: payload,
    );
  }

  bool canAccess({
    required String userRole,
    required String feature,
    required String requiredPermission, // 'view', 'edit', 'approve'
    List<Map<String, dynamic>>? customMatrix,
  }) {
    final role = userRole.toLowerCase().trim();
    if (role == 'superadmin' || role == 'sadmin' || role == 'principal') {
      return true;
    }

    String granted = 'none';
    if (customMatrix != null && customMatrix.isNotEmpty) {
      final match = customMatrix.firstWhere(
        (m) =>
            m['role']?.toString().toLowerCase() == role &&
            m['feature']?.toString().toLowerCase() == feature.toLowerCase(),
        orElse: () => {},
      );
      if (match.isNotEmpty && match['permission'] != null) {
        granted = match['permission'].toString().toLowerCase();
      }
    }

    if (granted == 'none') {
      granted = _getDefaultPermission(role, feature.toLowerCase());
    }

    return _isPermissionSufficient(granted, requiredPermission.toLowerCase());
  }

  bool _isPermissionSufficient(String granted, String required) {
    const hierarchy = {'none': 0, 'view': 1, 'edit': 2, 'approve': 3};
    final gVal = hierarchy[granted] ?? 0;
    final rVal = hierarchy[required] ?? 1;
    return gVal >= rVal;
  }

  /// Get verified user role directly from live `users` database table
  Future<String?> getLiveUserRole([String? username]) async {
    return await AuthService().getLiveUserRole(username);
  }

  /// Enforce authorization policy: role is re-read from live `users` table.
  /// Throws an Exception if permission is not granted.
  Future<void> enforce({
    required String feature,
    required String requiredPermission,
    String? username,
  }) async {
    final uname = username ?? await AuthService().getCurrentUsername();
    if (uname == null || uname.isEmpty) {
      throw Exception('Unauthorized: No active authenticated session.');
    }

    final liveRole = await getLiveUserRole(uname);
    if (liveRole == null || liveRole.isEmpty) {
      throw Exception(
          'Access Denied: User "$uname" does not have an active verified role in the system.');
    }

    // Normalize roles like 'steacher' -> 'teacher', 'sstudent' -> 'student', 'sparent' -> 'parent', 'sadmin' -> 'admin'
    final normalized = liveRole.startsWith('s') &&
            (liveRole == 'steacher' ||
                liveRole == 'sstudent' ||
                liveRole == 'sparent' ||
                liveRole == 'sadmin')
        ? liveRole.substring(1)
        : liveRole;

    final allowed = canAccess(
          userRole: liveRole,
          feature: feature,
          requiredPermission: requiredPermission,
        ) ||
        canAccess(
          userRole: normalized,
          feature: feature,
          requiredPermission: requiredPermission,
        );

    if (!allowed) {
      throw Exception(
        'Security Enforcement: Role "$liveRole" does not have "$requiredPermission" permission for feature "$feature".',
      );
    }
  }

  /// Check permission with live role check without throwing
  Future<bool> canPerform({
    required String feature,
    required String requiredPermission,
    String? username,
  }) async {
    try {
      await enforce(
        feature: feature,
        requiredPermission: requiredPermission,
        username: username,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // 2. MARKS DEADLINE & LOCK MANAGEMENT
  // ==========================================

  Future<List<Map<String, dynamic>>> getMarksLocks({
    String? examId,
    String? classId,
    String instituteId = 'SHIV-SCH',
  }) async {
    try {
      var query = _supabase
          .from('school_marks_locks')
          .select()
          .eq('institute_id', instituteId);
      if (examId != null && examId.isNotEmpty) {
        query = query.eq('exam_id', examId);
      }
      if (classId != null && classId.isNotEmpty) {
        query = query.eq('class_id', classId);
      }
      final res = await query.order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final circRes = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'MarksLock')
          .order('published_at', ascending: false);
      final circList = List<Map<String, dynamic>>.from(circRes);
      if (circList.isNotEmpty) {
        return circList
            .map((c) {
              try {
                return jsonDecode(c['content']?.toString() ?? '{}')
                    as Map<String, dynamic>;
              } catch (_) {
                return <String, dynamic>{};
              }
            })
            .where((m) => m.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    // No configured lock means marks remain open; never invent a lock row.
    return [];
  }

  Future<bool> isMarksLocked({
    required String examId,
    required String classId,
    String subject = 'All',
    String instituteId = 'SHIV-SCH',
  }) async {
    final locks = await getMarksLocks(
        examId: examId, classId: classId, instituteId: instituteId);
    final match = locks.firstWhere(
      (l) =>
          l['exam_id'] == examId &&
          l['class_id'] == classId &&
          (l['subject'] == subject || l['subject'] == 'All'),
      orElse: () => {},
    );

    if (match.isEmpty) return false;

    // Check manual lock
    if (match['is_locked'] == true) return true;

    // Check deadline
    final deadlineStr = match['deadline']?.toString();
    if (deadlineStr != null) {
      final deadline = DateTime.tryParse(deadlineStr);
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        return true;
      }
    }

    return false;
  }

  static final RegExp _missingColumnPattern = RegExp(
    "(?:Could not find the '([a-zA-Z0-9_]+)' column"
    '|column "([a-zA-Z0-9_]+)" of relation "[a-zA-Z0-9_]+" does not exist'
    '|column "([a-zA-Z0-9_]+)" does not exist)',
    caseSensitive: false,
  );

  static String? _missingColumn(Object? error) {
    if (error == null) return null;
    final match = _missingColumnPattern.firstMatch(error.toString());
    if (match == null) return null;
    return match.group(1) ?? match.group(2) ?? match.group(3);
  }

  Future<Map<String, dynamic>> setMarksLock({
    required String examId,
    required String classId,
    String subject = 'All',
    required bool isLocked,
    required String actorUsername,
    String? unlockReason,
    DateTime? deadline,
    String instituteId = 'SHIV-SCH',
  }) async {
    final id = '${instituteId}_${examId}_${classId}_$subject';
    final payload = {
      'id': id,
      'institute_id': instituteId,
      'exam_id': examId,
      'class_id': classId,
      'subject': subject,
      'is_locked': isLocked,
      if (isLocked) 'locked_at': DateTime.now().toIso8601String(),
      if (isLocked) 'locked_by': actorUsername,
      if (!isLocked) 'unlocked_at': DateTime.now().toIso8601String(),
      if (!isLocked) 'unlocked_by': actorUsername,
      if (!isLocked && unlockReason != null) 'unlock_reason': unlockReason,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Older databases may miss one of the optional columns (updated_at,
    // deadline, unlock_reason). Strip the offending column and retry instead of
    // failing the whole submission with "column ... does not exist".
    var saved = false;
    final effective = Map<String, dynamic>.from(payload);
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await _supabase.from('school_marks_locks').upsert(effective);
        saved = true;
        break;
      } catch (e) {
        final missing = _missingColumn(e);
        if (missing == null ||
            !effective.containsKey(missing) ||
            missing == 'id' ||
            missing == 'exam_id' ||
            missing == 'class_id') {
          break;
        }
        effective.remove(missing);
      }
    }

    if (!saved) {
      // Last resort: keep a note in the circulars register so the submission is
      // still recorded somewhere readable by the administration.
      try {
        await _supabase.from('school_circulars').insert({
          'title':
              'Marks Lock Updated: $examId / $classId ($subject) -> ${isLocked ? "LOCKED" : "UNLOCKED"}',
          'content': jsonEncode(payload),
          'category': 'MarksLock',
          'target_audience': 'Teacher',
          'published_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    await _payroll.logAudit(
      actorUsername: actorUsername,
      action: isLocked ? 'lock_marks_entry' : 'unlock_marks_entry',
      entity: 'school_marks_locks',
      entityId: id,
      newValue: payload,
    );

    return payload;
  }

  // ==========================================
  // 3. MAKER-CHECKER EXTENSION (2-EYE PRINCIPLE)
  // ==========================================

  Future<List<Map<String, dynamic>>> getMakerCheckerRequests({
    String? status,
    String? requestType,
    String instituteId = 'SHIV-SCH',
  }) async {
    try {
      var query = _supabase
          .from('school_maker_checker_requests')
          .select()
          .eq('institute_id', instituteId);
      if (status != null && status != 'All') {
        query = query.eq('status', status.toLowerCase());
      }
      if (requestType != null && requestType != 'All') {
        query = query.eq('request_type', requestType);
      }
      final res = await query.order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final circRes = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'MakerChecker')
          .order('published_at', ascending: false);
      final circList = List<Map<String, dynamic>>.from(circRes);
      if (circList.isNotEmpty) {
        final items = circList
            .map((c) {
              try {
                return jsonDecode(c['content']?.toString() ?? '{}')
                    as Map<String, dynamic>;
              } catch (_) {
                return <String, dynamic>{};
              }
            })
            .where((m) => m.isNotEmpty)
            .toList();

        if (status != null && status != 'All') {
          return items
              .where((i) =>
                  i['status']?.toString().toLowerCase() == status.toLowerCase())
              .toList();
        }
        return items;
      }
    } catch (_) {}

    return _getDefaultMakerCheckerRequests();
  }

  Future<Map<String, dynamic>> submitMakerRequest({
    required String requestType,
    required String entityId,
    required String title,
    required String makerUsername,
    required String makerRole,
    String? description,
    Map<String, dynamic>? actionData,
    String instituteId = 'SHIV-SCH',
  }) async {
    final requestId = 'MC-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': requestId,
      'institute_id': instituteId,
      'request_type': requestType,
      'entity_id': entityId,
      'title': title,
      'description':
          description ?? 'Maker submitted $requestType for $entityId',
      'maker_username': makerUsername,
      'maker_role': makerRole,
      'status': 'pending',
      'action_data': actionData ?? {},
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_maker_checker_requests').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'Pending Maker-Checker Approval: $title ($requestId)',
        'content': jsonEncode(payload),
        'category': 'MakerChecker',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payroll.logAudit(
      actorUsername: makerUsername,
      action: 'submit_maker_request',
      entity: 'school_maker_checker_requests',
      entityId: requestId,
      newValue: payload,
    );

    return payload;
  }

  Future<Map<String, dynamic>> reviewMakerRequest({
    required String requestId,
    required String checkerUsername,
    required bool approve,
    String? rejectionReason,
    String instituteId = 'SHIV-SCH',
  }) async {
    // 1. Fetch current request to enforce Separation of Duty (maker != checker)
    final requests = await getMakerCheckerRequests(instituteId: instituteId);
    final req =
        requests.firstWhere((r) => r['id'] == requestId, orElse: () => {});
    if (req.isEmpty) {
      throw Exception('Request $requestId not found.');
    }

    final maker = req['maker_username']?.toString() ?? '';
    if (maker.toLowerCase() == checkerUsername.toLowerCase()) {
      throw Exception(
          'Separation of Duty Violation: Maker ($maker) cannot approve their own request!');
    }

    final newStatus = approve ? 'approved' : 'rejected';
    final payload = {
      ...req,
      'status': newStatus,
      'checker_username': checkerUsername,
      'reviewed_at': DateTime.now().toIso8601String(),
      if (!approve && rejectionReason != null)
        'rejection_reason': rejectionReason,
    };

    try {
      await _supabase.from('school_maker_checker_requests').update({
        'status': newStatus,
        'checker_username': checkerUsername,
        'reviewed_at': payload['reviewed_at'],
        if (!approve) 'rejection_reason': rejectionReason,
      }).eq('id', requestId);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title':
            'Maker-Checker Decision: $requestId -> ${newStatus.toUpperCase()}',
        'content': jsonEncode(payload),
        'category': 'MakerChecker',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payroll.logAudit(
      actorUsername: checkerUsername,
      action: approve ? 'approve_maker_request' : 'reject_maker_request',
      entity: 'school_maker_checker_requests',
      entityId: requestId,
      newValue: payload,
    );

    return payload;
  }

  // ==========================================
  // 4. STATS & SUMMARY
  // ==========================================

  Future<Map<String, dynamic>> getStats(
      {String instituteId = 'SHIV-SCH'}) async {
    final matrix = await getMatrix(instituteId: instituteId);
    final locks = await getMarksLocks(instituteId: instituteId);
    final requests = await getMakerCheckerRequests(instituteId: instituteId);

    final lockedCount = locks.where((l) => l['is_locked'] == true).length;
    final pendingApprovals =
        requests.where((r) => r['status'] == 'pending').length;

    return {
      'configured_roles': supportedRoles.length,
      'managed_features': supportedFeatures.length,
      'active_rules': matrix.length,
      'locked_exam_sessions': lockedCount,
      'pending_maker_checker': pendingApprovals,
    };
  }

  // ==========================================
  // DEFAULTS & BASELINE MATRIX
  // ==========================================

  String _getDefaultPermission(String role, String feature) {
    if (role == 'superadmin' || role == 'sadmin' || role == 'principal')
      return 'approve';

    switch (role) {
      case 'teacher':
        if (feature == 'attendance' || feature == 'marks') return 'edit';
        if (feature == 'homework') return 'edit';
        if (feature == 'timetable') return 'edit';
        if (feature == 'leave') return 'view';
        if (feature == 'discipline') return 'edit';
        if (feature == 'circulars') return 'edit';
        if (feature == 'library' || feature == 'timetable') return 'view';
        return 'none';

      case 'class_teacher':
        if (feature == 'attendance' || feature == 'marks') return 'edit';
        if (feature == 'homework') return 'edit';
        if (feature == 'timetable') return 'edit';
        if (feature == 'leave') return 'approve';
        if (feature == 'discipline') return 'edit';
        if (feature == 'discipline') return 'edit';
        if (feature == 'circulars') return 'edit';
        if (feature == 'fees' || feature == 'hostel' || feature == 'library')
          return 'view';
        return 'none';

      case 'librarian':
        if (feature == 'library') return 'approve';
        if (feature == 'circulars') return 'edit';
        if (feature == 'fees') return 'view';
        return 'none';

      case 'warden':
        if (feature == 'hostel') return 'approve';
        if (feature == 'circulars') return 'edit';
        if (feature == 'discipline') return 'edit';
        if (feature == 'infirmary') return 'view';
        return 'none';

      case 'nurse':
        if (feature == 'infirmary') return 'approve';
        if (feature == 'circulars') return 'edit';
        return 'none';

      case 'accountant':
        if (feature == 'fees' || feature == 'payroll') return 'edit';
        if (feature == 'circulars') return 'edit';
        if (feature == 'inventory') return 'view';
        return 'none';

      case 'driver':
      case 'conductor':
      case 'attendant':
        if (feature == 'circulars' || feature == 'transport') return 'view';
        return 'none';

      case 'alumni':
      case 'staff':
        if (feature == 'circulars') return 'view';
        return 'none';

      case 'parent':
        if (feature == 'attendance' ||
            feature == 'marks' ||
            feature == 'fees' ||
            feature == 'transport' ||
            feature == 'infirmary' ||
            feature == 'circulars' ||
            feature == 'homework') return 'view';
        if (feature == 'timetable') return 'view';
        if (feature == 'leave') return 'edit';
        if (feature == 'discipline') return 'view';
        return 'none';

      case 'student':
        if (feature == 'attendance' ||
            feature == 'marks' ||
            feature == 'fees' ||
            feature == 'library' ||
            feature == 'circulars') return 'view';
        if (feature == 'homework') return 'edit';
        if (feature == 'timetable') return 'view';
        if (feature == 'leave') return 'edit';
        if (feature == 'discipline') return 'view';
        return 'none';

      default:
        return 'none';
    }
  }

  List<Map<String, dynamic>> _getDefaultMatrix(String instituteId) {
    final List<Map<String, dynamic>> list = [];
    for (final role in supportedRoles) {
      for (final feat in supportedFeatures) {
        list.add({
          'id': '${instituteId}_${role}_$feat',
          'institute_id': instituteId,
          'role': role,
          'feature': feat,
          'permission': _getDefaultPermission(role, feat),
          'updated_by': 'system_seed',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
    return list;
  }

  List<Map<String, dynamic>> _getDefaultMakerCheckerRequests() {
    return [
      {
        'id': 'MC-101',
        'institute_id': 'SHIV-SCH',
        'request_type': 'payroll_lock',
        'entity_id': 'RUN-2026-10',
        'title': 'Monthly Payroll Lock Approval (October 2026)',
        'description':
            'Disbursement authorization for 24 staff members totaling ₹13,42,800',
        'maker_username': 'accountant1',
        'maker_role': 'accountant',
        'checker_username': null,
        'status': 'pending',
        'action_data': {'total_cost': 1342800, 'staff_count': 24},
        'created_at':
            DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      },
      {
        'id': 'MC-102',
        'institute_id': 'SHIV-SCH',
        'request_type': 'marks_bulk_upload',
        'entity_id': 'EXAM-MID-2026',
        'title': 'Bulk Marks Moderation Approval — Class 10-A Mathematics',
        'description':
            'Upward grade moderation of +2 grace marks across 38 students',
        'maker_username': 'steacher1',
        'maker_role': 'teacher',
        'checker_username': null,
        'status': 'pending',
        'action_data': {'class_id': 'Class 10-A', 'subject': 'Mathematics'},
        'created_at':
            DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
      },
      {
        'id': 'MC-103',
        'institute_id': 'SHIV-SCH',
        'request_type': 'discipline_suspension',
        'entity_id': 'INC-2026-004',
        'title': 'Disciplinary Suspension Sanction — 3 Days',
        'description':
            'Severe lab damage incident recommendation by inquiry committee',
        'maker_username': 'warden1',
        'maker_role': 'warden',
        'checker_username': null,
        'status': 'pending',
        'action_data': {'student_username': 'sstudent2', 'suspension_days': 3},
        'created_at': DateTime.now()
            .subtract(const Duration(hours: 12))
            .toIso8601String(),
      },
    ];
  }
}
