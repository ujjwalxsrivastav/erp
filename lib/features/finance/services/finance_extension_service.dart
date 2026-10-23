import 'package:supabase_flutter/supabase_flutter.dart';

/// Finance Extension Service — Budget Management, Purchase-to-Pay (P2P)
/// and Grant Management.
///
/// Companion to [FinanceService] (which is left untouched). Follows the
/// same conventions: plain class, `Supabase.instance.client`, try/catch
/// with print, safe empty defaults on failure.
///
/// Tables used:
///  * department_budgets / vendors / expenses — created in migration 27
///    (sql_migrations/27_enterprise_finance_module.sql)
///  * purchase_indents / purchase_orders / goods_receipts / vendor_bills /
///    research_grants / grant_expenses — created in
///    "run karwade/04_finance_budget_p2p_grants.sql" (run that SQL first)
class FinanceExtensionService {
  final _supabase = Supabase.instance.client;

  double _toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;

  // ============================================================
  // BUDGETS (department_budgets — migration 27)
  // Columns: department, financial_year_id, total_budget,
  // allocated_amount, spent_amount, remaining_amount, status
  // ============================================================
  Future<List<Map<String, dynamic>>> getBudgets() async {
    try {
      final r = await _supabase
          .from('department_budgets')
          .select()
          .order('department');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get budgets error: $e');
      return [];
    }
  }

  /// Budget rows enriched with computed fields used by the UI:
  /// 'allocated'  -> allocated_amount (fallback total_budget)
  /// 'utilized'   -> spent_amount + expenses approved/paid for the dept
  ///                 that are not yet reflected in spent_amount is NOT
  ///                 double counted: we report max(spent_amount,
  ///                 expenseTotal) is wrong, so we expose both pieces:
  ///                 'utilized' = spent_amount (ledger truth),
  ///                 'expensesTotal' = sum of expenses table for the dept,
  /// 'committed'  -> open PO totals (draft/approved/sent) whose indent
  ///                 belongs to this department
  /// 'balance'    -> allocated - utilized - committed
  /// 'utilizationPct' -> utilized / allocated * 100
  /// Every extra source is guarded in its own try/catch so a missing
  /// table never breaks the budget list.
  Future<List<Map<String, dynamic>>> getBudgetUtilization() async {
    final budgets = await getBudgets();
    if (budgets.isEmpty) return budgets;

    // Expenses per department (migration 27 table: department, total_amount, status)
    final expenseByDept = <String, double>{};
    try {
      final expenses = await _supabase
          .from('expenses')
          .select('department, total_amount, status')
          .neq('status', 'rejected');
      for (var e in expenses) {
        final dept = (e['department'] as String?) ?? '';
        if (dept.isEmpty) continue;
        expenseByDept[dept] =
            (expenseByDept[dept] ?? 0) + _toDouble(e['total_amount']);
      }
    } catch (e) {
      print('Budget utilization (expenses) error: $e');
    }

    // Committed = open purchase orders, mapped to department via indent
    final committedByDept = <String, double>{};
    try {
      final indents = await _supabase
          .from('purchase_indents')
          .select('id, department');
      final deptByIndent = <String, String>{
        for (var i in indents)
          (i['id'] as String): (i['department'] as String?) ?? '',
      };
      final openPOs = await _supabase
          .from('purchase_orders')
          .select('indent_id, total_amount, status')
          .inFilter('status', ['draft', 'approved', 'sent']);
      for (var po in openPOs) {
        final indentId = po['indent_id'] as String?;
        if (indentId == null) continue;
        final dept = deptByIndent[indentId];
        if (dept == null || dept.isEmpty) continue;
        committedByDept[dept] =
            (committedByDept[dept] ?? 0) + _toDouble(po['total_amount']);
      }
    } catch (e) {
      print('Budget utilization (committed) error: $e');
    }

    return budgets.map((b) {
      final dept = (b['department'] as String?) ?? '';
      final allocatedRaw = b['allocated_amount'];
      final allocated = (allocatedRaw is num && allocatedRaw > 0)
          ? allocatedRaw.toDouble()
          : _toDouble(b['total_budget']);
      final utilized = _toDouble(b['spent_amount']);
      final committed = committedByDept[dept] ?? 0.0;
      final balance = allocated - utilized - committed;
      return {
        ...b,
        'allocated': allocated,
        'utilized': utilized,
        'expensesTotal': expenseByDept[dept] ?? 0.0,
        'committed': committed,
        'balance': balance,
        'utilizationPct': allocated > 0 ? (utilized / allocated) * 100 : 0.0,
      };
    }).toList();
  }

