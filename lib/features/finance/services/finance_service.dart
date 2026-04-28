import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceService {
  final _supabase = Supabase.instance.client;

  // Get all students to assign fees
  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      final response = await _supabase
          .from('users')
          .select('username')
          .eq('role', 'student');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting students: $e');
      return [];
    }
  }

  // Get all departments
  Future<List<String>> getDepartments() async {
    try {
      final response = await _supabase
          .from('student_details')
          .select('department');
      final deps = response
          .map((e) => e['department'] as String?)
          .where((e) => e != null && e.trim().isNotEmpty)
          .toSet()
          .toList();
      if (deps.isEmpty) {
        return ['Computer Science', 'Mechanical', 'Electrical', 'Civil', 'Business', 'General'];
      }
      return deps.cast<String>();
    } catch (e) {
      print('Error getting departments: $e');
      return ['Computer Science', 'Mechanical', 'Electrical', 'Civil', 'Business', 'General'];
    }
  }

  // Get fees applied to a specific department
  Future<List<Map<String, dynamic>>> getDepartmentFees(String department) async {
    try {
      final students = await _supabase
          .from('student_details')
          .select('student_id')
          .eq('department', department);
      
      final studentIds = students.map((e) => e['student_id'] as String).toList();
      if (studentIds.isEmpty) return [];

      final response = await _supabase
          .from('finance_student_fees')
          .select()
          .inFilter('student_id', studentIds)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> fees = List<Map<String, dynamic>>.from(response);
      Map<String, Map<String, dynamic>> uniqueFees = {};
      
      for (var f in fees) {
        final key = '${f['fee_type']}_${f['amount']}_${f['due_date']}';
        if (!uniqueFees.containsKey(key)) {
          uniqueFees[key] = f;
        }
      }
      return uniqueFees.values.toList();
    } catch (e) {
      print('Error getting department fees: $e');
      return [];
    }
  }

  // Add fee to all students in a department
  Future<bool> addFeeToDepartment(String department, String feeType, double amount, String? dueDate) async {
    try {
      final students = await _supabase
          .from('student_details')
          .select('student_id')
          .eq('department', department);
      
      final studentIds = students.map((e) => e['student_id'] as String).toList();
      if (studentIds.isEmpty) return false;

      final records = studentIds.map((id) => {
        'student_id': id,
        'fee_type': feeType,
        'amount': amount,
        'status': 'pending',
        'due_date': dueDate,
      }).toList();

      await _supabase.from('finance_student_fees').insert(records);
      return true;
    } catch (e) {
      print('Error adding fee to department: $e');
      return false;
    }
  }

  // Get fees for a specific student
  Future<List<Map<String, dynamic>>> getStudentFees(String studentId) async {
    try {
      await _syncLegacyFees(studentId);

      final response = await _supabase
          .from('finance_student_fees')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting student fees: $e');
      return [];
    }
  }

  // Auto-sync transport and hostel fees from legacy tables
  Future<void> _syncLegacyFees(String studentId) async {
    try {
      // 1. Sync Transport Fee
      final transportData = await _supabase
          .from('bus_fee_enrollment')
          .select('bus_fee')
          .eq('student_id', studentId)
          .maybeSingle();
      
      if (transportData != null && transportData['bus_fee'] != null) {
        final existing = await _supabase
            .from('finance_student_fees')
            .select()
            .eq('student_id', studentId)
            .ilike('fee_type', '%Transport%')
            .maybeSingle();
            
        if (existing == null) {
          await _supabase.from('finance_student_fees').insert({
            'student_id': studentId,
            'fee_type': 'Transport Fee',
            'amount': (transportData['bus_fee'] as num).toDouble(),
            'status': 'pending',
          });
        }
      }

      // 2. Sync Hostel Fee
      final hostelData = await _supabase
          .from('hostel_fee_enrollment')
          .select('hostel_fee')
          .eq('student_id', studentId)
          .maybeSingle();

      if (hostelData != null && hostelData['hostel_fee'] != null) {
        final existing = await _supabase
            .from('finance_student_fees')
            .select()
            .eq('student_id', studentId)
            .ilike('fee_type', '%Hostel%')
            .maybeSingle();
            
        if (existing == null) {
          await _supabase.from('finance_student_fees').insert({
            'student_id': studentId,
            'fee_type': 'Hostel Fee',
            'amount': (hostelData['hostel_fee'] as num).toDouble(),
            'status': 'pending',
          });
        }
      }
    } catch (e) {
      print('Legacy fee sync error: $e');
    }
  }

  // Add fee to a student
  Future<bool> addFee(String studentId, String feeType, double amount, String? dueDate) async {
    try {
      await _supabase.from('finance_student_fees').insert({
        'student_id': studentId,
        'fee_type': feeType,
        'amount': amount,
        'status': 'pending',
        'due_date': dueDate,
      });
      return true;
    } catch (e) {
      print('Error adding fee: $e');
      return false;
    }
  }

  // Pay selected fees (Student side)
  Future<bool> payFees(String studentId, List<Map<String, dynamic>> selectedFees, String paymentMethod) async {
    try {
      double totalAmount = 0;
      List<String> feeIds = [];

      for (var fee in selectedFees) {
        totalAmount += (fee['amount'] as num).toDouble();
        feeIds.add(fee['id'].toString());
      }

      final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';

      // Record transaction
      await _supabase.from('finance_transactions').insert({
        'student_id': studentId,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'transaction_reference': transactionId,
        'fee_ids': feeIds,
      });

      // Update fee status
      for (var id in feeIds) {
        await _supabase.from('finance_student_fees').update({
          'status': 'paid',
          'paid_at': DateTime.now().toIso8601String(),
          'transaction_id': transactionId,
        }).eq('id', id);
      }

      return true;
    } catch (e) {
      print('Error paying fees: $e');
      return false;
    }
  }

  // Get all transactions for accountant reports
  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final response = await _supabase
          .from('finance_transactions')
          .select()
          .order('transaction_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }
}
