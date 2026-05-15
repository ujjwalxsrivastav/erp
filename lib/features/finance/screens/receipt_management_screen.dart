import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/finance_service.dart';

class ReceiptManagementScreen extends StatefulWidget {
  const ReceiptManagementScreen({super.key});
  @override
  State<ReceiptManagementScreen> createState() => _ReceiptManagementScreenState();
}

class _ReceiptManagementScreenState extends State<ReceiptManagementScreen> {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _receipts = [];

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _receipts = await _service.getReceipts();
    setState(() => _isLoading = false);
  }

  Color _statusColor(String s) {
    switch (s) { case 'completed': return const Color(0xFF00B894); case 'bounced': return const Color(0xFFEF4444); case 'cancelled': return const Color(0xFFE17055); default: return const Color(0xFFFDCB6E); }
  }

  String _formatDate(String? d) { if (d == null) return 'N/A'; try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; } }

  @override
  Widget build(BuildContext context) {
    double totalAmount = 0;
    for (var r in _receipts) if (r['status'] == 'completed') totalAmount += (r['total_amount'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _cardBg, foregroundColor: Colors.white, elevation: 0, title: const Text('Receipt Management', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/accountant-dashboard'))),
      body: Column(children: [
        // Stats
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statCol('Total Receipts', '${_receipts.length}'),
            Container(width: 1, height: 40, color: Colors.white30),
            _statCol('Total Amount', '₹${NumberFormat('#,##0').format(totalAmount)}'),
            Container(width: 1, height: 40, color: Colors.white30),
            _statCol('Completed', '${_receipts.where((r) => r['status'] == 'completed').length}'),
          ]),
        ),
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _receipts.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.receipt_long_rounded, size: 56, color: _primary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text('No Receipts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _receipts.length,
                  itemBuilder: (ctx, i) {
                    final r = _receipts[i];
                    final sc = _statusColor(r['status'] ?? 'pending');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2D2D44))),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.receipt_rounded, color: sc, size: 22)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r['receipt_number'] ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.person_rounded, size: 14, color: _textSec),
                            const SizedBox(width: 4),
                            Text(r['student_id'] ?? '', style: const TextStyle(color: _textSec, fontSize: 12)),
                            const SizedBox(width: 12),
                            Icon(Icons.payment_rounded, size: 14, color: _textSec),
                            const SizedBox(width: 4),
                            Text((r['payment_mode'] ?? 'N/A').toString().toUpperCase(), style: const TextStyle(color: _textSec, fontSize: 11)),
                            const SizedBox(width: 12),
                            Text(_formatDate(r['receipt_date']?.toString()), style: const TextStyle(color: _textSec, fontSize: 11)),
                          ]),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('₹${((r['total_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text((r['status'] ?? 'pending').toString().toUpperCase(), style: TextStyle(color: sc, fontSize: 9, fontWeight: FontWeight.w700))),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _statCol(String label, String val) => Column(children: [
    Text(val, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}