  // ============================================================
  // PURCHASE INDENTS
  // ============================================================
  Future<bool> createIndent(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['indent_no'] ??=
          'IND-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      payload['status'] ??= 'raised';
      await _supabase.from('purchase_indents').insert(payload);
      return true;
    } catch (e) {
      print('Create indent error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getIndents({String? status}) async {
    try {
      var query = _supabase.from('purchase_indents').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get indents error: $e');
      return [];
    }
  }

  Future<bool> updateIndentStatus(String id, String status,
      {String? approvedBy}) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (approvedBy != null) update['approved_by'] = approvedBy;
      await _supabase.from('purchase_indents').update(update).eq('id', id);
      return true;
    } catch (e) {
      print('Update indent status error: $e');
      return false;
    }
  }

  // ============================================================
  // PURCHASE ORDERS
  // ============================================================
  Future<bool> createPO(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['po_no'] ??=
          'PO-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      payload['status'] ??= 'draft';
      payload['items'] ??= <Map<String, dynamic>>[];
      final res =
          await _supabase.from('purchase_orders').insert(payload).select().single();
      // Link back: the indent now has a PO raised against it.
      final indentId = payload['indent_id'] as String?;
      if (indentId != null && indentId.isNotEmpty) {
        await updateIndentStatus(indentId, 'po_raised');
      }
      return res.isNotEmpty;
    } catch (e) {
      print('Create PO error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPOs({String? status}) async {
    try {
      var query = _supabase.from('purchase_orders').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get POs error: $e');
      return [];
    }
  }

  Future<bool> updatePOStatus(String id, String status,
      {String? approvedBy}) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (approvedBy != null) update['approved_by'] = approvedBy;
      await _supabase.from('purchase_orders').update(update).eq('id', id);
      return true;
    } catch (e) {
      print('Update PO status error: $e');
      return false;
    }
  }

  // ============================================================
  // GOODS RECEIPTS (GRN)
  // ============================================================
  Future<bool> createGRN(Map<String, dynamic> data) async {
    try {
      final res =
          await _supabase.from('goods_receipts').insert(data).select().single();
      // Reflect receipt on the PO: fully accepted -> received,
      // anything rejected/partly -> partially_received.
      final poId = data['po_id'] as String?;
      if (poId != null && poId.isNotEmpty) {
        final inspection = (data['inspection_status'] as String?) ?? 'accepted';
        await updatePOStatus(
            poId, inspection == 'accepted' ? 'received' : 'partially_received');
      }
      return res.isNotEmpty;
    } catch (e) {
      print('Create GRN error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getGRNs(String poId) async {
    try {
      final r = await _supabase
          .from('goods_receipts')
          .select()
          .eq('po_id', poId)
          .order('received_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get GRNs error: $e');
      return [];
    }
  }

  // ============================================================
  // VENDOR BILLS (3-way match: PO = GRN = Bill)
  // ============================================================
  Future<bool> bookBill(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      final billAmount = _toDouble(payload['bill_amount']);
      final tds = _toDouble(payload['tds_amount']);
      payload['payable_amount'] ??= billAmount - tds;
      payload['status'] ??= 'booked';
      await _supabase.from('vendor_bills').insert(payload);
      return true;
    } catch (e) {
      print('Book bill error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBills({String? status}) async {
    try {
      var query = _supabase.from('vendor_bills').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get bills error: $e');
      return [];
    }
  }

  Future<bool> updateBillStatus(String id, String status) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'paid') {
        update['paid_at'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('vendor_bills').update(update).eq('id', id);
      return true;
    } catch (e) {
      print('Update bill status error: $e');
      return false;
    }
  }

  // ============================================================
  // VENDORS (migration 27 — read helper for PO dialogs)
  // ============================================================
  Future<List<Map<String, dynamic>>> getVendors() async {
    try {
      final r = await _supabase.from('vendors').select().order('name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get vendors (ext) error: $e');
      return [];
    }
  }

  // ============================================================
  // RESEARCH GRANTS
  // ============================================================
  Future<bool> createGrant(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['status'] ??= 'active';
      payload['utilized_amount'] ??= 0;
      await _supabase.from('research_grants').insert(payload);
      return true;
    } catch (e) {
      print('Create grant error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getGrants({String? status}) async {
    try {
      var query = _supabase.from('research_grants').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get grants error: $e');
      return [];
    }
  }

  Future<bool> updateGrantStatus(String id, String status) async {
    try {
      await _supabase.from('research_grants').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      print('Update grant status error: $e');
      return false;
    }
  }

  /// Adds an expense AND increments the grant's utilized_amount so the
  /// grant master always matches the head-wise expense rows.
  Future<bool> addGrantExpense(Map<String, dynamic> data) async {
    try {
      await _supabase.from('grant_expenses').insert(data);
      final grantId = data['grant_id'] as String?;
      final amount = _toDouble(data['amount']);
      if (grantId != null && amount != 0) {
        final grant = await _supabase
            .from('research_grants')
            .select('utilized_amount')
            .eq('id', grantId)
            .single();
        final newUtilized = _toDouble(grant['utilized_amount']) + amount;
        await _supabase.from('research_grants').update({
          'utilized_amount': newUtilized,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', grantId);
      }
      return true;
    } catch (e) {
      print('Add grant expense error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getGrantExpenses(String grantId) async {
    try {
      final r = await _supabase
          .from('grant_expenses')
          .select()
          .eq('grant_id', grantId)
          .order('expense_date', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get grant expenses error: $e');
      return [];
    }
  }

  /// Data needed to print a Utilization Certificate (UC) in the
  /// funding-agency format: sanctioned / received / utilized /
  /// balance + head-wise breakup of utilization.
  Future<Map<String, dynamic>> generateUCData(String grantId) async {
    try {
      final grant = await _supabase
          .from('research_grants')
          .select()
          .eq('id', grantId)
          .single();
      final expenses = await getGrantExpenses(grantId);

      final headWise = <String, double>{};
      double expenseTotal = 0;
      for (var e in expenses) {
        final head = (e['expense_head'] as String?) ?? 'other';
        final amt = _toDouble(e['amount']);
        headWise[head] = (headWise[head] ?? 0) + amt;
        expenseTotal += amt;
      }

      final sanctioned = _toDouble(grant['sanctioned_amount']);
      final received = _toDouble(grant['received_amount']);
      final utilizedMaster = _toDouble(grant['utilized_amount']);
      final utilized = utilizedMaster > 0 ? utilizedMaster : expenseTotal;

      return {
        'grant': Map<String, dynamic>.from(grant),
        'grantNo': grant['grant_no'],
        'title': grant['title'],
        'fundingAgency': grant['funding_agency'],
        'principalInvestigator': grant['principal_investigator'],
        'startDate': grant['start_date'],
        'endDate': grant['end_date'],
        'status': grant['status'],
        'sanctioned': sanctioned,
        'received': received,
        'utilized': utilized,
        'balance': received - utilized,
        'unspentOfSanctioned': sanctioned - utilized,
        'utilizationPct': sanctioned > 0 ? (utilized / sanctioned) * 100 : 0.0,
        'headWise': headWise,
        'expenses': expenses,
      };
    } catch (e) {
      print('Generate UC data error: $e');
      return {
        'grant': <String, dynamic>{},
        'sanctioned': 0.0,
        'received': 0.0,
        'utilized': 0.0,
        'balance': 0.0,
        'unspentOfSanctioned': 0.0,
        'utilizationPct': 0.0,
        'headWise': <String, double>{},
        'expenses': <Map<String, dynamic>>[],
      };
    }
  }

  // ============================================================
  // DASHBOARD STATS (Budget + P2P + Grants summary)
  // ============================================================
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final budgets = await getBudgets();
      final pendingIndents = await getIndents(status: 'raised');
      final openPOs = await _supabase
          .from('purchase_orders')
          .select('id, status')
          .inFilter('status', ['draft', 'approved', 'sent', 'partially_received']);
      final unpaidBills = await _supabase
          .from('vendor_bills')
          .select('payable_amount, status')
          .neq('status', 'paid');
      double unpaidTotal = 0;
      for (var b in unpaidBills) {
        unpaidTotal += _toDouble(b['payable_amount']);
      }
      final grants = await getGrants(status: 'active');
      double sanctionedTotal = 0, utilizedTotal = 0;
      for (var g in grants) {
        sanctionedTotal += _toDouble(g['sanctioned_amount']);
        utilizedTotal += _toDouble(g['utilized_amount']);
      }
      return {
        'activeBudgets': budgets.where((b) => b['status'] == 'active').length,
        'pendingIndents': pendingIndents.length,
        'openPOs': openPOs.length,
        'unpaidBills': unpaidBills.length,
        'unpaidBillsTotal': unpaidTotal,
        'activeGrants': grants.length,
        'grantSanctionedTotal': sanctionedTotal,
        'grantUtilizedTotal': utilizedTotal,
        'grantUtilizationPct':
            sanctionedTotal > 0 ? (utilizedTotal / sanctionedTotal) * 100 : 0.0,
      };
    } catch (e) {
      print('Finance extension dashboard stats error: $e');
      return {
        'activeBudgets': 0,
        'pendingIndents': 0,
        'openPOs': 0,
        'unpaidBills': 0,
        'unpaidBillsTotal': 0.0,
        'activeGrants': 0,
        'grantSanctionedTotal': 0.0,
        'grantUtilizedTotal': 0.0,
        'grantUtilizationPct': 0.0,
      };
    }
  }
}
