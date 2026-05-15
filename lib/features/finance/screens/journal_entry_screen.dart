import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/finance_service.dart';

class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key});
  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _entries = [];

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _entries = await _service.getJournalEntries();
    setState(() => _isLoading = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'posted': return const Color(0xFF00B894);
      case 'approved': return const Color(0xFF74B9FF);
      case 'draft': return const Color(0xFFFDCB6E);
      case 'rejected': return const Color(0xFFEF4444);
      case 'pending_approval': return const Color(0xFFA29BFE);
      default: return _textSec;
    }
  }

  void _showCreateDialog() {
    final narrationC = TextEditingController();
    String type = 'standard';
    List<Map<String, dynamic>> accounts = [];
    List<_JELine> lines = [_JELine(), _JELine()];

    _service.getChartOfAccounts().then((accs) {
      accounts = accs;
      showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        double totalDebit = 0, totalCredit = 0;
        for (var l in lines) { totalDebit += l.debit; totalCredit += l.credit; }
        final balanced = (totalDebit - totalCredit).abs() < 0.01 && totalDebit > 0;

        return AlertDialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Journal Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(width: 700, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: type, dropdownColor: _cardBg, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), labelText: 'Entry Type', labelStyle: const TextStyle(color: _textSec)),
                items: ['standard', 'adjusting', 'closing', 'reversing', 'correction'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                onChanged: (v) => setS(() => type = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: narrationC, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), labelText: 'Narration', labelStyle: const TextStyle(color: _textSec)),
              )),
            ]),
            const SizedBox(height: 16),
            ...lines.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(flex: 3, child: DropdownButtonFormField<String>(
                  initialValue: e.value.accountId, dropdownColor: _cardBg, style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), labelText: 'Account', labelStyle: const TextStyle(color: _textSec, fontSize: 11), isDense: true),
                  items: accounts.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text('${a['account_code']} - ${a['account_name']}', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setS(() => e.value.accountId = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), labelText: 'Debit', labelStyle: const TextStyle(color: _textSec, fontSize: 11), isDense: true),
                  onChanged: (v) => setS(() => e.value.debit = double.tryParse(v) ?? 0),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(filled: true, fillColor: const Color(0xFF16213E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), labelText: 'Credit', labelStyle: const TextStyle(color: _textSec, fontSize: 11), isDense: true),
                  onChanged: (v) => setS(() => e.value.credit = double.tryParse(v) ?? 0),
                )),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 20), onPressed: lines.length > 2 ? () => setS(() => lines.removeAt(e.key)) : null),
              ]),
            )),
            TextButton.icon(
              onPressed: () => setS(() => lines.add(_JELine())),
              icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add Line'),
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: balanced ? const Color(0xFF00B894).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total Debit: ₹${totalDebit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('Total Credit: ₹${totalCredit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Icon(balanced ? Icons.check_circle_rounded : Icons.error_rounded, color: balanced ? const Color(0xFF00B894) : const Color(0xFFEF4444)),
              ]),
            ),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSec))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: balanced ? _primary : Colors.grey),
              onPressed: balanced ? () async {
                await _service.createJournalEntry(
                  {'entry_type': type, 'narration': narrationC.text, 'total_debit': totalDebit, 'total_credit': totalCredit, 'status': 'draft', 'created_by': 'accountant1'},
                  lines.where((l) => l.accountId != null).map((l) => {'account_id': l.accountId, 'debit_amount': l.debit, 'credit_amount': l.credit}).toList(),
                );
                Navigator.pop(ctx); _load();
              } : null,
              child: const Text('Save as Draft', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Journal Entries', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/accountant-dashboard')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog, backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : _entries.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.book_rounded, size: 48, color: _primary)),
              const SizedBox(height: 16),
              const Text('No Journal Entries', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Create your first journal entry', style: TextStyle(color: _textSec)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (ctx, i) {
                final e = _entries[i];
                final status = (e['status'] ?? 'draft') as String;
                final sc = _statusColor(status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2D2D44))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.book_rounded, color: sc, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e['entry_number'] ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('${e['entry_type'] ?? 'standard'} • ${e['entry_date'] ?? ''}', style: const TextStyle(color: _textSec, fontSize: 11)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(status.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.w700))),
                    ]),
                    if (e['narration'] != null && (e['narration'] as String).isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 10), child: Text(e['narration'], style: const TextStyle(color: _textSec, fontSize: 12))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('Debit: ₹${((e['total_debit'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00B894), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 20),
                      Text('Credit: ₹${((e['total_credit'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFD79A8), fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (status == 'draft') ...[
                        IconButton(icon: const Icon(Icons.check_circle_outline, color: Color(0xFF00B894), size: 22), onPressed: () async { await _service.approveJournalEntry(e['id'], 'accountant1'); _load(); }),
                        IconButton(icon: const Icon(Icons.publish_rounded, color: Color(0xFF74B9FF), size: 22), onPressed: () async { await _service.postJournalEntry(e['id']); _load(); }),
                      ],
                    ]),
                  ]),
                );
              },
            ),
    );
  }
}

class _JELine {
  String? accountId;
  double debit = 0;
  double credit = 0;
}
