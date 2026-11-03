import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/finance_service.dart';

class StudentLedgerScreen extends StatefulWidget {
  const StudentLedgerScreen({super.key});
  @override
  State<StudentLedgerScreen> createState() => _StudentLedgerScreenState();
}

class _StudentLedgerScreenState extends State<StudentLedgerScreen> {
  final _service = FinanceService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allocations = [];
  List<Map<String, dynamic>> _receipts = [];
  String? _selectedStudent;

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() { super.initState(); _loadStudents(); }

  Future<void> _loadStudents() async {
    _students = await _service.getStudentsWithDetails();
    setState(() {});
  }

  Future<void> _loadStudentData(String studentId) async {
    setState(() { _selectedStudent = studentId; _isLoading = true; });
    _allocations = await _service.getStudentAllocations(studentId);
    _receipts = await _service.getReceipts(studentId: studentId);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    double totalAllocated = 0, totalPaid = 0, totalBalance = 0;
    for (var a in _allocations) {
      totalAllocated += (a['net_amount'] as num?)?.toDouble() ?? 0;
      totalPaid += (a['paid_amount'] as num?)?.toDouble() ?? 0;
      totalBalance += (a['balance_amount'] as num?)?.toDouble() ?? 0;
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _cardBg, foregroundColor: Colors.white, elevation: 0, title: const Text('Student Ledger', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/accountant-dashboard'))),
      body: Row(children: [
        // Student list sidebar
        Container(
          width: 280,
          decoration: const BoxDecoration(color: _cardBg, border: Border(right: BorderSide(color: Color(0xFF2D2D44)))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), hintText: 'Search students...', hintStyle: const TextStyle(color: _textSec, fontSize: 12), prefixIcon: const Icon(Icons.search, color: _textSec, size: 18), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _students.length,
                itemBuilder: (ctx, i) {
                  final s = _students[i];
                  final id = s['student_id'] ?? '';
                  final sel = id == _selectedStudent;
                  return InkWell(
                    onTap: () => _loadStudentData(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: sel ? _primary.withOpacity(0.15) : Colors.transparent, border: Border(left: BorderSide(color: sel ? _primary : Colors.transparent, width: 3))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s['name'] ?? id, style: TextStyle(color: sel ? Colors.white : _textSec, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${s['department'] ?? ''} • $id', style: const TextStyle(color: _textSec, fontSize: 10)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        // Main content
        Expanded(
          child: _selectedStudent == null
            ? const Center(child: Text('Select a student to view their ledger', style: TextStyle(color: _textSec, fontSize: 16)))
            : _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Financial Profile: $_selectedStudent', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      // Summary cards
                      Row(children: [
                        _summaryCard('Total Allocated', totalAllocated, const Color(0xFF74B9FF)),
                        const SizedBox(width: 12),
                        _summaryCard('Total Paid', totalPaid, const Color(0xFF00B894)),
                        const SizedBox(width: 12),
                        _summaryCard('Outstanding', totalBalance, const Color(0xFFFD79A8)),
                        const SizedBox(width: 12),
                        _summaryCard('Receipts', _receipts.length.toDouble(), _primary),
                      ]),
                      const SizedBox(height: 24),
                      // Allocations table
                      const Text('Fee Allocations', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (_allocations.isEmpty)
                        Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('No fee allocations', style: TextStyle(color: _textSec))))
                      else
                        Container(
                          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2D2D44))),
                          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF16213E)),
                            dataRowColor: WidgetStateProperty.all(Colors.transparent),
                            columns: const [
                              DataColumn(label: Text('Fee Head', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Original', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Net Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Paid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Due Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                            ],
                            rows: _allocations.map((a) {
                              final status = a['status'] ?? 'pending';
                              final sc = status == 'paid' ? const Color(0xFF00B894) : status == 'overdue' ? const Color(0xFFEF4444) : const Color(0xFFFDCB6E);
                              return DataRow(cells: [
                                DataCell(Text(a['fee_head_id'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                                DataCell(Text('₹${a['original_amount'] ?? 0}', style: const TextStyle(color: _textSec, fontSize: 12))),
                                DataCell(Text('₹${a['net_amount'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                                DataCell(Text('₹${a['paid_amount'] ?? 0}', style: const TextStyle(color: Color(0xFF00B894), fontSize: 12))),
                                DataCell(Text('₹${a['balance_amount'] ?? 0}', style: TextStyle(color: (a['balance_amount'] as num?)?.toDouble() == 0 ? const Color(0xFF00B894) : const Color(0xFFFD79A8), fontSize: 12, fontWeight: FontWeight.w600))),
                                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(status.toString().toUpperCase(), style: TextStyle(color: sc, fontSize: 9, fontWeight: FontWeight.w700)))),
                                DataCell(Text(a['due_date'] ?? 'N/A', style: const TextStyle(color: _textSec, fontSize: 12))),
                              ]);
                            }).toList(),
                          )),
                        ),
                      const SizedBox(height: 24),
                      const Text('Payment History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      ..._receipts.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2D2D44))),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF00B894).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r['receipt_number'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${r['payment_mode'] ?? ''} • ${r['receipt_date'] ?? ''}', style: const TextStyle(color: _textSec, fontSize: 11)),
                          ])),
                          Text('₹${r['total_amount'] ?? 0}', style: const TextStyle(color: Color(0xFF00B894), fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                      )),
                    ]),
                  )),
                ]),
        ),
      ]),
    );
  }

  Widget _summaryCard(String label, double value, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(value == value.roundToDouble() && value < 100 ? '${value.toInt()}' : '₹${value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
    ]),
  ));
}
