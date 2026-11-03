import 'package:supabase_flutter/supabase_flutter.dart';

/// SuperAdmin / Institute Setup service.
///
/// Owns the institute master data created by
/// `run karwade/06_superadmin_setup.sql`:
/// departments, designations, academic_years and the
/// key/value institute_settings store (profile + branding).
class SuperAdminService {
  final _supabase = Supabase.instance.client;

  static const List<String> designationCategories = [
    'teaching',
    'non_teaching',
    'leadership',
  ];

  static const String profileKey = 'institute_profile';
  static const String brandingKey = 'branding';

  // ============================================================
  // DEPARTMENTS
  // ============================================================
  Future<List<Map<String, dynamic>>> getDepartments({
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase.from('departments').select();
      if (activeOnly) query = query.eq('is_active', true);
      final response = await query.order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get departments error: $e');
      return [];
    }
  }

  Future<bool> createDepartment({
    required String name,
    required String code,
    String? hodUsername,
    String? email,
    String? phone,
  }) async {
    try {
      await _supabase.from('departments').insert({
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'hod_username': (hodUsername ?? '').trim().isEmpty
            ? null
            : hodUsername!.trim(),
        'email': (email ?? '').trim().isEmpty ? null : email!.trim(),
        'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
      });
      return true;
    } catch (e) {
      print('Create department error: $e');
      return false;
    }
  }

  /// [fields] may contain name, code, hod_username, email, phone.
  Future<bool> updateDepartment(
    String id,
    Map<String, dynamic> fields,
  ) async {
    try {
      final data = Map<String, dynamic>.from(fields);
      if (data.containsKey('code')) {
        data['code'] = data['code'].toString().trim().toUpperCase();
      }
      data['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('departments').update(data).eq('id', id);
      return true;
    } catch (e) {
      print('Update department error: $e');
      return false;
    }
  }

  Future<bool> setDepartmentActive(String id, bool active) async {
    try {
      await _supabase.from('departments').update({
        'is_active': active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      print('Set department active error: $e');
      return false;
    }
  }

  /// Teachers of a department, for the HOD picker.
  /// teacher_details.department stores the department NAME (free text).
  Future<List<Map<String, dynamic>>> getTeachersForHod(
    String department,
  ) async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select('teacher_id, name, email, subject, department')
          .eq('department', department)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get teachers for HOD error: $e');
      return [];
    }
  }

  // ============================================================
  // DESIGNATIONS
  // ============================================================
  Future<List<Map<String, dynamic>>> getDesignations() async {
    try {
      final response = await _supabase
          .from('designations')
          .select()
          .order('category')
          .order('level', ascending: false)
          .order('title');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get designations error: $e');
      return [];
    }
  }

  Future<bool> createDesignation({
    required String title,
    required String category,
    int level = 1,
  }) async {
    try {
      await _supabase.from('designations').insert({
        'title': title.trim(),
        'category': category,
        'level': level,
      });
      return true;
    } catch (e) {
      print('Create designation error: $e');
      return false;
    }
  }

  /// [fields] may contain title, category, level, is_active.
  Future<bool> updateDesignation(
    String id,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _supabase.from('designations').update(fields).eq('id', id);
      return true;
    } catch (e) {
      print('Update designation error: $e');
      return false;
    }
  }

  // ============================================================
  // ACADEMIC YEARS
  // ============================================================
  Future<List<Map<String, dynamic>>> getAcademicYears() async {
    try {
      final response = await _supabase
          .from('academic_years')
          .select()
          .order('label', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get academic years error: $e');
      return [];
    }
  }

  Future<bool> createAcademicYear({
    required String label,
    DateTime? startDate,
    DateTime? endDate,
    bool isCurrent = false,
  }) async {
    try {
      if (isCurrent) {
        await _supabase
            .from('academic_years')
            .update({'is_current': false})
            .eq('is_current', true);
      }
      await _supabase.from('academic_years').insert({
        'label': label.trim(),
        'start_date': startDate?.toIso8601String().split('T')[0],
        'end_date': endDate?.toIso8601String().split('T')[0],
        'is_current': isCurrent,
      });
      return true;
    } catch (e) {
      print('Create academic year error: $e');
      return false;
    }
  }

  /// Makes [id] the single current academic year.
  Future<bool> setCurrentAcademicYear(String id) async {
    try {
      await _supabase
          .from('academic_years')
          .update({'is_current': false})
          .eq('is_current', true);
      await _supabase
          .from('academic_years')
          .update({'is_current': true})
          .eq('id', id);
      return true;
    } catch (e) {
      print('Set current academic year error: $e');
      return false;
    }
  }

  // ============================================================
  // INSTITUTE SETTINGS (key/value)
  // ============================================================
  Future<Map<String, dynamic>> getSettings(String key) async {
    try {
      final response = await _supabase
          .from('institute_settings')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final value = response?['value'];
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    } catch (e) {
      print('Get settings error: $e');
      return {};
    }
  }

  Future<bool> saveSettings(
    String key,
    Map<String, dynamic> value, {
    String updatedBy = 'superadmin',
  }) async {
    try {
      await _supabase.from('institute_settings').upsert({
        'key': key,
        'value': value,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Save settings error: $e');
      return false;
    }
  }

  // ============================================================
  // STATS (setup overview)
  // ============================================================
  Future<Map<String, dynamic>> getInstituteStats() async {
    try {
      final departments = await _supabase.from('departments').select('id');
      final designations = await _supabase
          .from('designations')
          .select('id')
          .eq('is_active', true);
      final userRows = await _supabase.from('users').select('role');
      final students =
          await _supabase.from('student_details').select('student_id');
      final teachers =
          await _supabase.from('teacher_details').select('teacher_id');
      final years = await _supabase
          .from('academic_years')
          .select('label')
          .eq('is_current', true)
          .maybeSingle();

      final usersByRole = <String, int>{};
      for (final row in userRows) {
        final role = (row['role'] ?? 'unknown').toString();
        usersByRole[role] = (usersByRole[role] ?? 0) + 1;
      }

      return {
        'departments': departments.length,
        'designations': designations.length,
        'totalUsers': userRows.length,
        'usersByRole': usersByRole,
        'students': students.length,
        'teachers': teachers.length,
        'currentYear': years?['label']?.toString(),
      };
    } catch (e) {
      print('Institute stats error: $e');
      return {
        'departments': 0,
        'designations': 0,
        'totalUsers': 0,
        'usersByRole': <String, int>{},
        'students': 0,
        'teachers': 0,
        'currentYear': null,
      };
    }
  }
}
