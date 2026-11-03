import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/finance_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  String _filterEntity = 'all';

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _logs = await _service.getAuditLogs(limit: 200);
    setState(() => _isLoading = false);
  }

  Color _actionColor(String a) {
    switch (a) { case 'create': return const Color(0xFF00B894); case 'update': return const Color(0xFF74B9FF); case 'delete': return const Color(0xFFEF4444); case 'approve': return const Color(0xFFA29BFE); default: return const Color(0xFFFDCB6E); }
  }

  IconData _actionIcon(String a) {
    switch (a) { case 'create': return Icons.add_circle_rounded; case 'update': return Icons.edit_rounded; case 'delete': return Icons.delete_rounded; case 'approve': return Icons.check_circle_rounded; default: return Icons.info_rounded; }
  }

  List<Map<String, dynamic>> get _filtered => _filterEntity == 'all' ? _logs : _logs.where((l) => l['entity_type'] == _filterEntity).toList();

  @override
  Widget build(BuildContext context) {
    final entityTypes = _logs.map((l) => l['entity_type'] as String?).where((e) => e != null).toSet().toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _cardBg, foregroundColor: Colors.white, elevation: 0, title: const Text('Audit Trail', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/accountant-dashboard')),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load), const SizedBox(width: 8)]),
      body: Column(children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _chip('All', 'all'),
            ...entityTypes.map((e) => Padding(padding: const EdgeInsets.only(left: 8), child: _chip(e!.replaceAll('_', ' ').toUpperCase(), e))),
          ])),
        ),
        // Stats
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          _statBadge('Total Logs', _logs.length, _primary),
          const SizedBox(width: 8),
          _statBadge('Creates', _logs.where((l) => l['action'] == 'create').length, const Color(0xFF00B894)),
          const SizedBox(width: 8),
          _statBadge('Updates', _logs.where((l) => l['action'] == 'update').length, const Color(0xFF74B9FF)),
          const SizedBox(width: 8),
          _statBadge('Deletes', _logs.where((l) => l['action'] == 'delete').length, const Color(0xFFEF4444)),
        ])),
        const SizedBox(height: 12),
        // Timeline
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _filtered.isEmpty
              ? const Center(child: Text('No audit logs found', style: TextStyle(color: _textSec)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final log = _filtered[i];
                    final action = (log['action'] ?? 'info') as String;
                    final ac = _actionColor(action);
                    String timeStr = '';
                    if (log['created_at'] != null) { try { timeStr = DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.parse(log['created_at'])); } catch (_) {} }

                    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Timeline line
                      SizedBox(width: 30, child: Column(children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: ac, shape: BoxShape.circle, boxShadow: [BoxShadow(color: ac.withOpacity(0.4), blurRadius: 6)])),
                        if (i < _filtered.length - 1) Expanded(child: Container(width: 2, color: const Color(0xFF2D2D44))),
                      ])),
                      const SizedBox(width: 12),
                      Expanded(child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2D2D44))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(_actionIcon(action), color: ac, size: 18),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ac.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(action.toUpperCase(), style: TextStyle(color: ac, fontSize: 10, fontWeight: FontWeight.w700))),
                            const SizedBox(width: 8),
                            Text((log['entity_type'] ?? '').toString().replaceAll('_', ' '), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(timeStr, style: const TextStyle(color: _textSec, fontSize: 10)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.person_rounded, size: 14, color: _textSec),
                            const SizedBox(width: 4),
                            Text(log['performed_by'] ?? 'system', style: const TextStyle(color: _textSec, fontSize: 12)),
                          ]),
                          if (log['description'] != null)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(log['description'], style: const TextStyle(color: _textSec, fontSize: 11))),
                        ]),
                      )),
                    ]));
                  },
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _filterEntity == value;
    return GestureDetector(
      onTap: () => setState(() => _filterEntity = value),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: sel ? _primary : _cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? _primary : const Color(0xFF2D2D44))),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : _textSec, fontSize: 11, fontWeight: FontWeight.w600))),
    );
  }

  Widget _statBadge(String label, int count, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Text('$count', style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(width: 4), Text(label, style: TextStyle(color: c.withOpacity(0.8), fontSize: 11))]),
  );
}
