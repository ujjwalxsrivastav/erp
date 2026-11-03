import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class SchoolFeeScreen extends StatefulWidget {
  const SchoolFeeScreen({super.key});

  @override
  State<SchoolFeeScreen> createState() => _SchoolFeeScreenState();
}

class _SchoolFeeScreenState extends State<SchoolFeeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _schoolService = SchoolService();

  final List<Map<String, dynamic>> _feeHistory = [
    {'quarter': 'Q1 (Apr-Jun)', 'amount': 15000, 'paid': 15000, 'date': '05 Apr 2026', 'status': 'paid', 'receipt_no': 'REC-9081', 'mode': 'UPI'},
    {'quarter': 'Q2 (Jul-Sep)', 'amount': 15000, 'paid': 15000, 'date': '08 Jul 2026', 'status': 'paid', 'receipt_no': 'REC-9412', 'mode': 'Net Banking'},
    {'quarter': 'Q3 (Oct-Dec)', 'amount': 15000, 'paid': 10000, 'date': '15 Oct 2026', 'status': 'partial', 'receipt_no': 'REC-9705', 'mode': 'Cheque'},
    {'quarter': 'Q4 (Jan-Mar)', 'amount': 15000, 'paid': 0, 'date': 'Not paid', 'status': 'pending', 'receipt_no': null, 'mode': '-'},
  ];

  final Map<String, dynamic> _feeBreakdown = {
    'Tuition Fee': 10000,
    'Exam & Activity Fee': 2000,
    'Sports & Physical Ed': 1000,
    'Library & Computer Lab': 1000,
    'Science Practical Lab': 1000,
  };

  int get _totalFees => _feeHistory.fold(0, (sum, f) => sum + (f['amount'] as int));
  int get _paidFees => _feeHistory.fold(0, (sum, f) => sum + (f['paid'] as int));
  int get _pendingFees => _totalFees - _paidFees;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPaymentDialog() {
    final amountController = TextEditingController(text: '$_pendingFees');
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
              Text('Fee Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paying for: Class 10-A (Aarav Sharma)', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                  value: paymentMode,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Online')),
                    DropdownMenuItem(value: 'Net Banking', child: Text('Net Banking')),
                    DropdownMenuItem(value: 'Debit/Credit Card', child: Text('Debit/Credit Card')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash at Counter')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Bank Cheque')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => paymentMode = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Transaction / Reference Note', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'e.g. UPI Ref: 48921890',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amt = int.tryParse(amountController.text.trim()) ?? 0;
                if (amt <= 0) return;
                Navigator.pop(ctx);

                final newRecNo = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                await _schoolService.recordFeePayment({
                  'student_id': 'SCH-01',
                  'amount': amt,
                  'paid_amount': amt,
                  'payment_mode': paymentMode,
                  'receipt_no': newRecNo,
                  'status': 'paid',
                  'created_at': DateTime.now().toIso8601String(),
                });

                setState(() {
                  _feeHistory.insert(0, {
                    'quarter': 'Fee Payment (${DateTime.now().month}/${DateTime.now().year})',
                    'amount': amt,
                    'paid': amt,
                    'date': 'Today',
                    'status': 'paid',
                    'receipt_no': newRecNo,
                    'mode': paymentMode,
                  });
                });

                _showReceiptDialog(newRecNo, amt, paymentMode);
              },
              child: const Text('Confirm Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptDialog(String receiptNo, int amount, String mode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Payment Successful!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Receipt Number: $receiptNo', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
            const Divider(height: 30),
            _receiptRow('Amount Paid:', '₹$amount'),
            _receiptRow('Payment Mode:', mode),
            _receiptRow('Student Name:', 'Aarav Sharma'),
            _receiptRow('Class & Section:', 'Class 10-A'),
            _receiptRow('Date:', DateTime.now().toIso8601String().substring(0, 10)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Receipt $receiptNo downloaded successfully'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.download, color: Colors.white, size: 18),
                label: const Text('Download Receipt PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Fee Details & Collection', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Summary & Structure'), Tab(text: 'Payment History & Receipts')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildHistoryTab(),
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
                      '₹$_paidFees',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      ' / ₹$_totalFees',
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
                    _buildFeeStat('Total Paid', '₹$_paidFees', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    _buildFeeStat('Total Pending', '₹$_pendingFees', const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                const Text('Fee Breakdown (Per Term)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 14),
                ..._feeBreakdown.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                      const Spacer(),
                      Text(
                        '₹${e.value}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                      ),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  children: [
                    const Text('Term Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const Spacer(),
                    Text(
                      '₹${_feeBreakdown.values.fold(0, (a, b) => a + (b as int))}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showPaymentDialog,
              icon: const Icon(Icons.payment, color: Colors.white),
              label: Text(
                _pendingFees > 0 ? 'Collect / Pay Pending (₹$_pendingFees)' : 'Record Advance / Extra Fee',
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _feeHistory.length,
      itemBuilder: (context, index) {
        final f = _feeHistory[index];
        final status = f['status'] as String;
        final receiptNo = f['receipt_no'] as String?;
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
                    Text(f['quarter'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    const SizedBox(height: 4),
                    Text(
                      status == 'paid'
                          ? 'Paid on ${f['date']} • Mode: ${f['mode'] ?? "Online"}'
                          : status == 'partial'
                              ? 'Partial: ₹${f['paid']}/${f['amount']}'
                              : 'Payment due',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (receiptNo != null)
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
                  Text('₹${f['amount']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
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
                      if (receiptNo != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showReceiptDialog(receiptNo, f['paid'] as int, f['mode']?.toString() ?? 'Online'),
                          child: const Icon(Icons.print_outlined, size: 18, color: Color(0xFFF59E0B)),
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
}
