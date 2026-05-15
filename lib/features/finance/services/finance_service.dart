import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceService {
  final _supabase = Supabase.instance.client;

  // ============================================================
  // DASHBOARD DATA
  // ============================================================
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

      // Total collections
      final allReceipts = await _supabase.from('fee_receipts').select('total_amount, receipt_date, payment_mode, status').eq('status', 'completed');
      
      double totalCollected = 0, todayCollection = 0, monthlyRevenue = 0;
      int cashCount = 0, onlineCount = 0;
      double cashAmount = 0, onlineAmount = 0;
      
      for (var r in allReceipts) {
        final amt = (r['total_amount'] as num?)?.toDouble() ?? 0;
        totalCollected += amt;
        if (r['receipt_date'] == todayStr) todayCollection += amt;
        if (r['receipt_date'] != null && r['receipt_date'].compareTo(monthStart) >= 0) monthlyRevenue += amt;
        if (r['payment_mode'] == 'cash') { cashCount++; cashAmount += amt; }
        else { onlineCount++; onlineAmount += amt; }
      }

      // Pending dues
      final pendingAllocations = await _supabase.from('student_fee_allocations').select('balance_amount, status').neq('status', 'paid').neq('status', 'waived').neq('status', 'cancelled');
      double pendingDues = 0;
      int defaultersCount = 0;
      for (var a in pendingAllocations) {
        final bal = (a['balance_amount'] as num?)?.toDouble() ?? 0;
        pendingDues += bal;
        if (a['status'] == 'overdue') defaultersCount++;
      }

      // Scholarships
      final scholarshipData = await _supabase.from('student_scholarships').select('approved_amount').eq('status', 'approved');
      double scholarshipTotal = 0;
      for (var s in scholarshipData) {
        scholarshipTotal += (s['approved_amount'] as num?)?.toDouble() ?? 0;
      }

      // Refunds
      final refundData = await _supabase.from('refund_requests').select('amount').eq('status', 'completed');
      double refundTotal = 0;
      for (var r in refundData) {
        refundTotal += (r['amount'] as num?)?.toDouble() ?? 0;
      }

      // Pending approvals
      final pendingApprovals = await _supabase.from('approval_workflows').select('id').eq('status', 'pending');

      // Recent transactions
      final recentTxns = await _supabase.from('fee_receipts').select().eq('status', 'completed').order('created_at', ascending: false).limit(10);

      return {
        'totalCollected': totalCollected,
        'pendingDues': pendingDues,
        'todayCollection': todayCollection,
        'monthlyRevenue': monthlyRevenue,
        'scholarshipTotal': scholarshipTotal,
        'refundTotal': refundTotal,
        'defaultersCount': defaultersCount,
        'pendingApprovals': pendingApprovals.length,
        'cashAmount': cashAmount,
        'onlineAmount': onlineAmount,
        'cashCount': cashCount,
        'onlineCount': onlineCount,
        'recentTransactions': List<Map<String, dynamic>>.from(recentTxns),
      };
    } catch (e) {
      print('Dashboard stats error: $e');
      return {
        'totalCollected': 0.0, 'pendingDues': 0.0, 'todayCollection': 0.0,
        'monthlyRevenue': 0.0, 'scholarshipTotal': 0.0, 'refundTotal': 0.0,
        'defaultersCount': 0, 'pendingApprovals': 0, 'cashAmount': 0.0,
        'onlineAmount': 0.0, 'cashCount': 0, 'onlineCount': 0,
        'recentTransactions': <Map<String, dynamic>>[],
      };
    }
  }

  // ============================================================
  // DEPARTMENT-WISE REVENUE
  // ============================================================
  Future<List<Map<String, dynamic>>> getDepartmentRevenue() async {
    try {
      final depts = await getDepartments();
      List<Map<String, dynamic>> result = [];
      for (var dept in depts) {
        final students = await _supabase.from('student_details').select('student_id').eq('department', dept);
        final ids = students.map((s) => s['student_id'] as String).toList();
        if (ids.isEmpty) { result.add({'department': dept, 'collected': 0.0, 'pending': 0.0}); continue; }
        final allocations = await _supabase.from('student_fee_allocations').select('paid_amount, balance_amount').inFilter('student_id', ids);
        double collected = 0, pending = 0;
        for (var a in allocations) {
          collected += (a['paid_amount'] as num?)?.toDouble() ?? 0;
          pending += (a['balance_amount'] as num?)?.toDouble() ?? 0;
        }
        result.add({'department': dept, 'collected': collected, 'pending': pending});
      }
      return result;
    } catch (e) {
      print('Dept revenue error: $e');
      return [];
    }
  }

  // ============================================================
  // STUDENTS
  // ============================================================
  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      final response = await _supabase.from('users').select('username').eq('role', 'student');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) { return []; }
  }

  Future<List<Map<String, dynamic>>> getStudentsWithDetails() async {
    try {
      final response = await _supabase.from('student_details').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) { return []; }
  }

  Future<List<String>> getDepartments() async {
    try {
      final response = await _supabase.from('student_details').select('department');
      final deps = response.map((e) => e['department'] as String?).where((e) => e != null && e.trim().isNotEmpty).toSet().toList();
      return deps.isEmpty ? ['Computer Science', 'Mechanical', 'Electrical', 'Civil', 'Business'] : deps.cast<String>();
    } catch (e) { return ['Computer Science', 'Mechanical', 'Electrical', 'Civil', 'Business']; }
  }

  // ============================================================
  // FEE HEADS
  // ============================================================
  Future<List<Map<String, dynamic>>> getFeeHeads() async {
    try {
      final r = await _supabase.from('fee_heads').select().order('display_order');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> createFeeHead(Map<String, dynamic> data) async {
    try { await _supabase.from('fee_heads').insert(data); return true; }
    catch (e) { print('Create fee head error: $e'); return false; }
  }

  Future<bool> updateFeeHead(String id, Map<String, dynamic> data) async {
    try { await _supabase.from('fee_heads').update(data).eq('id', id); return true; }
    catch (e) { return false; }
  }

  Future<bool> deleteFeeHead(String id) async {
    try { await _supabase.from('fee_heads').delete().eq('id', id); return true; }
    catch (e) { return false; }
  }

  // ============================================================
  // FEE STRUCTURES
  // ============================================================
  Future<List<Map<String, dynamic>>> getFeeStructures() async {
    try {
      final r = await _supabase.from('fee_structures').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> createFeeStructure(Map<String, dynamic> data, List<Map<String, dynamic>> items) async {
    try {
      final res = await _supabase.from('fee_structures').insert(data).select().single();
      final structureId = res['id'];
      for (var item in items) {
        item['fee_structure_id'] = structureId;
      }
      if (items.isNotEmpty) await _supabase.from('fee_structure_items').insert(items);
      return true;
    } catch (e) { print('Create fee structure error: $e'); return false; }
  }

  Future<List<Map<String, dynamic>>> getFeeStructureItems(String structureId) async {
    try {
      final r = await _supabase.from('fee_structure_items').select().eq('fee_structure_id', structureId).order('display_order');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  // ============================================================
  // STUDENT FEE ALLOCATIONS
  // ============================================================
  Future<List<Map<String, dynamic>>> getStudentAllocations(String studentId) async {
    try {
      final r = await _supabase.from('student_fee_allocations').select().eq('student_id', studentId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> allocateFeesToStudent(String studentId, String structureId) async {
    try {
      final items = await getFeeStructureItems(structureId);
      final structure = await _supabase.from('fee_structures').select().eq('id', structureId).single();
      for (var item in items) {
        final amount = (item['amount'] as num).toDouble();
        await _supabase.from('student_fee_allocations').insert({
          'student_id': studentId,
          'fee_structure_id': structureId,
          'fee_head_id': item['fee_head_id'],
          'original_amount': amount,
          'net_amount': amount,
          'balance_amount': amount,
          'due_date': item['due_date'],
          'semester': structure['semester'],
          'academic_year': structure['academic_year'],
        });
      }
      await _logAudit('student_fee_allocation', null, 'create', null, {'student_id': studentId, 'structure': structureId}, 'accountant1');
      return true;
    } catch (e) { print('Allocate fees error: $e'); return false; }
  }

  Future<bool> allocateFeesToDepartment(String department, String structureId) async {
    try {
      final students = await _supabase.from('student_details').select('student_id').eq('department', department);
      for (var s in students) {
        await allocateFeesToStudent(s['student_id'], structureId);
      }
      return true;
    } catch (e) { return false; }
  }

  // ============================================================
  // RECEIPTS
  // ============================================================
  Future<List<Map<String, dynamic>>> getReceipts({String? studentId}) async {
    try {
      var query = _supabase.from('fee_receipts').select();
      if (studentId != null) query = query.eq('student_id', studentId);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<String?> createReceipt(String studentId, List<Map<String, dynamic>> allocations, String paymentMode, {String? paymentRef, String? collectedBy}) async {
    try {
      double total = 0;
      for (var a in allocations) total += (a['amount'] as num).toDouble();
      final receiptNum = 'REC-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final receipt = await _supabase.from('fee_receipts').insert({
        'receipt_number': receiptNum,
        'student_id': studentId,
        'total_amount': total,
        'payment_mode': paymentMode,
        'payment_reference': paymentRef,
        'collected_by': collectedBy ?? 'accountant1',
      }).select().single();
      final receiptId = receipt['id'];
      for (var a in allocations) {
        await _supabase.from('fee_receipt_items').insert({
          'receipt_id': receiptId,
          'allocation_id': a['allocation_id'],
          'fee_head_id': a['fee_head_id'],
          'amount': a['amount'],
        });
        final alloc = await _supabase.from('student_fee_allocations').select().eq('id', a['allocation_id']).single();
        final newPaid = ((alloc['paid_amount'] as num?)?.toDouble() ?? 0) + (a['amount'] as num).toDouble();
        final newBalance = ((alloc['net_amount'] as num).toDouble()) - newPaid;
        await _supabase.from('student_fee_allocations').update({
          'paid_amount': newPaid,
          'balance_amount': newBalance,
          'status': newBalance <= 0 ? 'paid' : 'partial',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', a['allocation_id']);
      }
      await _logAudit('fee_receipt', receiptId, 'create', null, {'receipt_number': receiptNum, 'student_id': studentId, 'amount': total}, collectedBy ?? 'accountant1');
      return receiptNum;
    } catch (e) { print('Create receipt error: $e'); return null; }
  }

  // ============================================================
  // CHART OF ACCOUNTS
  // ============================================================
  Future<List<Map<String, dynamic>>> getChartOfAccounts() async {
    try {
      final r = await _supabase.from('chart_of_accounts').select().order('account_code');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> createAccount(Map<String, dynamic> data) async {
    try { await _supabase.from('chart_of_accounts').insert(data); return true; }
    catch (e) { return false; }
  }

  // ============================================================
  // JOURNAL ENTRIES
  // ============================================================
  Future<List<Map<String, dynamic>>> getJournalEntries() async {
    try {
      final r = await _supabase.from('journal_entries').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<List<Map<String, dynamic>>> getJournalEntryLines(String entryId) async {
    try {
      final r = await _supabase.from('journal_entry_lines').select().eq('journal_entry_id', entryId);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> createJournalEntry(Map<String, dynamic> header, List<Map<String, dynamic>> lines) async {
    try {
      final entryNum = 'JE-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      header['entry_number'] = entryNum;
      final res = await _supabase.from('journal_entries').insert(header).select().single();
      final entryId = res['id'];
      for (var line in lines) {
        line['journal_entry_id'] = entryId;
        await _supabase.from('journal_entry_lines').insert(line);
      }
      await _logAudit('journal_entry', entryId, 'create', null, header, header['created_by'] ?? 'accountant1');
      return true;
    } catch (e) { print('Create JE error: $e'); return false; }
  }

  Future<bool> approveJournalEntry(String entryId, String approvedBy) async {
    try {
      await _supabase.from('journal_entries').update({'status': 'approved', 'approved_by': approvedBy, 'approved_at': DateTime.now().toIso8601String()}).eq('id', entryId);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> postJournalEntry(String entryId) async {
    try {
      final lines = await getJournalEntryLines(entryId);
      for (var line in lines) {
        await _supabase.from('general_ledger').insert({
          'account_id': line['account_id'],
          'journal_entry_id': entryId,
          'debit_amount': line['debit_amount'],
          'credit_amount': line['credit_amount'],
          'narration': line['narration'],
          'reference_type': 'journal_entry',
          'reference_id': entryId,
          'is_auto_posted': false,
        });
      }
      await _supabase.from('journal_entries').update({'status': 'posted', 'posted_at': DateTime.now().toIso8601String()}).eq('id', entryId);
      return true;
    } catch (e) { return false; }
  }

  // ============================================================
  // GENERAL LEDGER
  // ============================================================
  Future<List<Map<String, dynamic>>> getLedgerEntries({String? accountId, String? dateFrom, String? dateTo}) async {
    try {
      var query = _supabase.from('general_ledger').select();
      if (accountId != null) query = query.eq('account_id', accountId);
      if (dateFrom != null) query = query.gte('transaction_date', dateFrom);
      if (dateTo != null) query = query.lte('transaction_date', dateTo);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  // ============================================================
  // SCHOLARSHIPS
  // ============================================================
  Future<List<Map<String, dynamic>>> getScholarships() async {
    try {
      final r = await _supabase.from('scholarships').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> createScholarship(Map<String, dynamic> data) async {
    try { await _supabase.from('scholarships').insert(data); return true; }
    catch (e) { return false; }
  }

  Future<List<Map<String, dynamic>>> getStudentScholarships({String? studentId}) async {
    try {
      var query = _supabase.from('student_scholarships').select();
      if (studentId != null) query = query.eq('student_id', studentId);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> approveScholarship(String id, String approvedBy, double amount) async {
    try {
      await _supabase.from('student_scholarships').update({
        'status': 'approved', 'approved_by': approvedBy,
        'approved_amount': amount, 'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) { return false; }
  }

  // ============================================================
  // REFUNDS
  // ============================================================
  Future<List<Map<String, dynamic>>> getRefundRequests() async {
    try {
      final r = await _supabase.from('refund_requests').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> processRefund(String id, String status, {String? approvedBy, String? reason}) async {
    try {
      final update = <String, dynamic>{'status': status, 'updated_at': DateTime.now().toIso8601String()};
      if (approvedBy != null) { update['approved_by'] = approvedBy; update['approved_at'] = DateTime.now().toIso8601String(); }
      if (reason != null) update['rejection_reason'] = reason;
      if (status == 'completed') update['processed_at'] = DateTime.now().toIso8601String();
      await _supabase.from('refund_requests').update(update).eq('id', id);
      return true;
    } catch (e) { return false; }
  }

  // ============================================================
  // FINANCIAL YEARS
  // ============================================================
  Future<List<Map<String, dynamic>>> getFinancialYears() async {
    try {
      final r = await _supabase.from('financial_years').select().order('start_date', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> createFinancialYear(Map<String, dynamic> data) async {
    try { await _supabase.from('financial_years').insert(data); return true; }
    catch (e) { return false; }
  }

  Future<bool> closeFinancialYear(String id, String closedBy) async {
    try {
      await _supabase.from('financial_years').update({'status': 'closed', 'closed_at': DateTime.now().toIso8601String(), 'closed_by': closedBy}).eq('id', id);
      return true;
    } catch (e) { return false; }
  }

  // ============================================================
  // AUDIT LOGS
  // ============================================================
  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) async {
    try {
      final r = await _supabase.from('finance_audit_logs').select().order('created_at', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<void> _logAudit(String entityType, dynamic entityId, String action, Map<String, dynamic>? oldValues, Map<String, dynamic>? newValues, String performedBy) async {
    try {
      await _supabase.from('finance_audit_logs').insert({
        'entity_type': entityType,
        'entity_id': entityId?.toString(),
        'action': action,
        'old_values': oldValues,
        'new_values': newValues,
        'performed_by': performedBy,
      });
    } catch (e) { print('Audit log error: $e'); }
  }

  // ============================================================
  // VENDORS & EXPENSES
  // ============================================================
  Future<List<Map<String, dynamic>>> getVendors() async {
    try {
      final r = await _supabase.from('vendors').select().order('name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final r = await _supabase.from('expenses').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  // ============================================================
  // BANK ACCOUNTS
  // ============================================================
  Future<List<Map<String, dynamic>>> getBankAccounts() async {
    try {
      final r = await _supabase.from('bank_accounts').select().order('account_name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<List<Map<String, dynamic>>> getBankTransactions(String bankAccountId) async {
    try {
      final r = await _supabase.from('bank_transactions').select().eq('bank_account_id', bankAccountId).order('transaction_date', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  // ============================================================
  // FINES
  // ============================================================
  Future<List<Map<String, dynamic>>> getStudentFines(String studentId) async {
    try {
      final r = await _supabase.from('student_fines').select().eq('student_id', studentId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  // ============================================================
  // BACKWARD COMPAT — keep old methods for student_fees_screen.dart
  // ============================================================
  Future<List<Map<String, dynamic>>> getStudentFees(String studentId) async {
    try {
      final allocations = await getStudentAllocations(studentId);
      if (allocations.isNotEmpty) {
        return allocations.map((a) => {
          'id': a['id'],
          'fee_type': a['fee_head_id'] ?? 'Fee',
          'amount': a['net_amount'],
          'status': a['status'],
          'due_date': a['due_date'],
          'paid_at': a['updated_at'],
        }).toList();
      }
      // Fallback to legacy table
      final r = await _supabase.from('finance_student_fees').select().eq('student_id', studentId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> payFees(String studentId, List<Map<String, dynamic>> selectedFees, String paymentMethod) async {
    try {
      double totalAmount = 0;
      List<String> feeIds = [];
      for (var fee in selectedFees) {
        totalAmount += (fee['amount'] as num).toDouble();
        feeIds.add(fee['id'].toString());
      }
      final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
      await _supabase.from('finance_transactions').insert({
        'student_id': studentId, 'total_amount': totalAmount,
        'payment_method': paymentMethod, 'transaction_reference': transactionId, 'fee_ids': feeIds,
      });
      for (var id in feeIds) {
        await _supabase.from('finance_student_fees').update({
          'status': 'paid', 'paid_at': DateTime.now().toIso8601String(), 'transaction_id': transactionId,
        }).eq('id', id);
      }
      return true;
    } catch (e) { return false; }
  }

  Future<List<Map<String, dynamic>>> getStudentTransactions(String studentId) async {
    try {
      final r = await _supabase.from('finance_transactions').select().eq('student_id', studentId).order('transaction_date', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<List<Map<String, dynamic>>> getDepartmentFees(String department) async {
    try {
      final students = await _supabase.from('student_details').select('student_id').eq('department', department);
      final ids = students.map((e) => e['student_id'] as String).toList();
      if (ids.isEmpty) return [];
      final r = await _supabase.from('finance_student_fees').select().inFilter('student_id', ids).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }

  Future<bool> addFeeToDepartment(String department, String feeType, double amount, String? dueDate) async {
    try {
      final students = await _supabase.from('student_details').select('student_id').eq('department', department);
      final ids = students.map((e) => e['student_id'] as String).toList();
      if (ids.isEmpty) return false;
      final records = ids.map((id) => {
        'student_id': id, 'fee_type': feeType, 'amount': amount, 'status': 'pending', 'due_date': dueDate,
      }).toList();
      await _supabase.from('finance_student_fees').insert(records);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> addFee(String studentId, String feeType, double amount, String? dueDate) async {
    try {
      await _supabase.from('finance_student_fees').insert({
        'student_id': studentId, 'fee_type': feeType, 'amount': amount, 'status': 'pending', 'due_date': dueDate,
      });
      return true;
    } catch (e) { return false; }
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final r = await _supabase.from('finance_transactions').select().order('transaction_date', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { return []; }
  }
}
