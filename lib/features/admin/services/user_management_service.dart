import 'package:supabase_flutter/supabase_flutter.dart';

/// Roles allowed by the `users` table CHECK constraint
/// (see database_export/schema.sql and update_users_role_constraint.sql).
/// Note: 'HR' is stored uppercase in the database.
class UserRoles {
  static const List<String> all = [
    'student',
    'teacher',
    'admin',
    'staff',
    'HR',
    'hod',
  ];

  static String label(String role) {
    switch (role) {
      case 'HR':
        return 'HR';
      case 'hod':
        return 'HOD';
      default:
        return role.isEmpty
            ? role
            : '${role[0].toUpperCase()}${role.substring(1)}';
    }
  }
}

/// Admin — Manage Users.
///
/// The `users` table only carries username / password / role (no status
/// or active flag), so this service intentionally offers listing,
/// searching and role changes only — no activate/deactivate.
class UserManagementService {
  final _supabase = Supabase.instance.client;

  /// All login accounts, optionally filtered by [role] and/or a
  /// username [search] term. Each row is enriched (where resolvable)
  /// with `display_name` and `detail` from student_details /
  /// teacher_details so the UI can show a real name, not just an id.
  Future<List<Map<String, dynamic>>> getAllUsers({
    String? role,
    String? search,
  }) async {
    try {
      var query = _supabase.from('users').select('username, role');
      if (role != null && role.isNotEmpty) {
        query = query.eq('role', role);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('username', '%${search.trim()}%');
      }
      final response = await query.order('username', ascending: true);
      final users = List<Map<String, dynamic>>.from(response);
      await _attachDetails(users);
      return users;
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  /// Resolves display names/details for the given user rows with two
  /// batched lookups (students by student_id, staff by teacher_id).
  Future<void> _attachDetails(List<Map<String, dynamic>> users) async {
    if (users.isEmpty) return;
    final usernames = users.map((u) => u['username'] as String).toList();

    try {
      final students = await _supabase
          .from('student_details')
          .select('student_id, name, department, year, semester, section')
          .inFilter('student_id', usernames);
      final byId = <String, Map<String, dynamic>>{
        for (final s in List<Map<String, dynamic>>.from(students))
          s['student_id'] as String: s,
      };
      for (final u in users) {
        final s = byId[u['username']];
        if (s != null) {
          u['display_name'] = s['name'];
          u['detail'] =
              '${s['department']} • Year ${s['year']} • Sem ${s['semester']} • Sec ${s['section']}';
        }
      }
    } catch (e) {
      print('Error resolving student details for users: $e');
    }

    try {
      final teachers = await _supabase
          .from('teacher_details')
          .select('teacher_id, name, department, subject')
          .inFilter('teacher_id', usernames);
      final byId = <String, Map<String, dynamic>>{
        for (final t in List<Map<String, dynamic>>.from(teachers))
          t['teacher_id'] as String: t,
      };
      for (final u in users) {
        if (u['display_name'] != null) continue;
        final t = byId[u['username']];
        if (t != null) {
          u['display_name'] = t['name'];
          u['detail'] = '${t['department']} • ${t['subject']}';
        }
      }
    } catch (e) {
      print('Error resolving teacher details for users: $e');
    }
  }

  /// Live count of accounts per role, plus a 'total' key.
  Future<Map<String, int>> getRoleCounts() async {
    try {
      final response = await _supabase.from('users').select('role');
      final counts = <String, int>{'total': 0};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final role = (row['role'] ?? '').toString();
        counts[role] = (counts[role] ?? 0) + 1;
        counts['total'] = (counts['total'] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      print('Error fetching role counts: $e');
      return {'total': 0};
    }
  }

  /// Changes a user's role. [newRole] must be one of [UserRoles.all]
  /// (the database CHECK constraint rejects anything else).
  Future<bool> updateUserRole(String username, String newRole) async {
    try {
      await _supabase
          .from('users')
          .update({'role': newRole}).eq('username', username);
      return true;
    } catch (e) {
      print('Error updating role for $username: $e');
      return false;
    }
  }
}
