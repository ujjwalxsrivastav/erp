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
  static const String counsellor = 'counsellor';
  static const String admin = 'admin';

  static const List<String> all = [student, teacher, counsellor, admin];

  static String label(String role) => switch (role) {
        student => 'Student',
        teacher => 'Teacher',
        counsellor => 'Counsellor',
        admin => 'Admin',
        _ =>
          role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}',
      };

  /// `users.institution` / `users.institute_type` — decides which dashboard
  /// the account lands on. [preferredInstitution] lets the screen pass the
  /// institution the admin is currently creating accounts for.
  static String institutionFor(String role, {String? preferredInstitution}) {
    final preferred = (preferredInstitution ?? '').trim().toLowerCase();
    if (preferred == 'school' || preferred == 'college') return preferred;
    return role == admin ? 'college' : 'school';
  }

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
      final teachers = await _supabase
          .from('school_teachers')
          .select('username, name, subject')
          .inFilter('username', ids);
      final byId = <String, Map<String, dynamic>>{
        for (final t in List<Map<String, dynamic>>.from(teachers))
          t['username'] as String: t,
      };
      for (final u in users) {
        final t = byId[u['username']];
        if (t == null) continue;
        u['display_name'] = t['name'];
        final subject = (t['subject'] ?? '').toString();
        if (subject.isNotEmpty) {
          u['detail'] = '$subject • School teacher';
        }
      }
    } catch (e) {
      print('Error resolving school teacher directory for users: $e');
    }

    try {
      final counsellors = await _supabase
          .from('school_counsellors')
          .select('username, name, phone, email, assignments_count')
          .inFilter('username', ids);
      final byId = <String, Map<String, dynamic>>{
        for (final c in List<Map<String, dynamic>>.from(counsellors))
          c['username'] as String: c,
      };
      for (final u in users) {
        final c = byId[u['username']];
        if (c == null) continue;
        u['display_name'] = c['name'];
        final phone = (c['phone'] ?? '').toString();
        final load = (c['assignments_count'] as num?)?.toInt() ?? 0;
        u['detail'] = [
          'Admission counsellor',
          if (phone.isNotEmpty) phone,
          '$load allotted',
        ].join(' • ');
      }
    } catch (e) {
      // Table may not exist until database/school_counsellors_setup.sql runs.
      print('Error resolving counsellor directory for users: $e');
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

  /// Keeps the legacy `users.institution` column and the dual-mode
  /// `users.institute_type` column in sync, tolerating databases that only
  /// have one of them.
  Future<void> _applyInstitution(String username, String institution) async {
    try {
      await _supabase.from('users').update({
        'institution': institution,
        'institute_type': institution,
      }).eq('username', username);
      return;
    } catch (_) {}
    try {
      await _supabase
          .from('users')
          .update({'institution': institution}).eq('username', username);
      return;
    } catch (_) {}
    try {
      await _supabase
          .from('users')
          .update({'institute_type': institution}).eq('username', username);
    } catch (_) {}
  }

  String? _nullIfBlank(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  /// Adds/refreshes the school teacher directory row used by the teacher
  /// dashboard and homework cards to show a real name.
  Future<bool> _upsertSchoolTeacher(
      String username, String name, String? subject) async {
    final cleanSubject = (subject ?? '').trim();
    try {
      await _supabase.from('school_teachers').upsert({
        'username': username,
        'name': name,
        if (cleanSubject.isNotEmpty) 'subject': cleanSubject,
      }, onConflict: 'username');
      return true;
    } catch (e) {
      print('Error saving school teacher $username: $e');
      return false;
    }
  }

  /// Adds/refreshes the school counsellor directory row. This is what the
  /// round-robin allotment engine reads when assigning admission forms.
  Future<bool> _upsertCounsellor({
    required String username,
    required String name,
    String? email,
    String? phone,
  }) async {
    final cleanEmail = _nullIfBlank(email);
    final cleanPhone = _nullIfBlank(phone);
    try {
      await _supabase.from('school_counsellors').upsert({
        'username': username,
        'name': name,
        'is_active': true,
        if (cleanEmail != null) 'email': cleanEmail,
        if (cleanPhone != null) 'phone': cleanPhone,
      }, onConflict: 'username');
      return true;
    } catch (e) {
      print('Error saving school counsellor $username: $e');
      return false;
    }
  }

  Future<bool> updateUserRole(
    String username,
    String newRole, {
    String? name,
    String? institution,
  }) async {
    if (!UserRoles.isSupported(newRole)) return false;

    try {
      await _supabase
          .from('users')
          .update({'role': newRole}).eq('username', username);
    } catch (e) {
      print('Error updating role for $username: $e');
      return false;
    }

    final targetInstitution =
        UserRoles.institutionFor(newRole, preferredInstitution: institution);
    await _applyInstitution(username, targetInstitution);

    final displayName = (name ?? '').trim();
    final safeName = displayName.isEmpty ? username : displayName;

    if (newRole == UserRoles.counsellor) {
      // Make sure the allocator can pick this person for new admissions.
      await _upsertCounsellor(username: username, name: safeName);
    } else {
      // Stop offering the account to the round-robin allocator.
      try {
        await _supabase
            .from('school_counsellors')
            .update({'is_active': false}).eq('username', username);
      } catch (_) {}
    }

    if (newRole == UserRoles.teacher &&
        targetInstitution == 'school' &&
        displayName.isNotEmpty) {
      await _upsertSchoolTeacher(username, displayName, null);
    }

    return true;
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
    String? email,
    String? phone,
    String? institution,
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

    final targetInstitution =
        UserRoles.institutionFor(role, preferredInstitution: institution);
    await _applyInstitution(cleanUsername, targetInstitution);

    var profileSaved = false;
    String? profileError;

    try {
      if (role == UserRoles.teacher) {
        if (targetInstitution == 'school') {
          profileSaved =
              await _upsertSchoolTeacher(cleanUsername, cleanName, subject);
        }
        if (!profileSaved) {
          final now = DateTime.now().toIso8601String();
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
          profileSaved = true;
        }
      } else if (role == UserRoles.counsellor) {
        profileSaved = await _upsertCounsellor(
          username: cleanUsername,
          name: cleanName,
          email: email,
          phone: phone,
        );
        if (!profileSaved) {
          profileError = 'the school_counsellors table is unavailable — run '
              'database/school_counsellors_setup.sql';
        }
      } else if (role == UserRoles.student) {
        await _supabase.from('school_students').insert({
          'username': cleanUsername,
          'name': cleanName,
          'class_name': (className ?? '').trim(),
          'roll_number': (rollNumber ?? '').trim(),
        });
        profileSaved = true;
      } else {
        // Admin accounts do not need a profile row.
        profileSaved = true;
      }
    } catch (e) {
      profileError = e.toString();
    }

    if (!profileSaved) {
      // The login exists; surface the profile error so the admin can fix it.
      return {
        'success': true,
        'username': cleanUsername,
        'message': 'Account created, but saving the '
            '${UserRoles.label(role).toLowerCase()} profile failed: '
            '${profileError ?? 'unknown error'}. '
            'Role changes are still applied from this screen.',
      };
    }

    return {
      'success': true,
      'username': cleanUsername,
      'message': '${UserRoles.label(role)} account created for $cleanName',
    };
  }
}
