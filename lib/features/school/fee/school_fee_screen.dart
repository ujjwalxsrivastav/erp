import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/fee_receipt_pdf.dart';
import '../../../services/school_export_service.dart';

class SchoolFeeScreen extends StatefulWidget {
  final String? studentId;
  const SchoolFeeScreen({super.key, this.studentId});

  @override
  State<SchoolFeeScreen> createState() => _SchoolFeeScreenState();
}

class _SchoolFeeScreenState extends State<SchoolFeeScreen> {
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = 'student';
  String _studentUsername = '';
  String _studentName = '';
  String _studentClass = '';
  String _studentClassId = '';
  String _admissionNo = '';

  // Parent child selection state (PM6)
  List<Map<String, dynamic>> _parentChildren = [];
  int _selectedChildIndex = 0;

  // Fee state
  List<Map<String, dynamic>> _feeHeads = [];
  List<Map<String, dynamic>> _monthlySchedule = [];
  Map<String, dynamic> _studentFeeSummary = {};
  List<Map<String, dynamic>> _receipts = [];

  // Months ticked for a combined payment.
  final Set<String> _selectedMonths = {};

  // Admin state
  List<Map<String, dynamic>> _allStudentSummaries = [];
  Map<String, dynamic> _defaulterData = {};
  String _adminSearchQuery = '';
  String _adminFilter = 'all'; // 'all', 'overdue', 'paid', 'partial'

  bool get _isAdminRole => _userRole == 'admin' || _userRole == 'sadmin';

