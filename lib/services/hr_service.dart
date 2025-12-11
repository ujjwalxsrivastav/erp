import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class HRService {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Fetch all staff members with pagination
  Future<List<Map<String, dynamic>>> getAllStaff({
    int page = 0,
    int limit = 25,
  }) async {
    try {
      final offset = page * limit;
      final response = await _supabase
          .from('teacher_details')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('📄 Fetched staff page $page (${response.length} items)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching staff: $e');
      return [];
    }
  }

  // Get total count of staff (for pagination)
  Future<int> getStaffCount() async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select('teacher_id')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      print('Error counting staff: $e');
      return 0;
    }
  }

  // Get next teacher ID
  Future<String> getNextTeacherId() async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select('teacher_id')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return 'teacher1';
      }

      final lastId = response[0]['teacher_id'] as String;
      // Extract number from teacher_id (e.g., "teacher5" -> 5)
      final match = RegExp(r'teacher(\d+)').firstMatch(lastId);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        return 'teacher${number + 1}';
      }
      return 'teacher1';
    } catch (e) {
      print('Error getting next teacher ID: $e');
      return 'teacher1';
    }
  }

  // Get next employee ID
  Future<String> getNextEmployeeId() async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select('employee_id')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return 'EMP001';
      }

      final lastId = response[0]['employee_id'] as String;
      // Extract number from employee_id (e.g., "EMP005" -> 5)
      final match = RegExp(r'EMP(\d+)').firstMatch(lastId);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        return 'EMP${(number + 1).toString().padLeft(3, '0')}';
      }
      return 'EMP001';
    } catch (e) {
      print('Error getting next employee ID: $e');
      return 'EMP001';
    }
  }

  // Fetch single staff member details
  Future<Map<String, dynamic>?> getStaffDetails(String employeeId) async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select()
          .eq('employee_id', employeeId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching staff details: $e');
      return null;
    }
  }

  // Fetch staff salary details
  Future<Map<String, dynamic>?> getStaffSalary(String employeeId) async {
    try {
      final response = await _supabase
          .from('teacher_salary')
          .select()
          .eq('employee_id', employeeId)
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching salary: $e');
      return null;
    }
  }

  // Fetch staff activity logs
  Future<List<Map<String, dynamic>>> getStaffActivityLogs(
      String employeeId) async {
    try {
      final response = await _supabase
          .from('teacher_activity_logs')
          .select()
          .eq('employee_id', employeeId)
          .order('performed_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching activity logs: $e');
      return [];
    }
  }

  // Update staff personal details
  Future<bool> updateStaffPersonalDetails({
    required String employeeId,
    required Map<String, dynamic> data,
    required String updatedBy,
  }) async {
    try {
      await _supabase.from('teacher_details').update({
        ...data,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('employee_id', employeeId);

      return true;
    } catch (e) {
      print('Error updating personal details: $e');
      return false;
    }
  }

  // Update staff professional details
  Future<bool> updateStaffProfessionalDetails({
    required String employeeId,
    required Map<String, dynamic> data,
    required String updatedBy,
  }) async {
    try {
      await _supabase.from('teacher_details').update({
        ...data,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('employee_id', employeeId);

      return true;
    } catch (e) {
      print('Error updating professional details: $e');
      return false;
    }
  }

  // Update staff salary
  Future<bool> updateStaffSalary({
    required String employeeId,
    required Map<String, dynamic> salaryData,
    required String updatedBy,
  }) async {
    try {
      // Deactivate old salary records
      await _supabase
          .from('teacher_salary')
          .update({
            'is_active': false,
            'effective_to': DateTime.now().toIso8601String().split('T')[0],
          })
          .eq('employee_id', employeeId)
          .eq('is_active', true);

      // Insert new salary record
      await _supabase.from('teacher_salary').insert({
        'employee_id': employeeId,
        ...salaryData,
        'is_active': true,
        'effective_from': DateTime.now().toIso8601String().split('T')[0],
        'created_by': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error updating salary: $e');
      return false;
    }
  }

  // Update staff education & experience
  Future<bool> updateStaffExperience({
    required String employeeId,
    required Map<String, dynamic> data,
    required String updatedBy,
  }) async {
    try {
      await _supabase.from('teacher_details').update({
        ...data,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('employee_id', employeeId);

      return true;
    } catch (e) {
      print('Error updating experience: $e');
      return false;
    }
  }

  // Update staff status
  Future<bool> updateStaffStatus({
    required String employeeId,
    required String status,
    required String updatedBy,
  }) async {
    try {
      await _supabase.from('teacher_details').update({
        'status': status,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('employee_id', employeeId);

      // Log the status change
      await _supabase.from('teacher_activity_logs').insert({
        'employee_id': employeeId,
        'activity_type': 'Status Changed',
        'activity_title': 'Status Updated',
        'activity_description': 'Employee status changed to $status',
        'performed_by': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }

  // Upload document
  Future<String?> uploadDocument({
    required String employeeId,
    required String documentType,
    required String filePath,
    required List<int> fileBytes,
  }) async {
    try {
      final fileName =
          '$employeeId\_$documentType\_${DateTime.now().millisecondsSinceEpoch}';

      await _supabase.storage
          .from('teacher-documents')
          .uploadBinary(fileName, Uint8List.fromList(fileBytes));

      final publicUrl =
          _supabase.storage.from('teacher-documents').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading document: $e');
      return null;
    }
  }

  // Update document URL in database
  Future<bool> updateDocumentUrl({
    required String employeeId,
    required String documentField,
    required String documentUrl,
    required String updatedBy,
  }) async {
    try {
      await _supabase.from('teacher_details').update({
        documentField: documentUrl,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('employee_id', employeeId);

      // Log document upload
      await _supabase.from('teacher_activity_logs').insert({
        'employee_id': employeeId,
        'activity_type': 'Document Uploaded',
        'activity_title': 'Document Uploaded',
        'activity_description': '$documentField uploaded successfully',
        'performed_by': updatedBy,
      });

      return true;
    } catch (e) {
      print('Error updating document URL: $e');
      return false;
    }
  }

  // Search staff
  Future<List<Map<String, dynamic>>> searchStaff(String query) async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select()
          .or('name.ilike.%$query%,employee_id.ilike.%$query%,department.ilike.%$query%,designation.ilike.%$query%')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching staff: $e');
      return [];
    }
  }

  // Get staff by department
  Future<List<Map<String, dynamic>>> getStaffByDepartment(
      String department) async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select()
          .eq('department', department)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching staff by department: $e');
      return [];
    }
  }

  // Get staff by status
  Future<List<Map<String, dynamic>>> getStaffByStatus(String status) async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select()
          .eq('status', status)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching staff by status: $e');
      return [];
    }
  }

  // Create new staff member
  Future<bool> createStaff({
    required Map<String, dynamic> staffData,
    required String createdBy,
  }) async {
    try {
      await _supabase.from('teacher_details').insert({
        ...staffData,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Log creation
      await _supabase.from('teacher_activity_logs').insert({
        'employee_id': staffData['employee_id'],
        'activity_type': 'Profile Created',
        'activity_title': 'New Employee Onboarded',
        'activity_description': 'Employee profile created in the system',
        'performed_by': createdBy,
      });

      return true;
    } catch (e) {
      print('Error creating staff: $e');
      return false;
    }
  }

  // Delete staff member (soft delete by changing status)
  Future<bool> deleteStaff({
    required String employeeId,
    required String deletedBy,
  }) async {
    try {
      await _supabase.from('teacher_details').update({
        'status': 'Terminated',
        'updated_by': deletedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('employee_id', employeeId);

      // Log deletion
      await _supabase.from('teacher_activity_logs').insert({
        'employee_id': employeeId,
        'activity_type': 'Status Changed',
        'activity_title': 'Employee Terminated',
        'activity_description': 'Employee status changed to Terminated',
        'performed_by': deletedBy,
      });

      return true;
    } catch (e) {
      print('Error deleting staff: $e');
      return false;
    }
  }
}
