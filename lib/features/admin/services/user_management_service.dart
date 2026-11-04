import 'package:supabase_flutter/supabase_flutter.dart';

class ManagedUsersResult {
  final List<Map<String, dynamic>> users;
  final bool institutionFilterAvailable;

  const ManagedUsersResult({
    required this.users,
    required this.institutionFilterAvailable,
  });
}

/// Roles an admin can assign from Manage Users. HR / HOD / Staff accounts are
/// no longer supported.
class UserRoles {
  static const String student = 'student';
  static const String teacher = 'teacher';
  static const String admin = 'admin';

  static const List<String> all = [student, teacher, admin];

  static String label(String role) => switch (role) {
        student => 'Student',
        teacher => 'Teacher',
        admin => 'Admin',
        _ =>
          role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}',
      };

  /// `users.institution` — decides which dashboard the account lands on.
  static String institutionFor(String role) =>
      role == admin ? 'college' : 'school';

  static bool isSupported(String role) => all.contains(role);
}

/// Admin — Manage Users.
///
/// The `users` table only carries username / password / role, so this
/// service offers listing, role changes and account creation. Display names
/// are resolved from the profile tables (school_students, teacher_details,
/// staff) since the login table has no name column.
class UserManagementService {
  final _supabase = Supabase.instance.client;

