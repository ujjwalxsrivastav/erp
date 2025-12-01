import 'package:supabase_flutter/supabase_flutter.dart';

class FeesService {
  final supabase = Supabase.instance.client;

  /// Get complete fee details for a student from database
  Future<Map<String, dynamic>> getStudentFees(
      String studentId, String academicYear) async {
    try {
      print('🎯 Fetching fees for student: $studentId, Year: $academicYear');

      // Get main fee record
      final feeData = await supabase
          .from('student_fees')
          .select()
          .eq('student_id', studentId)
          .eq('academic_year', academicYear)
          .maybeSingle();

      if (feeData == null) {
        throw Exception('No fee record found for student');
      }

      // Check bus enrollment
      final busData = await supabase
          .from('bus_fee_enrollment')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

      // Check hostel enrollment
      final hostelData = await supabase
          .from('hostel_fee_enrollment')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

      final result = {
        'student_id': studentId,
        'base_fee': (feeData['base_fee'] as num).toDouble(),
        'bus_fee':
            busData != null ? (busData['bus_fee'] as num).toDouble() : 0.0,
        'hostel_fee': hostelData != null
            ? (hostelData['hostel_fee'] as num).toDouble()
            : 0.0,
        'total_fee': (feeData['total_fee'] as num).toDouble(),
        'paid_amount': (feeData['paid_amount'] as num).toDouble(),
        'pending_amount': (feeData['pending_amount'] as num).toDouble(),
        'uses_bus': busData != null,
        'uses_hostel': hostelData != null,
        'last_payment_date': feeData['last_payment_date'],
      };

      print(
          '✅ Fees fetched: Total=${result['total_fee']}, Paid=${result['paid_amount']}, Pending=${result['pending_amount']}');
      return result;
    } catch (e) {
      print('❌ Error fetching student fees: $e');
      rethrow;
    }
  }

  /// Get payment history for a student
  Future<List<Map<String, dynamic>>> getPaymentHistory(
      String studentId, String academicYear) async {
    try {
      print('🎯 Fetching payment history for: $studentId, Year: $academicYear');

      final response = await supabase
          .from('fee_transactions')
          .select()
          .eq('student_id', studentId)
          .eq('academic_year', academicYear)
          .order('payment_date', ascending: false);

      print('✅ Found ${response.length} payment records');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching payment history: $e');
      return [];
    }
  }

  /// Create payment transaction
  Future<Map<String, dynamic>> createPaymentTransaction({
    required String studentId,
    required double amount,
    required String academicYear,
    String? razorpayOrderId,
  }) async {
    try {
      final response = await supabase
          .from('fee_transactions')
          .insert({
            'student_id': studentId,
            'amount': amount,
            'razorpay_order_id': razorpayOrderId,
            'academic_year': academicYear,
            'payment_status': 'pending',
          })
          .select()
          .single();

      print('✅ Payment transaction created: ${response['transaction_id']}');
      return response;
    } catch (e) {
      print('❌ Error creating payment transaction: $e');
      rethrow;
    }
  }

  /// Update payment status (triggers automatic fee update via database trigger)
  Future<void> updatePaymentStatus({
    required int transactionId,
    required String status,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    try {
      await supabase.from('fee_transactions').update({
        'payment_status': status,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
        'payment_date':
            status == 'success' ? DateTime.now().toIso8601String() : null,
      }).eq('transaction_id', transactionId);

      print('✅ Payment status updated: Transaction $transactionId -> $status');

      // Database trigger will automatically update student_fees table
    } catch (e) {
      print('❌ Error updating payment status: $e');
      rethrow;
    }
  }

  /// Get fee breakdown with paid/pending details
  Future<Map<String, dynamic>> getFeeBreakdown(
      String studentId, String academicYear) async {
    try {
      final feesData = await getStudentFees(studentId, academicYear);
      final payments = await getPaymentHistory(studentId, academicYear);

      // Calculate successful payments
      double totalPaid = 0.0;
      for (var payment in payments) {
        if (payment['payment_status'] == 'success') {
          totalPaid += (payment['amount'] as num).toDouble();
        }
      }

      return {
        'fees': feesData,
        'payments': payments,
        'total_paid': totalPaid,
        'payment_count':
            payments.where((p) => p['payment_status'] == 'success').length,
      };
    } catch (e) {
      print('❌ Error getting fee breakdown: $e');
      rethrow;
    }
  }

  /// Check if student can make partial payment
  bool canMakePartialPayment(double pendingAmount, double paymentAmount) {
    return paymentAmount > 0 && paymentAmount <= pendingAmount;
  }

  /// Get suggested payment amounts
  List<double> getSuggestedPayments(double pendingAmount) {
    if (pendingAmount <= 0) return [];

    List<double> suggestions = [];

    // Full amount
    suggestions.add(pendingAmount);

    // Half amount
    if (pendingAmount > 1000) {
      suggestions.add((pendingAmount / 2).roundToDouble());
    }

    // Quarter amount
    if (pendingAmount > 5000) {
      suggestions.add((pendingAmount / 4).roundToDouble());
    }

    // Common amounts
    if (pendingAmount > 10000) suggestions.add(10000);
    if (pendingAmount > 25000) suggestions.add(25000);
    if (pendingAmount > 50000) suggestions.add(50000);

    // Remove duplicates and sort
    suggestions = suggestions.toSet().toList();
    suggestions.sort((a, b) => b.compareTo(a)); // Descending order

    return suggestions;
  }
}
