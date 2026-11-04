import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/fee_receipt_pdf.dart';

class SchoolFeeScreen extends StatefulWidget {
  const SchoolFeeScreen({super.key});

  @override
  State<SchoolFeeScreen> createState() => _SchoolFeeScreenState();
}

class _SchoolFeeScreenState extends State<SchoolFeeScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = 'student';
  String _studentUsername = 'sstudent1';
  String _studentName = 'Aarav Sharma';
  String _studentClass = 'Class 10-A';
  String _studentClassId = 'cls-10a';
  String _admissionNo = '';

  List<Map<String, dynamic>> _feeHistory = [];
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _allStudentFeeSummaries = [];
  Map<String, dynamic> _defaulterData = {};
  bool _isAdminFeesLoading = false;
  String? _adminFeesError;
  String _adminFeeSearch = '';

  /// Students/parents see 2 tabs; other staff see 3. Admins get a pending-only
  /// fee list without payment or student-specific fee controls.
  bool get _isStudentRole =>
      _userRole == 'student' || _userRole == 'parent';
  bool get _isAdminRole =>
      _userRole == 'admin' || _userRole == 'sadmin';
  int get _tabCount => _isStudentRole ? 2 : 3;

  List<Map<String, dynamic>> get _filteredStudentFeeSummaries {
    final query = _adminFeeSearch.trim().toLowerCase();
    return _allStudentFeeSummaries.where((student) {
      if (((student['pending_amount'] as num?)?.toDouble() ?? 0) <= 0.01) {
        return false;
      }
      if (query.isEmpty) return true;
      return [
        student['name'],
        student['username'],
        student['class_name'],
        student['section'],
        student['roll_number'],
      ].any((value) => (value ?? '').toString().toLowerCase().contains(query));
    }).toList();
  }

  // Totals computed from the real backend ledger.
  // Every row is a fee demand; `paid_amount` is what has been settled
  // against it. Paying can never change the outstanding total — it only
  // moves money from `pending` to `paid`.
  double get _totalFees =>
      _feeHistory.fold(0.0, (sum, f) => sum + ((f['amount'] as num?)?.toDouble() ?? 0.0));

  double get _paidFees => _feeHistory.fold(0.0, (sum, f) {
        final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (f['paid_amount'] as num?)?.toDouble() ?? 0.0;
        return sum + (paid < amount ? paid : amount);
      });

  double get _pendingFees => ((_totalFees - _paidFees).clamp(0.0, double.infinity));

  /// Fully settled → the pay button is replaced by a receipt download.
  bool get _isFullyPaid => _feeHistory.isNotEmpty && _pendingFees <= 0.01;

  /// Demand rows that still have an outstanding amount (latest first).
  List<Map<String, dynamic>> get _outstandingDemands {
    final items = _feeHistory.where((f) {
      final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
      final paid = (f['paid_amount'] as num?)?.toDouble() ?? 0.0;
      return amount - paid > 0.01;
    }).toList();
    items.sort((a, b) =>
        (a['due_date']?.toString() ?? '9999-12-31')
            .compareTo(b['due_date']?.toString() ?? '9999-12-31'));
    return items;
  }

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadFeeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final role = await _authService.getCurrentUserRole() ?? 'student';
      final username = await _authService.getCurrentUsername() ?? 'sstudent1';
      if (role == 'admin' || role == 'sadmin') {
        if (mounted) setState(() => _userRole = role);
        await _loadAdminStudentFees();
        if (!mounted) return;
        setState(() => _isLoading = false);
        _tabController?.dispose();
        _tabController = null;
        return;
      }
      if (role == 'teacher' || role == 'steacher') {
        if (mounted) {
          setState(() {
            _userRole = role;
            _errorMessage = 'Fee management is restricted to School Administration and Accounts. Teachers do not have access to fee records.';
            _isLoading = false;
          });
        }
        return;
      }
      final targetUser = username;

      final fees = await _schoolService.getStudentFees(targetUser);
      final receipts = await _schoolService.getStudentReceipts(targetUser);
      final defaulters = await _schoolService.getDefaultersWithAgeing();
      final profile =
          await _schoolService.getSchoolStudentProfile(targetUser);

      if (mounted) {
        setState(() {
          _userRole = role;
          _studentUsername = targetUser;
          _feeHistory = fees;
          _receipts = receipts;
          _defaulterData = defaulters;
          if (profile != null) {
            _studentName = profile['name']?.toString() ?? _studentName;
            _studentClass = profile['class_name']?.toString() ?? _studentClass;
            _studentClassId = profile['class_id']?.toString() ?? _studentClassId;
            _admissionNo = profile['admission_no']?.toString() ?? '';
          }
          _isLoading = false;
        });

        // Tab set depends on the role — create it once the role is known.
        if (_tabController == null || _tabController!.length != _tabCount) {
          _tabController?.dispose();
          _tabController = TabController(length: _tabCount, vsync: this);
          setState(() {});
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load fee records. Please check your connection and retry.';
        });
      }
    }
  }

  Future<void> _loadAdminStudentFees() async {
    setState(() {
      _isAdminFeesLoading = true;
      _adminFeesError = null;
    });
    try {
      final summaries = await _schoolService.getAllStudentFeeSummaries();
      if (!mounted) return;
      setState(() {
        _allStudentFeeSummaries = summaries;
        _isAdminFeesLoading = false;
      });
    } catch (e) {
      print('Error loading all student fee summaries: $e');
      if (!mounted) return;
      setState(() {
        _adminFeesError = 'Could not load student fees: $e';
        _isAdminFeesLoading = false;
      });
    }
  }

  void _showPaymentDialog() {
    // Nothing owed → there is nothing to pay. Never allow an over-payment.
    if (_pendingFees <= 0) return;

    final double pendingCap = _pendingFees;
    final amountController = TextEditingController(
        text: pendingCap > 0 ? pendingCap.toStringAsFixed(0) : '');
    String paymentMode = 'UPI / Online';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.payment, color: Color(0xFFF59E0B)),
              SizedBox(width: 10),
              Text('Record / Pay Fee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paying for: $_studentClass ($_studentName)', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if (pendingCap > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Outstanding: ₹${pendingCap.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Amount to Pay (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: paymentMode,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Razorpay Online')),
                    DropdownMenuItem(value: 'Net Banking', child: Text('Net Banking')),
                    DropdownMenuItem(value: 'Debit/Credit Card', child: Text('Debit/Credit Card')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash at Counter')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Bank Cheque / DD')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => paymentMode = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Notes / Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Q3 instalment',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amt <= 0) return;
                if (pendingCap > 0 && amt > pendingCap + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Amount cannot exceed outstanding ₹${pendingCap.toStringAsFixed(0)}'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _confirmFeePayment(amt, paymentMode, notesController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmFeePayment(
      double amt, String paymentMode, String notes) async {
    // Target the earliest outstanding demand's head — the backend allocates
    // the payment by matching head first, then earliest due date.
    final demands = _outstandingDemands;
    final head = demands.isNotEmpty
        ? (demands.first['head']?.toString() ?? 'Composite Fee')
        : 'Composite Fee';

    try {
      final receiptNo = await _schoolService.recordFeePayment({
        'student_id': _studentUsername,
        'class_id': _studentClassId,
        'amount': amt,
        'payment_mode': paymentMode,
        'head': head,
        'due_date': DateTime.now().toIso8601String().substring(0, 10),
        if (notes.isNotEmpty) 'note': notes,
      });

      await _loadFeeData();

      if (mounted) {
        _showReceiptDialog(
          receiptNo,
          amt,
          paymentMode,
          date: DateTime.now().toIso8601String().substring(0, 10),
        );
      }
    } catch (e) {
      // Backend refused (already fully paid / exceeds outstanding / offline)
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadFeeData();
      }
    }
  }

  /// Generate the branded PDF (with school watermark) and open the system
  /// share sheet so the user can download / print / send it.
  Future<void> _downloadReceipt({
    String? receiptNo,
    double? amount,
    String? mode,
    String? date,
  }) async {
    try {
      await FeeReceiptPdf.share(
        studentName: _studentName,
        className: _studentClass,
        admissionNo: _admissionNo.isNotEmpty ? _admissionNo : _studentUsername,
        studentUsername: _studentUsername,
        ledger: _feeHistory,
        receiptNo: receiptNo,
        paymentMode: mode,
        paymentAmount: amount,
        paymentDate: date,
        title: receiptNo == null ? 'FEE STATEMENT' : 'FEE RECEIPT',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate the PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// ADMIN ONLY: update the total fee demand from the screen. The service
  /// re-checks the role, so this is a convenience — not the security boundary.
  void _showSetDemandDialog() {    if (!_isAdminRole) return;
    final headCtrl = TextEditingController(text: 'Quarter 4 Tuition Fee');
    final amountCtrl = TextEditingController();
    final dueCtrl = TextEditingController(
        text: DateTime.now().add(const Duration(days: 15))
            .toIso8601String()
            .substring(0, 10));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.admin_panel_settings, color: Color(0xFF92400E)),
            SizedBox(width: 10),
            Text('Set Fee Demand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: $_studentName ($_studentUsername)',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 14),
              const Text('Fee Head', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: headCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Quarter 4 Tuition Fee',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: dueCtrl,
                decoration: InputDecoration(
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Admin only — students and teachers read this total, they cannot change it.',
                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final head = headCtrl.text.trim();
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (head.isEmpty || amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a fee head and an amount greater than 0'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final result = await _schoolService.setFeeDemand(
                  studentId: _studentUsername,
                  head: head,
                  amount: amt,
                  dueDate: dueCtrl.text.trim(),
                  classId: _studentClassId,
                );
                await _loadFeeData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result == 'updated'
                          ? 'Fee demand updated — total is now ₹${_totalFees.toStringAsFixed(0)}'
                          : 'New fee demand created — ₹${amt.toStringAsFixed(0)}'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF92400E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Demand'),
          ),
        ],
      ),
    );
  }

  void _showReceiptDialog(String receiptNo, double amount, String mode,
      {String? date}) {
    final paidDate = date ?? DateTime.now().toIso8601String().substring(0, 10);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Payment Successful', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _receiptRow('Receipt Number', receiptNo),
                  _receiptRow('Student Name', _studentName),
                  _receiptRow('Class & Section', _studentClass),
                  _receiptRow('Amount Paid', '₹${amount.toStringAsFixed(0)}'),
                  _receiptRow('Payment Mode', mode),
                  _receiptRow('Date', paidDate),
                  _receiptRow('Status',
                      _pendingFees <= 0 ? 'FULLY PAID — NO DUES' : 'CONFIRMED (PAID)'),
                  const Divider(height: 16),
                  const Text('Digital Verification Seal: Verified by Shivalik International Accounts', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preparing your receipt PDF…'),
                      backgroundColor: Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _downloadReceipt(
                    receiptNo: receiptNo,
                    amount: amount,
                    mode: mode,
                    date: paidDate,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                label: const Text('Download Receipt PDF', style: TextStyle(fontWeight: FontWeight.bold)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      Tab(text: 'Summary'),
      Tab(text: 'Receipts'),
      if (!_isStudentRole) Tab(text: 'Defaulters'),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isAdminRole ? 'Fee Management & Accounts' : 'Fee Details & Payments',
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF92400E), Color(0xFFD97706), Color(0xFFF59E0B)],
            ),
          ),
        ),
        bottom: _isAdminRole || _tabController == null
            ? null
            : PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF92400E),
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: tabs,
            ),
          ),
        ),
      ),
      body: _isLoading || _tabController == null
          ? (_isAdminRole && !_isLoading
              ? _buildAllStudentFeesTab()
              : _buildLoadingSkeleton())
          : _isAdminRole
              ? _buildAllStudentFeesTab()
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(),
                    _buildHistoryTab(),
                    if (!_isStudentRole) _buildDefaultersTab(),
                  ],
                ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Fee Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An error occurred while loading fees.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadFeeData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllStudentFeesTab() {
    if (_isAdminFeesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD97706)),
      );
    }
    if (_adminFeesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _adminFeesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadAdminStudentFees,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final students = _filteredStudentFeeSummaries;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _adminFeeSearch = value),
            decoration: InputDecoration(
              hintText: 'Search name, username, class or roll number',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Students with pending fees: ${students.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAdminStudentFees,
            color: const Color(0xFFD97706),
            child: students.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 56),
                        child: Center(
                          child: Text(
                            _adminFeeSearch.trim().isEmpty
                                ? 'No students have pending fees.'
                                : 'No students match your search.',
                            style:
                                const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: students.length,
                    itemBuilder: (context, index) =>
                        _buildAdminStudentFeeCard(students[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminStudentFeeCard(Map<String, dynamic> student) {
    final name = (student['name'] ?? '').toString().trim();
    final username = (student['username'] ?? '').toString();
    final className = (student['class_name'] ?? '').toString();
    final section = (student['section'] ?? '').toString();
    final roll = (student['roll_number'] ?? '').toString();
    final total = (student['total_fee'] as num?)?.toDouble() ?? 0;
    final paid = (student['paid_amount'] as num?)?.toDouble() ?? 0;
    final pending = (student['pending_amount'] as num?)?.toDouble() ?? 0;
    final status = total <= 0
        ? 'No fee set'
        : pending <= 0.01
            ? 'Paid'
            : paid > 0
                ? 'Partially paid'
                : 'Pending';
    final statusColor = pending <= 0.01 && total > 0
        ? const Color(0xFF059669)
        : paid > 0
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    final classDetail = [
      if (className.isNotEmpty) className,
      if (section.isNotEmpty) 'Section $section',
      if (roll.isNotEmpty) 'Roll $roll',
    ].join(' • ');

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFEF3C7),
                  child: Text(
                    (name.isNotEmpty ? name : username)
                        .characters
                        .first
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? username : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '$username${classDetail.isEmpty ? '' : ' • $classDetail'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                _buildStudentFeeAmount('Total', total, const Color(0xFF334155)),
                _buildStudentFeeAmount('Paid', paid, const Color(0xFF059669)),
                _buildStudentFeeAmount(
                  'Pending',
                  pending,
                  pending > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF64748B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentFeeAmount(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 3),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    final progress = _totalFees > 0 ? (_paidFees / _totalFees).clamp(0.0, 1.0) : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Academic Year 2026-27 Fee Status', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_paidFees.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      ' / ₹${_totalFees.toStringAsFixed(0)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFeeStat('Total Paid', '₹${_paidFees.toStringAsFixed(0)}', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    _buildFeeStat('Total Pending', '₹${_pendingFees.toStringAsFixed(0)}', const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Policy Badges (Sibling / Staff / RTE)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Text('Institutional Concession Policies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('• Sibling Concession: 15% discount on quarterly tuition fee for younger sibling.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('• Staff Ward Policy: 25% educational concession on tuition.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('• RTE Act 25% Quota: Zero fee to parent; booked as Government Receivable.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fee Structure ($_studentClass)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Live demand ledger — read from the accounts backend',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Download fee statement (PDF)',
                      onPressed: () => _downloadReceipt(),
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          color: Color(0xFFEF4444), size: 22),
                    ),
                    if (_isAdminRole)
                      IconButton(
                        tooltip: 'Admin: set fee demand',
                        onPressed: _showSetDemandDialog,
                        icon: const Icon(Icons.edit_outlined,
                            color: Color(0xFF92400E), size: 22),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_outstandingDemands.isEmpty && _feeHistory.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No fee records found for this student.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  )
                else if (_outstandingDemands.isEmpty)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                      SizedBox(width: 8),
                      Text('All demands fully settled',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                    ],
                  )
                else
                  ..._outstandingDemands.map((d) {
                    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
                    final paid = (d['paid_amount'] as num?)?.toDouble() ?? 0.0;
                    final remaining = (amount - paid).clamp(0.0, double.infinity);
                    final isPartial = paid > 0.01 && remaining > 0.01;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['head']?.toString() ?? 'Fee',
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Due ${d['due_date']?.toString() ?? '—'}${isPartial ? ' · ₹${paid.toStringAsFixed(0)} already paid' : ''}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          if (isPartial) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Partial',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '₹${remaining.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                          ),
                        ],
                      ),
                    );
                  }),
                const Divider(),
                Row(
                  children: [
                    const Text('Outstanding Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const Spacer(),
                    Text(
                      '₹${_pendingFees.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isFullyPaid)
            // Fully settled → no more payments possible, receipt is ready.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981), width: 1.2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.verified, color: Color(0xFF10B981), size: 22),
                      SizedBox(width: 8),
                      Text('All Fees Paid — No Dues',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total ₹${_totalFees.toStringAsFixed(0)} fully settled. '
                    'No further payment can be made against this account.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF065F46)),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Preparing your fee receipt PDF…'),
                            backgroundColor: Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _downloadReceipt();
                      },
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text('Download Fee Receipt',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showPaymentDialog,
                icon: const Icon(Icons.payment, color: Colors.white),
                label: Text(
                  'Pay Outstanding (₹${_pendingFees.toStringAsFixed(0)})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeeStat(String label, String amount, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            Text(label, style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_feeHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No fee records found', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _showPaymentDialog,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
              child: const Text('Record First Payment'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _feeHistory.length,
      itemBuilder: (context, index) {
        final f = _feeHistory[index];
        final status = (f['status'] ?? 'pending').toString().toLowerCase();
        final receiptNo = f['receipt_no'] as String?;
        final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
        final paidRaw = (f['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final paidAmount = paidRaw < amount ? paidRaw : amount;
        final head = f['head'] ?? 'Quarter Tuition Fee';
        final dueDate = f['due_date'] ?? 'Upcoming';
        final createdAt = f['created_at']?.toString() ?? '';
        final createdDate = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : null;

        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'paid':
            statusColor = const Color(0xFF10B981);
            statusLabel = 'Paid';
            break;
          case 'partial':
            statusColor = const Color(0xFFF59E0B);
            statusLabel = 'Partial';
            break;
          default:
            statusColor = const Color(0xFFEF4444);
            statusLabel = 'Pending';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_outlined, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(head, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    const SizedBox(height: 4),
                    Text(
                      status == 'paid'
                          ? 'Paid via ${f['payment_mode'] ?? "Online"}'
                          : 'Due by $dueDate',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (receiptNo != null && receiptNo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          receiptNo,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                      ),
                      if (receiptNo != null && receiptNo.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'View / download receipt',
                          child: InkWell(
                            onTap: () => _showReceiptDialog(
                              receiptNo,
                              paidAmount > 0 ? paidAmount : amount,
                              f['payment_mode']?.toString() ?? 'Online',
                              date: createdDate,
                            ),
                            child: const Icon(Icons.picture_as_pdf_outlined,
                                size: 18, color: Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultersTab() {
    final b0 = (_defaulterData['bucket_0_30'] as List?) ?? [];
    final b31 = (_defaulterData['bucket_31_60'] as List?) ?? [];
    final b61 = (_defaulterData['bucket_61_90'] as List?) ?? [];
    final b90 = (_defaulterData['bucket_90_plus'] as List?) ?? [];
    final totalPending = (_defaulterData['total_pending'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Overdue Fees', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('₹${totalPending.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Ageing Analysis Buckets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildAgeingCard('0 - 30 Days Overdue', b0, Colors.amber),
          _buildAgeingCard('31 - 60 Days Overdue', b31, Colors.orange),
          _buildAgeingCard('61 - 90 Days Overdue', b61, Colors.deepOrange),
          _buildAgeingCard('90+ Days (Critical Notice)', b90, Colors.red),
        ],
      ),
    );
  }

  Widget _buildAgeingCard(String title, List items, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade200),
      ),
      child: ExpansionTile(
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.shade800)),
        subtitle: Text('${items.length} accounts overdue', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: items.isEmpty
            ? [const Padding(padding: EdgeInsets.all(12), child: Text('No accounts in this bucket', style: TextStyle(fontSize: 12, color: Colors.grey)))]
            : items.map((item) {
                final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline, size: 20),
                  title: Text(item['student_id'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Due: ${item['due_date'] ?? "N/A"} • ${item['head'] ?? "Fee"}'),
                  trailing: Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                );
              }).toList(),
      ),
    );
  }
}
