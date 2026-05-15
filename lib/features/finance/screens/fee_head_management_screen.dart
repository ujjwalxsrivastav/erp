import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/finance_service.dart';

class FeeHeadManagementScreen extends StatefulWidget {
  const FeeHeadManagementScreen({super.key});
  @override
  State<FeeHeadManagementScreen> createState() =>
      _FeeHeadManagementScreenState();
}

class _FeeHeadManagementScreenState extends State<FeeHeadManagementScreen> {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _feeHeads = [];
  String _searchQuery = '';

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
    _feeHeads = await _service.getFeeHeads();
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filtered => _searchQuery.isEmpty
      ? _feeHeads
      : _feeHeads
          .where((h) =>
              (h['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (h['code'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();

  void _showCreateDialog() {
    final codeC = TextEditingController(),
        nameC = TextEditingController(),
        descC = TextEditingController();
    String category = 'academic';
    bool refundable = false,
        taxable = false,
        scholarshipApp = true,
        fineApp = true;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
                  backgroundColor: _cardBg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Create Fee Head',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        _dialogField(
                            codeC, 'Code (e.g. TUI)', Icons.code_rounded),
                        const SizedBox(height: 12),
                        _dialogField(nameC, 'Name (e.g. Tuition Fee)',
                            Icons.label_rounded),
                        const SizedBox(height: 12),
                        _dialogField(
                            descC, 'Description', Icons.description_rounded),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          dropdownColor: _cardBg,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF16213E),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              labelText: 'Category',
                              labelStyle: const TextStyle(color: _textSec)),
                          items: [
                            'academic',
                            'hostel',
                            'transport',
                            'exam',
                            'misc'
                          ]
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c.toUpperCase())))
                              .toList(),
                          onChanged: (v) => setS(() => category = v!),
                        ),
                        const SizedBox(height: 16),
                        _switchRow('Refundable', refundable,
                            (v) => setS(() => refundable = v)),
                        _switchRow('Taxable (GST)', taxable,
                            (v) => setS(() => taxable = v)),
                        _switchRow('Scholarship Applicable', scholarshipApp,
                            (v) => setS(() => scholarshipApp = v)),
                        _switchRow('Late Fine Applicable', fineApp,
                            (v) => setS(() => fineApp = v)),
                      ]))),
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
                        await _service.createFeeHead({
                          'code': codeC.text.trim().toUpperCase(),
                          'name': nameC.text.trim(),
                          'description': descC.text.trim(),
                          'category': category,
                          'is_refundable': refundable,
                          'is_taxable': taxable,
                          'scholarship_applicable': scholarshipApp,
                          'late_fine_applicable': fineApp,
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

  Widget _dialogField(TextEditingController c, String label, IconData icon) =>
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

  Widget _switchRow(String label, bool val, Function(bool) onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: _textSec, fontSize: 13))),
          Switch(value: val, onChanged: onChanged, activeThumbColor: _primary),
        ]),
      );

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'hostel':
        return const Color(0xFFFD79A8);
      case 'transport':
        return const Color(0xFF74B9FF);
      case 'exam':
        return const Color(0xFFFDCB6E);
      case 'misc':
        return const Color(0xFFE17055);
      default:
        return const Color(0xFF00B894);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Fee Head Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/accountant-dashboard')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Fee Head',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        // Search bar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2D2D44))),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                hintText: 'Search fee heads...',
                hintStyle: TextStyle(color: _textSec),
                prefixIcon: Icon(Icons.search_rounded, color: _textSec),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          ),
        ),
        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _statChip('Total', _feeHeads.length, _primary),
            const SizedBox(width: 8),
            _statChip(
                'Active',
                _feeHeads.where((h) => h['is_active'] == true).length,
                const Color(0xFF00B894)),
            const SizedBox(width: 8),
            _statChip(
                'Refundable',
                _feeHeads.where((h) => h['is_refundable'] == true).length,
                const Color(0xFF74B9FF)),
          ]),
        ),
        const SizedBox(height: 12),
        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('No fee heads found',
                          style: TextStyle(color: _textSec)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final h = _filtered[i];
                        final cat = (h['category'] ?? 'academic') as String;
                        final cc = _categoryColor(cat);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFF2D2D44))),
                          child: Row(children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  color: cc.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Center(
                                  child: Text(h['code'] ?? '??',
                                      style: TextStyle(
                                          color: cc,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(h['name'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    _tag(cat.toUpperCase(), cc),
                                    if (h['is_refundable'] == true) ...[
                                      const SizedBox(width: 6),
                                      _tag(
                                          'REFUNDABLE', const Color(0xFF74B9FF))
                                    ],
                                    if (h['is_taxable'] == true) ...[
                                      const SizedBox(width: 6),
                                      _tag('GST', const Color(0xFFFDCB6E))
                                    ],
                                  ]),
                                ])),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: h['is_active'] == true
                                    ? const Color(0xFF00B894).withOpacity(0.15)
                                    : const Color(0xFFEF4444).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                  h['is_active'] == true
                                      ? 'Active'
                                      : 'Inactive',
                                  style: TextStyle(
                                      color: h['is_active'] == true
                                          ? const Color(0xFF00B894)
                                          : const Color(0xFFEF4444),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _statChip(String label, int count, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withOpacity(0.2))),
        child: Row(children: [
          Text('$count',
              style: TextStyle(
                  color: c, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: c.withOpacity(0.8), fontSize: 12)),
        ]),
      );

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(t,
            style: TextStyle(
                color: c,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}
