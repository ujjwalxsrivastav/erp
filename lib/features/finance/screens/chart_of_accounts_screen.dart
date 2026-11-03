import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/finance_service.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});
  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _accounts = [];
  String _filterType = 'all';

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _accounts = await _service.getChartOfAccounts();
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filtered => _filterType == 'all'
      ? _accounts
      : _accounts.where((a) => a['account_type'] == _filterType).toList();

  Color _typeColor(String type) {
    switch (type) {
      case 'asset':
        return const Color(0xFF00B894);
      case 'liability':
        return const Color(0xFFFD79A8);
      case 'equity':
        return const Color(0xFFA29BFE);
      case 'revenue':
        return const Color(0xFF74B9FF);
      case 'expense':
        return const Color(0xFFE17055);
      default:
        return _textSec;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'asset':
        return Icons.account_balance_rounded;
      case 'liability':
        return Icons.credit_card_rounded;
      case 'equity':
        return Icons.pie_chart_rounded;
      case 'revenue':
        return Icons.trending_up_rounded;
      case 'expense':
        return Icons.trending_down_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  void _showCreateDialog() {
    final codeC = TextEditingController(),
        nameC = TextEditingController(),
        descC = TextEditingController();
    String type = 'asset';
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
                  backgroundColor: _cardBg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Create Account',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  content: SizedBox(
                      width: 450,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _field(codeC, 'Account Code', Icons.tag_rounded),
                        const SizedBox(height: 12),
                        _field(nameC, 'Account Name', Icons.label_rounded),
                        const SizedBox(height: 12),
                        _field(descC, 'Description', Icons.description_rounded),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          dropdownColor: _cardBg,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF16213E),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              labelText: 'Account Type',
                              labelStyle: const TextStyle(color: _textSec)),
                          items: [
                            'asset',
                            'liability',
                            'equity',
                            'revenue',
                            'expense'
                          ]
                              .map((t) => DropdownMenuItem(
                                  value: t, child: Text(t.toUpperCase())))
                              .toList(),
                          onChanged: (v) => setS(() => type = v!),
                        ),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel',
                            style: TextStyle(color: _textSec))),
                    ElevatedButton(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: _primary),
                      onPressed: () async {
                        if (codeC.text.isEmpty || nameC.text.isEmpty) return;
                        await _service.createAccount({
                          'account_code': codeC.text.trim(),
                          'account_name': nameC.text.trim(),
                          'description': descC.text.trim(),
                          'account_type': type,
                          'normal_balance':
                              (type == 'asset' || type == 'expense')
                                  ? 'debit'
                                  : 'credit'
                        });
                        Navigator.pop(ctx);
                        _load();
                      },
                      child: const Text('Create',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                )));
  }

  Widget _field(TextEditingController c, String label, IconData icon) =>
      TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF16213E),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            labelText: label,
            labelStyle: const TextStyle(color: _textSec),
            prefixIcon: Icon(icon, color: _textSec, size: 20)),
      );

  @override
  Widget build(BuildContext context) {
    // Group by type
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var a in _filtered) {
      final t = a['account_type'] as String? ?? 'other';
      grouped.putIfAbsent(t, () => []).add(a);
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Chart of Accounts',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/accountant-dashboard')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Account',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Assets', 'asset'),
                const SizedBox(width: 8),
                _filterChip('Liabilities', 'liability'),
                const SizedBox(width: 8),
                _filterChip('Equity', 'equity'),
                const SizedBox(width: 8),
                _filterChip('Revenue', 'revenue'),
                const SizedBox(width: 8),
                _filterChip('Expenses', 'expense'),
              ])),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  children: grouped.entries
                      .map((e) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(children: [
                                    Icon(_typeIcon(e.key),
                                        color: _typeColor(e.key), size: 18),
                                    const SizedBox(width: 8),
                                    Text(e.key.toUpperCase(),
                                        style: TextStyle(
                                            color: _typeColor(e.key),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Divider(
                                            color: _typeColor(e.key)
                                                .withOpacity(0.2))),
                                  ]),
                                ),
                                ...e.value.map((a) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: _cardBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: const Color(0xFF2D2D44))),
                                      child: Row(children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                              color: _typeColor(e.key)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Center(
                                              child: Text(
                                                  a['account_code'] ?? '',
                                                  style: TextStyle(
                                                      color: _typeColor(e.key),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800))),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(a['account_name'] ?? '',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              if (a['description'] != null)
                                                Text(a['description'],
                                                    style: const TextStyle(
                                                        color: _textSec,
                                                        fontSize: 11)),
                                            ])),
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  '₹${((a['current_balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              Text(
                                                  a['normal_balance'] ??
                                                      'debit',
                                                  style: TextStyle(
                                                      color: _typeColor(e.key),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ]),
                                      ]),
                                    )),
                              ]))
                      .toList(),
                ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _filterType == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: sel ? _primary : _cardBg,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: sel ? _primary : const Color(0xFF2D2D44))),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : _textSec,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
