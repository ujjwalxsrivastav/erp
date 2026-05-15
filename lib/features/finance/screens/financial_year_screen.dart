import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/finance_service.dart';

class FinancialYearScreen extends StatefulWidget {
  const FinancialYearScreen({super.key});
  @override
  State<FinancialYearScreen> createState() => _FinancialYearScreenState();
}

class _FinancialYearScreenState extends State<FinancialYearScreen> {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _years = [];

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _years = await _service.getFinancialYears();
    setState(() => _isLoading = false);
  }

  Color _statusColor(String s) {
    switch (s) { case 'active': return const Color(0xFF00B894); case 'closed': return const Color(0xFFFDCB6E); case 'locked': return const Color(0xFFEF4444); case 'archived': return const Color(0xFF9CA3AF); default: return _textSec; }
  }

  IconData _statusIcon(String s) {
    switch (s) { case 'active': return Icons.play_circle_rounded; case 'closed': return Icons.stop_circle_rounded; case 'locked': return Icons.lock_rounded; case 'archived': return Icons.archive_rounded; default: return Icons.info_rounded; }
  }

  void _showCreateDialog() {
    final nameC = TextEditingController();
    DateTime? startDate, endDate;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: _cardBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Create Financial Year', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), labelText: 'Year Name (e.g. 2026-27)', labelStyle: const TextStyle(color: _textSec), prefixIcon: const Icon(Icons.calendar_today_rounded, color: _textSec, size: 20))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: InkWell(
            onTap: () async { final d = await showDatePicker(context: ctx, initialDate: DateTime(DateTime.now().year, 4, 1), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setS(() => startDate = d); },
            child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(10)),
              child: Text(startDate != null ? DateFormat('dd MMM yyyy').format(startDate!) : 'Start Date', style: TextStyle(color: startDate != null ? Colors.white : _textSec, fontSize: 13))),
          )),
          const SizedBox(width: 12),
          Expanded(child: InkWell(
            onTap: () async { final d = await showDatePicker(context: ctx, initialDate: DateTime(DateTime.now().year + 1, 3, 31), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setS(() => endDate = d); },
            child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(10)),
              child: Text(endDate != null ? DateFormat('dd MMM yyyy').format(endDate!) : 'End Date', style: TextStyle(color: endDate != null ? Colors.white : _textSec, fontSize: 13))),
          )),
        ]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSec))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primary), onPressed: () async {
          if (nameC.text.isEmpty || startDate == null || endDate == null) return;
          await _service.createFinancialYear({'name': nameC.text, 'start_date': startDate!.toIso8601String().split('T')[0], 'end_date': endDate!.toIso8601String().split('T')[0], 'status': 'active'});
          Navigator.pop(ctx); _load();
        }, child: const Text('Create', style: TextStyle(color: Colors.white))),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _cardBg, foregroundColor: Colors.white, elevation: 0, title: const Text('Financial Year Management', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/accountant-dashboard'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showCreateDialog, backgroundColor: _primary, icon: const Icon(Icons.add_rounded, color: Colors.white), label: const Text('New Year', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : _years.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.calendar_month_rounded, size: 56, color: _primary.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text('No Financial Years', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _years.length,
              itemBuilder: (ctx, i) {
                final y = _years[i];
                final status = (y['status'] ?? 'active') as String;
                final sc = _statusColor(status);
                final isCurrent = y['is_current'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardBg, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isCurrent ? _primary : const Color(0xFF2D2D44), width: isCurrent ? 2 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(_statusIcon(status), color: sc, size: 28)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(y['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          if (isCurrent) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _primary.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: const Text('CURRENT', style: TextStyle(color: _primary, fontSize: 9, fontWeight: FontWeight.w700)))],
                        ]),
                        const SizedBox(height: 4),
                        Text('${y['start_date'] ?? ''} → ${y['end_date'] ?? ''}', style: const TextStyle(color: _textSec, fontSize: 12)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(status.toUpperCase(), style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700))),
                    ]),
                    if (status == 'active') ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () async { await _service.closeFinancialYear(y['id'], 'accountant1'); _load(); },
                          icon: const Icon(Icons.stop_circle_outlined, size: 18),
                          label: const Text('Close Year'),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFDCB6E), side: const BorderSide(color: Color(0xFFFDCB6E)), padding: const EdgeInsets.symmetric(vertical: 12)),
                        )),
                      ]),
                    ],
                    if (y['closed_at'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Closed by ${y['closed_by'] ?? 'N/A'} on ${y['closed_at'] ?? ''}', style: const TextStyle(color: _textSec, fontSize: 11)),
                    ],
                  ]),
                );
              },
            ),
    );
  }
}