  // Monthly base amount calculated from active heads
  double get _monthlyBaseFee {
    final active = _feeHeads.where((h) => h['is_active'] != false);
    return active.fold(0.0, (sum, h) => sum + ((h['amount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _annualBaseFee => _monthlyBaseFee * 12;

  // Student metrics
  double get _studentTotalAnnual =>
      (_studentFeeSummary['total_annual'] as num?)?.toDouble() ??
      (_monthlySchedule.fold(0.0, (s, m) => s + ((m['total_amount'] as num?)?.toDouble() ?? 0.0)));

  double get _studentTotalPaid =>
      (_studentFeeSummary['total_paid'] as num?)?.toDouble() ??
      (_monthlySchedule.where((m) => m['is_paid'] == true).fold(0.0, (s, m) => s + ((m['paid_amount'] as num?)?.toDouble() ?? 0.0)));

  double get _studentTotalPending =>
      (_studentFeeSummary['total_pending'] as num?)?.toDouble() ??
      (_monthlySchedule.where((m) => m['is_paid'] != true).fold(0.0, (s, m) => s + ((m['total_amount'] as num?)?.toDouble() ?? 0.0)));

  int get _studentOverdueMonthsCount =>
      (_studentFeeSummary['overdue_count'] as int?) ??
      (_monthlySchedule.where((m) => m['is_overdue'] == true && m['is_paid'] != true).length);

  double get _studentTotalLateFees =>
      (_studentFeeSummary['total_late_fees'] as num?)?.toDouble() ??
      (_studentOverdueMonthsCount * 100.0);

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  Future<void> _loadFeeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Kick off every independent request together instead of awaiting them
      // one by one (this screen used to make ~9 sequential round-trips).
      final roleFuture = _authService.getCurrentUserRole();
      final usernameFuture = _authService.getCurrentUsername();
      final headsFuture = _schoolService.getSchoolFeeHeads();

      final role = await roleFuture ?? 'student';
      final username = await usernameFuture ?? 'sstudent1';
      final heads = await headsFuture;

      if (role == 'admin' || role == 'sadmin') {
        final results = await Future.wait([
          _schoolService.getAllStudentFeeSummaries(),
          _schoolService.getDefaultersWithAgeing(),
        ]);

        if (!mounted) return;
        setState(() {
          _userRole = role;
          _feeHeads = heads;
          _allStudentSummaries = results[0] as List<Map<String, dynamic>>;
          _defaulterData = results[1] as Map<String, dynamic>;
          _receipts = const [];
          _isLoading = false;
        });
        return;
      }

      if (role == 'teacher' || role == 'steacher') {
        if (!mounted) return;
        setState(() {
          _userRole = role;
          _errorMessage =
              'Fee management is restricted to School Administration, Students, and Parents. Teachers do not have ledger access.';
          _isLoading = false;
        });
        return;
      }

      // Student / Parent role
      String targetUser = username;
      List<Map<String, dynamic>> parentKids = [];

      if (role == 'parent') {
        parentKids = await _schoolService.getParentChildren(username);
        if (widget.studentId != null && widget.studentId!.isNotEmpty) {
          final idx = parentKids.indexWhere((k) => (k['username'] == widget.studentId || k['id'] == widget.studentId));
          if (idx != -1) {
            _selectedChildIndex = idx;
            targetUser = parentKids[idx]['username']?.toString() ?? parentKids[idx]['id']?.toString() ?? widget.studentId!;
          } else {
            targetUser = widget.studentId!;
          }
        } else if (parentKids.isNotEmpty) {
          _selectedChildIndex = 0;
          targetUser = parentKids.first['username']?.toString() ?? parentKids.first['id']?.toString() ?? '';
        } else {
          if (!mounted) return;
          setState(() {
            _userRole = role;
            _errorMessage = 'No student profiles are linked to this parent account.';
            _isLoading = false;
          });
          return;
        }
      }

      // profile / schedule / receipts are independent → fetch concurrently.
      final profileFuture =
          _schoolService.getSchoolStudentProfile(targetUser);
      final scheduleFuture =
          _schoolService.getMonthlyFeeSchedule(targetUser);
      final receiptsFuture = _schoolService.getStudentReceipts(targetUser);

      final profile = await profileFuture;
      final schedule = await scheduleFuture;
      // Reuse the schedule we just fetched instead of running it again.
      final summary = await _schoolService
          .getStudentFeeSummary(targetUser, scheduleOverride: schedule);
      final receipts = await receiptsFuture;

      if (!mounted) return;
      setState(() {
        _userRole = role;
        _parentChildren = parentKids;
        _studentUsername = targetUser;
        _feeHeads = heads;
        _monthlySchedule = schedule;
        _studentFeeSummary = summary;
        _receipts = receipts;
        if (profile != null) {
          _studentName = profile['name']?.toString() ?? _studentName;
          _studentClass = profile['class_name']?.toString() ?? _studentClass;
          _studentClassId = profile['class_id']?.toString() ?? _studentClassId;
          _admissionNo = profile['admission_no']?.toString() ?? _admissionNo;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load fee records: $e';
      });
    }
  }

  Future<void> _switchParentChild(int index) async {
    if (index == _selectedChildIndex || index >= _parentChildren.length) return;
    final child = _parentChildren[index];
    final targetUser = child['username']?.toString() ?? child['id']?.toString() ?? '';
    if (targetUser.isEmpty) return;

    setState(() {
      _selectedChildIndex = index;
      _isLoading = true;
    });

    try {
      final profileFuture =
          _schoolService.getSchoolStudentProfile(targetUser);
      final scheduleFuture =
          _schoolService.getMonthlyFeeSchedule(targetUser);
      final receiptsFuture = _schoolService.getStudentReceipts(targetUser);

      final profile = await profileFuture;
      final schedule = await scheduleFuture;
      final summary = await _schoolService
          .getStudentFeeSummary(targetUser, scheduleOverride: schedule);
      final receipts = await receiptsFuture;

      if (!mounted) return;
      setState(() {
        _studentUsername = targetUser;
        _monthlySchedule = schedule;
        _studentFeeSummary = summary;
        _receipts = receipts;
        if (profile != null) {
          _studentName = profile['name']?.toString() ?? _studentName;
          _studentClass = profile['class_name']?.toString() ?? _studentClass;
          _studentClassId = profile['class_id']?.toString() ?? _studentClassId;
          _admissionNo = profile['admission_no']?.toString() ?? _admissionNo;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not switch child fee records: $e';
      });
    }
  }

  // ── Combined payment selection ──

  List<Map<String, dynamic>> get _unpaidMonths => _monthlySchedule
      .where((m) => m['is_paid'] != true)
      .toList(growable: false);

  List<Map<String, dynamic>> get _selectedMonthRows => _unpaidMonths
      .where((m) => _selectedMonths.contains(m['month_name']?.toString() ?? ''))
      .toList(growable: false);

  double get _selectedMonthsTotal => _selectedMonthRows.fold<double>(
      0.0, (sum, m) => sum + ((m['total_amount'] as num?)?.toDouble() ?? 0.0));

  bool get _allUnpaidSelected =>
      _unpaidMonths.isNotEmpty &&
      _selectedMonthRows.length == _unpaidMonths.length;

  void _toggleMonth(String monthName, bool selected) {
    setState(() {
      if (selected) {
        _selectedMonths.add(monthName);
      } else {
        _selectedMonths.remove(monthName);
      }
    });
  }

  void _toggleAllUnpaid() {
    setState(() {
      if (_allUnpaidSelected) {
        _selectedMonths.clear();
      } else {
        _selectedMonths
          ..clear()
          ..addAll(_unpaidMonths
              .map((m) => m['month_name']?.toString() ?? '')
              .where((n) => n.isNotEmpty));
      }
    });
  }

  void _showBulkPaymentDialog() {
    final months = _selectedMonthRows;
    if (months.isEmpty) return;
    _showPaymentDialog(multipleMonths: months);
  }

  // Filtered students for Admin
  List<Map<String, dynamic>> get _filteredAdminStudents {
    final q = _adminSearchQuery.trim().toLowerCase();
    return _allStudentSummaries.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final uname = (s['username'] ?? '').toString().toLowerCase();
      final cName = (s['class_name'] ?? '').toString().toLowerCase();
      final roll = (s['roll_number'] ?? '').toString().toLowerCase();
      final matchesQuery = q.isEmpty ||
          name.contains(q) ||
          uname.contains(q) ||
          cName.contains(q) ||
          roll.contains(q);

      if (!matchesQuery) return false;

      final pending = (s['pending_amount'] as num?)?.toDouble() ?? 0.0;
      final paid = (s['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final overdue = (s['overdue_months'] as int?) ?? 0;

      switch (_adminFilter) {
        case 'overdue':
          return overdue > 0 && pending > 0.01;
        case 'paid':
          return pending <= 0.01;
        case 'partial':
          return paid > 0.01 && pending > 0.01;
        default:
          return true;
      }
    }).toList();
  }

  // --- ACTIONS & DIALOGS ---

  Future<void> _showAddEditFeeHeadDialog([Map<String, dynamic>? existingHead]) async {
    final isEdit = existingHead != null;
    final titleCtrl = TextEditingController(text: existingHead?['title']?.toString() ?? '');
    final amountCtrl = TextEditingController(
      text: existingHead != null ? ((existingHead['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0) : '',
    );
    final descCtrl = TextEditingController(text: existingHead?['description']?.toString() ?? '');
    String category = existingHead?['category']?.toString() ?? 'Academic';
    String frequency = existingHead?['frequency']?.toString() ?? 'Monthly';

    final categories = ['Academic', 'Technology', 'Laboratory', 'Sports', 'Library', 'Evaluation', 'Activity', 'Transport', 'Other'];
    final frequencies = ['Monthly', 'Quarterly', 'Annual'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isEdit ? 'Edit Fee Head' : 'Create New Fee Head',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fee Head Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Tuition Fee, Computer Lab, Sports Fee',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Monthly Amount per Student (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'e.g. 3500',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => category = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cycle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: frequency,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => frequency = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Explain what this fee covers',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a fee head title.')));
                  return;
                }
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an amount greater than zero.')));
                  return;
                }

                Navigator.pop(ctx);
                final headPayload = <String, dynamic>{
                  if (existingHead != null) 'id': existingHead['id'],
                  'title': title,
                  'amount': amount,
                  'category': category,
                  'frequency': frequency,
                  'description': descCtrl.text.trim(),
                  'is_active': true,
                };
                await _schoolService.saveSchoolFeeHead(headPayload);
                await _loadFeeData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Fee head "$title" updated.' : 'Fee head "$title" added successfully.'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Text(isEdit ? 'Save Changes' : 'Create Head'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFeeHead(String headId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Fee Head?'),
        content: Text('Are you sure you want to remove "$title"? This head will no longer be included in new monthly demands.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _schoolService.deleteSchoolFeeHead(headId);
      await _loadFeeData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fee head "$title" removed.'), backgroundColor: const Color(0xFF059669)),
        );
      }
    }
  }

  void _showPaymentDialog({
    Map<String, dynamic>? singleMonth,
    List<Map<String, dynamic>>? multipleMonths,
    String? targetStudentUsername,
    String? targetStudentName,
  }) {
    final studentUname = targetStudentUsername ?? _studentUsername;
    final studentDisplay = targetStudentName ?? _studentName;

    final months = multipleMonths ??
        (singleMonth != null
            ? <Map<String, dynamic>>[singleMonth]
            : const <Map<String, dynamic>>[]);
    final isMultiMonth = months.length > 1;
    final monthName = months.isEmpty
        ? 'Composite Fee Demand'
        : months
            .map((m) => m['month_name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');

    double sumOf(String field) => months.fold<double>(
        0.0, (sum, m) => sum + ((m[field] as num?)?.toDouble() ?? 0.0));
    final double baseAmt = months.isEmpty ? _monthlyBaseFee : sumOf('base_amount');
    final double lateFee =
        months.isEmpty ? _studentTotalLateFees : sumOf('late_fee');
    final double totalPayable = months.isEmpty
        ? _studentTotalPending
        : (sumOf('total_amount') > 0 ? sumOf('total_amount') : baseAmt + lateFee);

    String paymentMode = 'UPI / Online';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.payment_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 10),
              Text('Record / Pay Fee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paying for: $studentDisplay ($studentUname)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text(
                        isMultiMonth
                            ? 'Cycle: ${months.length} months selected'
                            : 'Cycle: $monthName',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (isMultiMonth) ...[
                        const SizedBox(height: 8),
                        ...months.map((m) => Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '• ${m['month_name']}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF475569)),
                                  ),
                                  Text(
                                    '₹${((m['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      if (lateFee > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                              const SizedBox(width: 4),
                              Text('Includes ₹${lateFee.toStringAsFixed(0)} statutory late fee fine (past 5th)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Monthly Fee:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text('₹${baseAmt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ],
                ),
                if (lateFee > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Late Fee Fine (Overdue):', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                      Text('+₹${lateFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                    ],
                  ),
                ],
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount Payable:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text('₹${totalPayable.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: paymentMode,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / QR Code / NetBanking')),
                    DropdownMenuItem(value: 'Debit/Credit Card', child: Text('Debit / Credit Card')),
                    DropdownMenuItem(value: 'Counter Cash', child: Text('Cash at Accounts Counter')),
                    DropdownMenuItem(value: 'Bank Cheque / DD', child: Text('Bank Cheque / DD')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => paymentMode = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Transaction Reference / Note (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. UTR / Cheque No. / Counter Slip',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final String receiptNo;
                  if (months.length > 1) {
                    final receipts = await _schoolService.payFeeMonths(
                      studentUsername: studentUname,
                      months: months,
                      paymentMode: paymentMode,
                      classId: _studentClassId,
                      note: notesCtrl.text.trim(),
                    );
                    receiptNo = receipts.length == 1
                        ? receipts.first
                        : '${receipts.first} (+${receipts.length - 1} more)';
                  } else {
                    receiptNo = await _schoolService.payMonthlyFee(
                      studentUsername: studentUname,
                      monthName: months.isEmpty
                          ? monthName
                          : months.first['month_name']?.toString() ?? monthName,
                      baseAmount: baseAmt,
                      lateFee: lateFee,
                      paymentMode: paymentMode,
                      classId: _studentClassId,
                      note: notesCtrl.text.trim(),
                    );
                  }

                  _selectedMonths.clear();
                  await _loadFeeData();
                  if (mounted) {
                    _showReceiptSuccessDialog(
                      receiptNo: receiptNo,
                      studentName: studentDisplay,
                      amount: totalPayable,
                      mode: paymentMode,
                      monthName: isMultiMonth
                          ? '${months.length} months (${months.take(2).map((m) => m['month_name']).join(', ')}${months.length > 2 ? ' +${months.length - 2} more' : ''})'
                          : monthName,
                      lateFee: lateFee,
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  // A duplicate payment is rejected above — reload the ledger so
                  // the already-settled month shows as paid instead of staying
                  // payable on screen.
                  await _loadFeeData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment failed: $e'), backgroundColor: const Color(0xFFDC2626)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Confirm ₹${totalPayable.toStringAsFixed(0)} Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptSuccessDialog({
    required String receiptNo,
    required String studentName,
    required double amount,
    required String mode,
    required String monthName,
    required double lateFee,
  }) {
    final paidDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 26),
            SizedBox(width: 10),
            Text('Payment Successful', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _receiptRow('Receipt Number', receiptNo),
                  _receiptRow('Student Name', studentName),
                  _receiptRow('Academic Month', monthName),
                  _receiptRow('Amount Paid', '₹${amount.toStringAsFixed(0)}'),
                  if (lateFee > 0) _receiptRow('Late Fee Fine Included', '₹${lateFee.toStringAsFixed(0)}'),
                  _receiptRow('Payment Mode', mode),
                  _receiptRow('Date of Payment', paidDate),
                  _receiptRow('Verification', 'Authorized CBSE Accounts Seal'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _downloadReceipt(receiptNo: receiptNo, amount: amount, mode: mode, date: paidDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download Official PDF Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReceipt({String? receiptNo, double? amount, String? mode, String? date}) async {
    try {
      final ledger = _monthlySchedule.map((m) {
        return {
          'head': m['month_name'],
          'amount': m['total_amount'],
          'paid_amount': m['paid_amount'],
          'status': m['status'],
          'due_date': m['due_date'],
        };
      }).toList();

      await FeeReceiptPdf.share(
        studentName: _studentName,
        className: _studentClass,
        admissionNo: _admissionNo,
        studentUsername: _studentUsername,
        ledger: ledger,
        receiptNo: receiptNo,
        paymentMode: mode,
        paymentAmount: amount,
        paymentDate: date,
        title: receiptNo == null ? 'ANNUAL FEE STATEMENT' : 'OFFICIAL FEE RECEIPT',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  Future<void> _downloadAllReceipts() async {
    try {
      final ledger = _monthlySchedule.map((m) {
        return {
          'head': m['month_name'],
          'amount': m['total_amount'],
          'paid_amount': m['paid_amount'],
          'status': m['status'],
          'due_date': m['due_date'],
        };
      }).toList();

      await FeeReceiptPdf.shareAll(
        studentName: _studentName,
        className: _studentClass,
        admissionNo: _admissionNo,
        studentUsername: _studentUsername,
        ledger: ledger,
        receipts: _receipts,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate receipts PDF: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  void _showStudentLedgerModal(Map<String, dynamic> student) async {
    final username = (student['username'] ?? '').toString();
    final name = (student['name'] ?? username).toString();
    final className = (student['class_name'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _schoolService.getMonthlyFeeSchedule(username),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 350,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
              );
            }

            final schedule = snapshot.data ?? [];
            final totalPending = schedule.where((m) => m['is_paid'] != true).fold<double>(0.0, (s, m) => s + ((m['total_amount'] as num?)?.toDouble() ?? 0.0));
            final totalPaid = schedule.where((m) => m['is_paid'] == true).fold<double>(0.0, (s, m) => s + ((m['paid_amount'] as num?)?.toDouble() ?? 0.0));

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          Text('$username • $className', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _metricBadge('Paid', '₹${totalPaid.toStringAsFixed(0)}', const Color(0xFFECFDF5), const Color(0xFF059669)),
                      const SizedBox(width: 8),
                      _metricBadge('Pending', '₹${totalPending.toStringAsFixed(0)}', const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('12-Month Academic Schedule (April - March)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: schedule.length,
                      itemBuilder: (context, index) {
                        final m = schedule[index];
                        final isPaid = m['is_paid'] == true;
                        final isOverdue = m['is_overdue'] == true;
                        final lateFee = (m['late_fee'] as num?)?.toDouble() ?? 0.0;
                        final total = (m['total_amount'] as num?)?.toDouble() ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? const Color(0xFFECFDF5)
                                      : isOverdue
                                          ? const Color(0xFFFEF2F2)
                                          : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    isPaid
                                        ? Icons.check
                                        : isOverdue
                                            ? Icons.warning_amber_rounded
                                            : Icons.calendar_today_outlined,
                                    size: 18,
                                    color: isPaid
                                        ? const Color(0xFF059669)
                                        : isOverdue
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['month_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                                    Text('Due 5th • ${isPaid ? "Paid (${m['payment_mode'] ?? 'Online'})" : isOverdue ? "Overdue (+₹${lateFee.toStringAsFixed(0)} fine)" : "Pending"}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isPaid
                                              ? const Color(0xFF059669)
                                              : isOverdue
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF64748B),
                                        )),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                                  if (!isPaid)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(60, 24),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showPaymentDialog(singleMonth: m, targetStudentUsername: username, targetStudentName: name);
                                      },
                                      child: const Text('Record Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metricBadge(String label, String value, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        ],
      ),
    );
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: Text(
            _isAdminRole ? 'School Fee & Accounts Master' : 'Student Fee Portal',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ),
        body: _buildLoadingSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: Text(
            _isAdminRole ? 'School Fee & Accounts Master' : 'Student Fee Portal',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ),
        body: _buildErrorView(),
      );
    }

    final tabCount = _isAdminRole ? 3 : 2;

    return DefaultTabController(
      key: ValueKey('fee_tabs_${tabCount}_$_userRole'),
      length: tabCount,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isAdminRole ? 'School Fee & Accounts Master' : 'Student Fee Portal',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                _isAdminRole
                    ? 'CBSE Academic Year 2026-27 • 12-Month April-March Schedule'
                    : '$_studentName • $_studentClass • Roll $_admissionNo',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh Ledger',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _loadFeeData,
            ),
            if (_isAdminRole)
              IconButton(
                tooltip: 'Export Defaulters',
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () {
                  final defaulters = _allStudentSummaries.where((s) => ((s['pending_amount'] as num?)?.toDouble() ?? 0) > 0.01).toList();
                  SchoolExportService.showExportOptionsModal(
                    context: context,
                    title: 'Export Defaulters Ledger',
                    subtitle: 'Export ${defaulters.length} students with outstanding balances.',
                    onExportPdf: () => SchoolExportService.exportPendingFeesPdf(
                      context: context,
                      pendingStudents: defaulters,
                      totalOutstandingAmount: defaulters.fold<double>(0.0, (s, d) => s + ((d['pending_amount'] as num?)?.toDouble() ?? 0.0)),
                    ),
                    onExportCsv: () => SchoolExportService.exportPendingFeesCsv(context: context, pendingStudents: defaulters),
                  );
                },
              ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                labelColor: const Color(0xFFD97706),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFFD97706),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: _isAdminRole
                    ? const [
                        Tab(text: 'Fee Heads & Policy'),
                        Tab(text: 'Student Accounts'),
                        Tab(text: 'Defaulters & Ageing'),
                      ]
                    : const [
                        Tab(text: 'Academic Schedule (Apr-Mar)'),
                        Tab(text: 'Receipts & History'),
                      ],
              ),
            ),
          ),
        ),
        body: _isAdminRole
            ? TabBarView(
                children: [
                  _buildAdminFeeHeadsTab(),
                  _buildAdminStudentAccountsTab(),
                  _buildAdminDefaultersTab(),
                ],
              )
            : TabBarView(
                children: [
                  _buildStudentScheduleTab(),
                  _buildStudentReceiptsTab(),
                ],
              ),
        floatingActionButton: _isAdminRole
            ? FloatingActionButton.extended(
                onPressed: () => _showAddEditFeeHeadDialog(),
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Fee Head', style: TextStyle(fontWeight: FontWeight.w600)),
              )
            : null,
      ),
    );
  }

  // ================= ADMIN TAB 1: FEE HEADS & POLICY =================

  Widget _buildAdminFeeHeadsTab() {
    return RefreshIndicator(
      onRefresh: _loadFeeData,
      color: const Color(0xFFD97706),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Metric Cards
          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Monthly Base',
                  value: '₹${NumberFormat('#,##,###').format(_monthlyBaseFee.round())}',
                  subtitle: '${_feeHeads.length} Configured Heads',
                  color: const Color(0xFFD97706),
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  title: 'Annual Schedule',
                  value: '₹${NumberFormat('#,##,###').format(_annualBaseFee.round())}',
                  subtitle: '12 Months (Apr - Mar)',
                  color: const Color(0xFF059669),
                  icon: Icons.account_balance_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Statutory Late Fee Policy Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Statutory Late Fee Rule: ₹100 Fine past 5th',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF92400E)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'School demands are scheduled on a monthly basis from April to March. Monthly fee is due on or before the 5th of each month. Any pending account past the 5th automatically incurs a ₹100 statutory fine per overdue month, syncing instantly to student dashboards.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Heads List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Fee Heads (${_feeHeads.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              TextButton.icon(
                onPressed: () async {
                  await _schoolService.resetSchoolFeeHeadsToDefault();
                  await _loadFeeData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fee heads reset to CBSE standard defaults.'), backgroundColor: Color(0xFF059669)),
                    );
                  }
                },
                icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF64748B)),
                label: const Text('Reset Defaults', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fee Heads Cards
          ..._feeHeads.map((head) {
            final headId = head['id']?.toString() ?? '';
            final title = head['title']?.toString() ?? 'Fee Head';
            final amount = (head['amount'] as num?)?.toDouble() ?? 0.0;
            final category = head['category']?.toString() ?? 'Academic';
            final description = head['description']?.toString() ?? '';
            final frequency = head['frequency']?.toString() ?? 'Monthly';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              Text(' / $frequency', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                          onPressed: () => _showAddEditFeeHeadDialog(head),
                          tooltip: 'Edit Head',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                          onPressed: () => _deleteFeeHead(headId, title),
                          tooltip: 'Delete Head',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ================= ADMIN TAB 2: STUDENT ACCOUNTS & DEMANDS =================

  Widget _buildAdminStudentAccountsTab() {
    final students = _filteredAdminStudents;
    return Column(
      children: [
        // Search & Filter header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _adminSearchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search student name, roll number, class, or username...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All (${_allStudentSummaries.length})', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('Overdue Defaulters', 'overdue'),
                    const SizedBox(width: 8),
                    _filterChip('Partially Paid', 'partial'),
                    const SizedBox(width: 8),
                    _filterChip('Fully Settled', 'paid'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Student list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFeeData,
            color: const Color(0xFFD97706),
            child: students.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(
                          child: Text('No students match the selected filter.', style: TextStyle(color: Color(0xFF64748B))),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final s = students[index];
                      final name = (s['name'] ?? s['username']).toString();
                      final uname = s['username']?.toString() ?? '';
                      final cName = s['class_name']?.toString() ?? 'Class 10';
                      final section = s['section']?.toString() ?? 'A';
                      final roll = s['roll_number']?.toString() ?? '—';
                      final total = (s['total_fee'] as num?)?.toDouble() ?? 0.0;
                      final paid = (s['paid_amount'] as num?)?.toDouble() ?? 0.0;
                      final pending = (s['pending_amount'] as num?)?.toDouble() ?? 0.0;
                      final overdue = (s['overdue_months'] as int?) ?? 0;
                      final lateFee = (s['late_fee_fine'] as num?)?.toDouble() ?? 0.0;

                      final isSettled = pending <= 0.01;
                      final isOverdue = overdue > 0 && !isSettled;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showStudentLedgerModal(s),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isSettled
                                          ? const Color(0xFFECFDF5)
                                          : isOverdue
                                              ? const Color(0xFFFEF2F2)
                                              : const Color(0xFFFEF3C7),
                                      child: Text(
                                        name.characters.first.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isSettled
                                              ? const Color(0xFF059669)
                                              : isOverdue
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                                          Text('$uname • $cName-$section • Roll $roll', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSettled
                                            ? const Color(0xFFECFDF5)
                                            : isOverdue
                                                ? const Color(0xFFFEF2F2)
                                                : const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isSettled
                                            ? 'PAID'
                                            : isOverdue
                                                ? 'OVERDUE ($overdue MOS)'
                                                : 'PENDING',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSettled
                                              ? const Color(0xFF059669)
                                              : isOverdue
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _amountColumn('Annual Total', '₹${total.toStringAsFixed(0)}', const Color(0xFF334155)),
                                    _amountColumn('Paid', '₹${paid.toStringAsFixed(0)}', const Color(0xFF059669)),
                                    _amountColumn('Pending', '₹${pending.toStringAsFixed(0)}', isOverdue ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                                    if (lateFee > 0)
                                      _amountColumn('Late Fine', '+₹${lateFee.toStringAsFixed(0)}', const Color(0xFFDC2626)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _adminFilter == value;
    return InkWell(
      onTap: () => setState(() => _adminFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _amountColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      ],
    );
  }

  // ================= ADMIN TAB 3: DEFAULTERS & AGEING =================

  Widget _buildAdminDefaultersTab() {
    final b0 = (_defaulterData['bucket_0_30'] as List?) ?? [];
    final b31 = (_defaulterData['bucket_31_60'] as List?) ?? [];
    final b61 = (_defaulterData['bucket_61_90'] as List?) ?? [];
    final b90 = (_defaulterData['bucket_90_plus'] as List?) ?? [];
    final totalPending = (_defaulterData['total_pending'] as num?)?.toDouble() ?? 0.0;
    final defaultersCount = (_defaulterData['total_defaulters'] as int?) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overdue summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Overdue Outstanding', style: TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                    Text('₹${totalPending.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                    Text('$defaultersCount accounts currently overdue past the 5th', style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Statutory Defaulter Ageing Buckets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        _ageingBucketTile('0 - 30 Days Overdue', b0, const Color(0xFFD97706), 'Recent overdue (Grace period ended on 5th)'),
        _ageingBucketTile('31 - 60 Days Overdue', b31, const Color(0xFFEA580C), 'First reminder issued'),
        _ageingBucketTile('61 - 90 Days Overdue', b61, const Color(0xFFDC2626), 'Notice sent to parents'),
        _ageingBucketTile('90+ Days Critical', b90, const Color(0xFF991B1B), 'Critical ledger hold'),
      ],
    );
  }

  Widget _ageingBucketTile(String title, List items, Color color, String note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.access_time_rounded, color: color, size: 18),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color)),
        subtitle: Text('${items.length} accounts • $note', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        children: items.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No accounts in this ageing bucket.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
              ]
            : items.map((item) {
                final sid = item['student_id']?.toString() ?? 'Student';
                final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                final due = item['due_date']?.toString() ?? '—';
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                  title: Text(sid, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('Due 5th: $due', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  trailing: Text('₹${amt.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                );
              }).toList(),
      ),
    );
  }

  // ================= STUDENT TAB 1: ACADEMIC SCHEDULE (APRIL - MARCH) =================

  Widget _buildStudentScheduleTab() {
    final progress = _studentTotalAnnual > 0 ? (_studentTotalPaid / _studentTotalAnnual).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      onRefresh: _loadFeeData,
      color: const Color(0xFFD97706),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sibling Switcher Bar for Parents (PM6)
          if (_parentChildren.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: List.generate(_parentChildren.length, (i) {
                  final k = _parentChildren[i];
                  final isSel = i == _selectedChildIndex;
                  final kName = k['name']?.toString() ?? 'Child';
                  final kClass = k['class_name']?.toString() ?? '';
                  return Expanded(
                    child: InkWell(
                      onTap: () => _switchParentChild(i),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF0F172A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$kName ($kClass)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],

          // Hero Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_studentName.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'Student: $_studentName ($_studentClass • Adm: $_admissionNo)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CBSE Academic Session 2026-27', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _studentTotalPending <= 0.01 ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _studentTotalPending <= 0.01 ? 'FULL CLEARANCE' : 'ACTIVE SCHEDULE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _studentTotalPending <= 0.01 ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${_studentTotalPaid.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(' / ₹${_studentTotalAnnual.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? const Color(0xFF059669) : const Color(0xFFD97706)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _heroStat('Total Paid', '₹${_studentTotalPaid.toStringAsFixed(0)}', const Color(0xFF059669)),
                    _heroStat('Pending Due', '₹${_studentTotalPending.toStringAsFixed(0)}',
                        _studentTotalPending > 0.01 ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                    _heroStat('Next Due', '5th of Month', const Color(0xFFD97706)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Overdue late fine warning banner
          if (_studentOverdueMonthsCount > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notice: $_studentOverdueMonthsCount Month${_studentOverdueMonthsCount > 1 ? "s" : ""} Overdue Past 5th',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A statutory fine of ₹100 per overdue month has been added (+₹${_studentTotalLateFees.toStringAsFixed(0)} total). Please settle outstanding dues.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // 12-Month Breakdown Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '12-Month Academic Breakdown (Apr - Mar)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                'Due on 5th',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
              ),
            ],
          ),
          if (_unpaidMonths.isNotEmpty) ...[
            Row(
              children: [
                TextButton.icon(
                  onPressed: _toggleAllUnpaid,
                  icon: Icon(
                    _allUnpaidSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _allUnpaidSelected ? 'Clear selection' : 'Select all unpaid',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedMonthRows.length} selected',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),

          // 12 Monthly Cards
          ..._monthlySchedule.map((m) {
            return _buildMonthFeeCard(m);
          }),

          // Combined payment bar — appears once at least one month is ticked
          if (_selectedMonthRows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedMonthRows.length} month${_selectedMonthRows.length > 1 ? "s" : ""} selected',
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFFCBD5E1)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_selectedMonthsTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showBulkPaymentDialog,
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Pay Selected',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildMonthFeeCard(Map<String, dynamic> m) {
    final monthName = m['month_name']?.toString() ?? 'Academic Month';
    final isPaid = m['is_paid'] == true;
    final isOverdue = m['is_overdue'] == true;
    final lateFee = (m['late_fee'] as num?)?.toDouble() ?? 0.0;
    final total = (m['total_amount'] as num?)?.toDouble() ?? 0.0;
    final receiptNo = m['receipt_no']?.toString();
    final paymentMode = m['payment_mode']?.toString() ?? 'Online';
    final heads = (m['heads'] as List?) ?? [];

    Color badgeBg;
    Color badgeColor;
    String badgeText;

    if (isPaid) {
      badgeBg = const Color(0xFFECFDF5);
      badgeColor = const Color(0xFF059669);
      badgeText = 'PAID';
    } else if (isOverdue) {
      badgeBg = const Color(0xFFFEF2F2);
      badgeColor = const Color(0xFFDC2626);
      badgeText = 'OVERDUE (+₹100 FINE)';
    } else {
      badgeBg = const Color(0xFFFFFBEB);
      badgeColor = const Color(0xFFD97706);
      badgeText = 'DUE 5TH';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: badgeBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_today_rounded,
              color: badgeColor,
              size: 20,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(monthName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
              child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor)),
            ),
          ],
        ),
        subtitle: Text(
          isPaid
              ? 'Paid via $paymentMode • Receipt $receiptNo'
              : 'Due by 5th ${monthName.split(" ").first} • ${heads.length} Itemized Heads',
          style: TextStyle(fontSize: 11.5, color: isPaid ? const Color(0xFF059669) : const Color(0xFF64748B)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹${total.toStringAsFixed(0)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0F172A))),
            // Paid months can never be selected again — only unpaid ones can.
            if (!isPaid) ...[
              const SizedBox(width: 2),
              Checkbox(
                value: _selectedMonths.contains(monthName),
                onChanged: (v) => _toggleMonth(monthName, v ?? false),
                activeColor: const Color(0xFF059669),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                const Text('Itemized Fee Heads Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                ...heads.map((h) {
                  final hTitle = h['title']?.toString() ?? 'Head';
                  final hAmt = (h['amount'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• $hTitle', style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        Text('₹${hAmt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ],
                    ),
                  );
                }),
                if (lateFee > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                          SizedBox(width: 4),
                          Text('Statutory Late Fee Fine (Grace expired 5th):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        ],
                      ),
                      Text('+₹${lateFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                    ],
                  ),
                ],
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Month Payable', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: isPaid
                      ? OutlinedButton.icon(
                          onPressed: () => _downloadReceipt(
                            receiptNo: receiptNo,
                            amount: total,
                            mode: paymentMode,
                            date: m['paid_on']?.toString(),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFF059669)),
                          label: const Text('Download Official Receipt (PDF)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF059669)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _showPaymentDialog(singleMonth: m),
                          icon: const Icon(Icons.payment_rounded, size: 16),
                          label: Text('Pay Month (₹${total.toStringAsFixed(0)})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= STUDENT TAB 2: RECEIPTS & HISTORY =================

  Widget _buildStudentReceiptsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Consolidated download button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Receipts & Statement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A))),
                        Text('Download every receipt or the full 12-month academic statement', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _receipts.isEmpty ? null : _downloadAllReceipts,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(_receipts.isEmpty ? 'No Receipts Yet' : 'Download All Receipts (${_receipts.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _downloadReceipt(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0F172A)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Statement PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Completed Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        if (_receipts.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Text('No fee payment receipts found yet.', style: TextStyle(color: Color(0xFF64748B))),
          )
        else
          ..._receipts.map((r) {
            final no = r['receipt_no']?.toString() ?? 'RCP-2026-000';
            final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
            final mode = r['payment_mode']?.toString() ?? 'Online';
            final head = r['head']?.toString() ?? 'Academic Fee';
            final date = r['paid_on']?.toString() ?? r['created_at']?.toString() ?? '—';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_rounded, color: Color(0xFF059669), size: 20),
                ),
                title: Text(head, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A))),
                subtitle: Text('$no • $mode • $date', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF059669))),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFD97706)),
                      onPressed: () => _downloadReceipt(receiptNo: no, amount: amt, mode: mode, date: date),
                      tooltip: 'Download Receipt PDF',
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // --- HELPERS ---

  Widget _statCard({required String title, required String value, required String subtitle, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return const Color(0xFF2563EB);
      case 'technology':
        return const Color(0xFF7C3AED);
      case 'laboratory':
        return const Color(0xFF059669);
      case 'sports':
        return const Color(0xFFD97706);
      case 'library':
        return const Color(0xFF0284C7);
      case 'evaluation':
        return const Color(0xFFE11D48);
      default:
        return const Color(0xFF475569);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return Icons.school_outlined;
      case 'technology':
        return Icons.computer_outlined;
      case 'laboratory':
        return Icons.science_outlined;
      case 'sports':
        return Icons.sports_soccer_outlined;
      case 'library':
        return Icons.menu_book_outlined;
      case 'evaluation':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(height: 140, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(16))),
        const SizedBox(height: 16),
        Container(height: 80, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(14))),
        const SizedBox(height: 16),
        Container(height: 180, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(16))),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            const Text('Could Not Load Fee Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text(_errorMessage ?? 'An unexpected error occurred.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFeeData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
