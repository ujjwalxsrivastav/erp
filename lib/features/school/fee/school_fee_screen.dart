import 'package:flutter/material.dart';

class SchoolFeeScreen extends StatefulWidget {
  const SchoolFeeScreen({super.key});

  @override
  State<SchoolFeeScreen> createState() => _SchoolFeeScreenState();
}

class _SchoolFeeScreenState extends State<SchoolFeeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _feeHistory = [
    {'quarter': 'Q1 (Apr-Jun)', 'amount': 15000, 'paid': 15000, 'date': '05 Apr 2024', 'status': 'paid'},
    {'quarter': 'Q2 (Jul-Sep)', 'amount': 15000, 'paid': 15000, 'date': '08 Jul 2024', 'status': 'paid'},
    {'quarter': 'Q3 (Oct-Dec)', 'amount': 15000, 'paid': 10000, 'date': '15 Oct 2024', 'status': 'partial'},
    {'quarter': 'Q4 (Jan-Mar)', 'amount': 15000, 'paid': 0, 'date': 'Not paid', 'status': 'pending'},
  ];

  final Map<String, dynamic> _feeBreakdown = {
    'Tuition Fee': 10000,
    'Exam Fee': 2000,
    'Sports Fee': 1000,
    'Library Fee': 500,
    'Lab Fee': 1500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Fee Details', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Summary'), Tab(text: 'History')],
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
              boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Annual Fee Status', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _paidFees / _totalFees,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFeeStat('Paid', '₹$_paidFees', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    _buildFeeStat('Pending', '₹$_pendingFees', const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fee Breakdown (Per Quarter)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
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
                    const Text('Quarterly Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
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
          const SizedBox(height: 16),
          if (_pendingFees > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment gateway integration coming soon!')),
                  );
                },
                icon: const Icon(Icons.payment, color: Colors.white),
                label: Text(
                  'Pay Pending ₹$_pendingFees',
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
            Text(label, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8))),
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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
                          ? 'Paid on ${f['date']}'
                          : status == 'partial'
                              ? 'Partial: ₹${f['paid']}/${f['amount']}'
                              : 'Payment due',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${f['amount']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
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