  /// [institution] — `school` or `college`; null lists every institution.
  /// Older databases may not yet have `users.institution`; in that case, list
  /// the accounts without institution filtering so the screen is still useful.
  /// Each row is enriched with `display_name` / `detail` where resolvable.
  Future<ManagedUsersResult> getUsers({String? institution}) async {
    late final List<Map<String, dynamic>> users;
    var institutionFilterAvailable = true;
    if (institution == null || institution.isEmpty) {
      users = await _fetchAllUsers();
    } else {
      try {
        final response = await _supabase
            .from('users')
            .select('username, role, institution, institute_type')
            .or('institution.eq.$institution,institute_type.eq.$institution')
            .order('username', ascending: true);
        users = List<Map<String, dynamic>>.from(response);
      } on PostgrestException catch (e) {
        if (!_isMissingColumn(e)) rethrow;
        try {
          users = await _fetchUsersByLegacyInstitution(institution);
        } on PostgrestException catch (legacyError) {
          if (!_isMissingColumn(legacyError)) rethrow;
          try {
            users = await _fetchUsersByInstitution(institution);
          } on PostgrestException catch (institutionError) {
            if (!_isMissingColumn(institutionError)) rethrow;
            print(
              'Neither users.institution nor users.institute_type is '
              'available; loading all users without institution filtering.',
            );
            users = await _fetchAllUsers();
            institutionFilterAvailable = false;
          }
        }
      }
    }

    await _attachDetails(users);
    return ManagedUsersResult(
      users: users,
      institutionFilterAvailable: institutionFilterAvailable,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsersByLegacyInstitution(
    String institution,
  ) async {
    final response = await _supabase
        .from('users')
        .select('username, role, institute_type')
        .eq('institute_type', institution)
        .order('username', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchUsersByInstitution(
    String institution,
  ) async {
    final response = await _supabase
        .from('users')
        .select('username, role, institution')
        .eq('institution', institution)
        .order('username', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    final response = await _supabase
        .from('users')
        .select('username, role')
        .order('username', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  bool _isMissingColumn(PostgrestException error) =>
      error.code == '42703' || error.code == 'PGRST204';

  /// Two batched lookups: school profiles (school_students + teacher_details)
  /// and college profiles (student_details + staff).
  Future<void> _attachDetails(List<Map<String, dynamic>> users) async {
    if (users.isEmpty) return;
    final ids = users.map((u) => u['username'] as String).toList();

    try {
      final students = await _supabase
          .from('school_students')
          .select('username, name, class_name, roll_number')
          .inFilter('username', ids);
      final byId = <String, Map<String, dynamic>>{
        for (final s in List<Map<String, dynamic>>.from(students))
          s['username'] as String: s,
      };
      for (final u in users) {
        final s = byId[u['username']];
        if (s == null) continue;
        u['display_name'] = s['name'];
        final cls = (s['class_name'] ?? '').toString();
        final roll = (s['roll_number'] ?? '').toString();
        u['detail'] = [
          if (cls.isNotEmpty) cls,
          if (roll.isNotEmpty) 'Roll $roll',
        ].join(' • ');
      }
    } catch (e) {
      print('Error resolving school students for users: $e');
    }

    try {
      final teachers = await _supabase
          .from('teacher_details')
          .select('teacher_id, name, department, subject')
          .inFilter('teacher_id', ids);
      final byId = <String, Map<String, dynamic>>{
        for (final t in List<Map<String, dynamic>>.from(teachers))
          t['teacher_id'] as String: t,
      };
      for (final u in users) {
        if (u['display_name'] != null) continue;
        final t = byId[u['username']];
        if (t == null) continue;
        u['display_name'] = t['name'];
        u['detail'] = [t['department'], t['subject']]
            .where((v) => (v ?? '').toString().isNotEmpty)
            .join(' • ');
      }
    } catch (e) {
      print('Error resolving teacher details for users: $e');
    }

    try {
      final students = await _supabase
          .from('student_details')
          .select('student_id, name, department, year, semester, section')
          .inFilter('student_id', ids);
      final byId = <String, Map<String, dynamic>>{
        for (final s in List<Map<String, dynamic>>.from(students))
          s['student_id'] as String: s,
      };
      for (final u in users) {
        if (u['display_name'] != null) continue;
        final s = byId[u['username']];
        if (s == null) continue;
        u['display_name'] = s['name'];
        u['detail'] =
            '${s['department']} • Year ${s['year']} • Sem ${s['semester']} • Sec ${s['section']}';
      }
    } catch (e) {
      print('Error resolving college students for users: $e');
    }

    try {
      final parents = await _supabase
          .from('parent_student_links')
          .select('parent_username, student_username')
          .inFilter('parent_username', ids);
      final byId = <String, List<String>>{};
      for (final p in List<Map<String, dynamic>>.from(parents)) {
        byId.putIfAbsent(p['parent_username'] as String, () => []).add(
              (p['student_username'] ?? '').toString(),
            );
      }
      for (final u in users) {
        if (u['display_name'] != null) continue;
        final children = byId[u['username']];
        if (children == null) continue;
        u['display_name'] = 'Parent of ${children.join(', ')}';
        u['detail'] = 'Parent account';
      }
    } catch (e) {
      print('Error resolving parents for users: $e');
    }

    try {
      final staff = await _supabase
          .from('staff')
          .select('staff_code, name, designation')
          .inFilter('staff_code', ids);
      final byId = <String, Map<String, dynamic>>{
        for (final s in List<Map<String, dynamic>>.from(staff))
          s['staff_code'] as String: s,
      };
      for (final u in users) {
        if (u['display_name'] != null) continue;
        final s = byId[u['username']];
        if (s == null) continue;
        u['display_name'] = s['name'];
        u['detail'] = (s['designation'] ?? '').toString();
      }
    } catch (e) {
      print('Error resolving staff for users: $e');
    }
  }

  Future<bool> updateUserRole(String username, String newRole) async {
    try {
      await _supabase.from('users').update({
        'role': newRole,
        'institution': UserRoles.institutionFor(newRole),
      }).eq('username', username);
      return true;
    } catch (e) {
      print('Error updating role for $username: $e');
      return false;
    }
  }

  /// Creates a login account and a profile row carrying [name].
  /// Returns `{success, message, username}`.
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String name,
    required String role,
    String? className,
    String? rollNumber,
    String? subject,
    String? department,
    String? createdBy,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanName = name.trim();
    if (!UserRoles.isSupported(role)) {
      return {'success': false, 'message': 'Unsupported role: $role'};
    }

    try {
      final authResult = await _supabase.rpc('secure_add_user_v2', params: {
        'p_username': cleanUsername,
        'p_password': password,
        'p_role': role,
        'p_created_by': createdBy ?? 'admin',
      });
      final result = Map<String, dynamic>.from(authResult as Map);
      if (result['success'] != true) {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to create user account',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Could not create account: $e'};
    }

    try {
      await _supabase.from('users').update({
        'institution': UserRoles.institutionFor(role),
      }).eq('username', cleanUsername);
    } catch (_) {
      // Column may not exist yet — the account itself already works.
    }

    try {
      final now = DateTime.now().toIso8601String();
      if (role == UserRoles.teacher) {
        await _supabase.from('teacher_details').insert({
          'teacher_id': cleanUsername,
          'name': cleanName,
          'employee_id': cleanUsername,
          'subject': (subject ?? '').trim().isEmpty ? '-' : subject!.trim(),
          'department':
              (department ?? '').trim().isEmpty ? '-' : department!.trim(),
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await _supabase.from('school_students').insert({
          'username': cleanUsername,
          'name': cleanName,
          'class_name': (className ?? '').trim(),
          'roll_number': (rollNumber ?? '').trim(),
        });
      }
    } catch (e) {
      // The login exists; surface the profile error so the admin can fix it.
      return {
        'success': true,
        'username': cleanUsername,
        'message': 'Account created, but saving the name failed: $e. '
            'Role changes are still applied from this screen.',
      };
    }

    return {
      'success': true,
      'username': cleanUsername,
      'message': 'Account created for $cleanName',
    };
  }
}
