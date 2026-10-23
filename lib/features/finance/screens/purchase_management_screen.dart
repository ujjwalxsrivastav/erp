import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/finance_extension_service.dart';

/// Purchase Management — full Purchase-to-Pay in one screen:
/// Tab 1 Indents (raise + approve), Tab 2 Purchase Orders (create PO
/// against an indent, GRN entry), Tab 3 Vendor Bills (book bill after
/// 3-way match PO = GRN = Bill, mark paid).
class PurchaseManagementScreen extends StatefulWidget {
  const PurchaseManagementScreen({super.key});

  @override
  State<PurchaseManagementScreen> createState() =>
      _PurchaseManagementScreenState();
}

class _PurchaseManagementScreenState extends State<PurchaseManagementScreen>
    with SingleTickerProviderStateMixin {
  final _service = FinanceExtensionService();
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _indents = [];
  List<Map<String, dynamic>> _pos = [];
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _vendors = [];

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _cardBg2 = Color(0xFF16213E);
  static const _primary = Color(0xFF6C5CE7);
  static const _accent = Color(0xFF00CEC9);
  static const _textSec = Color(0xFF9CA3AF);
  static const _ok = Color(0xFF00B894);
  static const _warn = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);
  static const _info = Color(0xFF74B9FF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Rebuild so the FAB label/action follows the active tab.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getIndents(),
      _service.getPOs(),
      _service.getBills(),
      _service.getVendors(),
    ]);
    if (mounted) {
      setState(() {
        _indents = results[0];
        _pos = results[1];
        _bills = results[2];
        _vendors = results[3];
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic v) {
    final n = (v is num) ? v.toDouble() : 0.0;
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)} Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(2)} L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _danger : _ok,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'raised':
      case 'draft':
      case 'booked':
        return _info;
      case 'hod_approved':
      case 'approved':
      case 'sent':
        return _warn;
      case 'store_issued':
      case 'po_raised':
      case 'received':
      case 'paid':
      case 'closed':
        return _ok;
      case 'rejected':
      case 'cancelled':
      case 'on_hold':
        return _danger;
      default:
        return _textSec;
    }
  }

  // ---------------------------------------------------------------
  // Shared form widgets (same style as chart_of_accounts_screen)
  // ---------------------------------------------------------------
  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard, String? Function(String?)? validator,
      int maxLines = 1}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: _cardBg2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        labelText: label,
        labelStyle: const TextStyle(color: _textSec),
        prefixIcon: Icon(icon, color: _textSec, size: 20),
      ),
    );
  }

  InputDecoration _dropDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: _cardBg2,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      labelText: label,
      labelStyle: const TextStyle(color: _textSec),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _amount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
    return null;
  }

  // ---------------------------------------------------------------
  // INDENT DIALOG
  // ---------------------------------------------------------------
  void _showRaiseIndentDialog() {
    final formKey = GlobalKey<FormState>();
    final deptC = TextEditingController();
    final itemC = TextEditingController();
    final specC = TextEditingController();
    final qtyC = TextEditingController(text: '1');
    final costC = TextEditingController();
    final justC = TextEditingController();
    final headC = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Raise Purchase Indent',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _field(deptC, 'Department', Icons.domain_rounded,
                      validator: _required),
                  const SizedBox(height: 12),
                  _field(itemC, 'Item Name', Icons.inventory_2_rounded,
                      validator: _required),
                  const SizedBox(height: 12),
                  _field(specC, 'Specification', Icons.description_rounded),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _field(qtyC, 'Quantity', Icons.numbers_rounded,
                            keyboard: TextInputType.number,
                            validator: _amount)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(
                            costC, 'Estimated Cost (₹)', Icons.currency_rupee_rounded,
                            keyboard: TextInputType.number,
                            validator: _amount)),
                  ]),
                  const SizedBox(height: 12),
                  _field(headC, 'Budget Head', Icons.account_balance_wallet_rounded),
                  const SizedBox(height: 12),
                  _field(justC, 'Justification', Icons.notes_rounded,
                      maxLines: 2),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: _textSec))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => saving = true);
                      final ok = await _service.createIndent({
                        'department': deptC.text.trim(),
                        'item_name': itemC.text.trim(),
                        'specification': specC.text.trim(),
                        'quantity': double.tryParse(qtyC.text.trim()) ?? 1,
                        'estimated_cost':
                            double.tryParse(costC.text.trim()) ?? 0,
                        'justification': justC.text.trim(),
                        'budget_head': headC.text.trim(),
                        'raised_by': 'accountant',
                      });
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _toast(ok
                          ? 'Indent raised successfully'
                          : 'Failed to raise indent — check SQL is run',
                          error: !ok);
                      if (ok) _load();
                    },
              child: const Text('Raise Indent',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeIndentStatus(
      Map<String, dynamic> indent, String status) async {
    final ok = await _service.updateIndentStatus(
      indent['id'].toString(),
      status,
      approvedBy: status == 'hod_approved' ? 'accountant' : null,
    );
    _toast(ok ? 'Indent marked $status' : 'Status update failed',
        error: !ok);
    if (ok) _load();
  }

  // ---------------------------------------------------------------
  // PO DIALOG
  // ---------------------------------------------------------------
  void _showCreatePODialog() {
    final openIndents = _indents
        .where((i) => i['status'] != 'closed' && i['status'] != 'rejected')
        .toList();
    if (openIndents.isEmpty) {
      _toast('Raise an indent first — PO must link to an open indent',
          error: true);
      return;
    }
    final formKey = GlobalKey<FormState>();
    final vendorNameC = TextEditingController();
    final qtyC = TextEditingController(text: '1');
    final rateC = TextEditingController();
    final gstC = TextEditingController(text: '0');
    String? indentId = openIndents.first['id'].toString();
    String? vendorId;
    bool saving = false;

    Map<String, dynamic> selectedIndent() =>
        openIndents.firstWhere((i) => i['id'].toString() == indentId,
            orElse: () => openIndents.first);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Purchase Order',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: indentId,
                    dropdownColor: _cardBg,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dropDecoration('Indent'),
                    items: openIndents
                        .map((i) => DropdownMenuItem(
                              value: i['id'].toString(),
                              child: Text(
                                  '${i['indent_no'] ?? ''} — ${i['item_name'] ?? ''}'),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => indentId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: vendorId,
                    dropdownColor: _cardBg,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dropDecoration('Vendor (registered)'),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('— Unregistered vendor —')),
                      ..._vendors.map((v) => DropdownMenuItem<String>(
                            value: v['id'].toString(),
                            child: Text((v['name'] as String?) ?? ''),
                          )),
                    ],
                    onChanged: (v) {
                      setS(() {
                        vendorId = v;
                        if (v != null) {
                          final vend = _vendors.firstWhere(
                              (x) => x['id'].toString() == v,
                              orElse: () => {});
                          vendorNameC.text =
                              (vend['name'] as String?) ?? vendorNameC.text;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(vendorNameC, 'Vendor Name', Icons.store_rounded,
                      validator: _required),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _field(qtyC, 'Quantity', Icons.numbers_rounded,
                            keyboard: TextInputType.number,
                            validator: _amount)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(rateC, 'Rate (₹)', Icons.currency_rupee_rounded,
                            keyboard: TextInputType.number,
                            validator: _amount)),
                  ]),
                  const SizedBox(height: 12),
                  _field(gstC, 'GST Amount (₹)', Icons.percent_rounded,
                      keyboard: TextInputType.number, validator: _amount),
                  const SizedBox(height: 8),
                  const Text(
                    'Line item is taken from the selected indent; total = quantity × rate.',
                    style: TextStyle(color: _textSec, fontSize: 11),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: _textSec))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => saving = true);
                      final ind = selectedIndent();
                      final qty = double.tryParse(qtyC.text.trim()) ?? 0;
                      final rate = double.tryParse(rateC.text.trim()) ?? 0;
                      final total = qty * rate;
                      final ok = await _service.createPO({
                        'indent_id': indentId,
                        'vendor_id': vendorId,
                        'vendor_name': vendorNameC.text.trim(),
                        'items': [
                          {
                            'item_name': ind['item_name'],
                            'specification': ind['specification'],
                            'quantity': qty,
                            'rate': rate,
                            'amount': total,
                          }
                        ],
                        'total_amount': total,
                        'gst_amount': double.tryParse(gstC.text.trim()) ?? 0,
                        'created_by': 'accountant',
                      });
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _toast(ok ? 'Purchase order created (draft)' : 'PO creation failed',
                          error: !ok);
                      if (ok) _load();
                    },
              child: const Text('Create PO',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // GRN DIALOG (against a PO)
  // ---------------------------------------------------------------
  void _showGRNDialog(Map<String, dynamic> po) {
    final formKey = GlobalKey<FormState>();
    final qtyC = TextEditingController();
    final byC = TextEditingController();
    final remarksC = TextEditingController();
    String inspection = 'accepted';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Goods Receipt — ${po['po_no'] ?? ''}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(qtyC, 'Received Quantity', Icons.numbers_rounded,
                    keyboard: TextInputType.number, validator: _amount),
                const SizedBox(height: 12),
                _field(byC, 'Received By', Icons.person_rounded,
                    validator: _required),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: inspection,
                  dropdownColor: _cardBg,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dropDecoration('Inspection'),
                  items: const [
                    DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                    DropdownMenuItem(
                        value: 'partially_rejected',
                        child: Text('Partially Rejected')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (v) => setS(() => inspection = v ?? 'accepted'),
                ),
                const SizedBox(height: 12),
                _field(remarksC, 'Remarks', Icons.notes_rounded),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: _textSec))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => saving = true);
                      final ok = await _service.createGRN({
                        'po_id': po['id'],
                        'received_quantity':
                            double.tryParse(qtyC.text.trim()) ?? 0,
                        'received_by': byC.text.trim(),
                        'inspection_status': inspection,
                        'remarks': remarksC.text.trim(),
                      });
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _toast(ok ? 'GRN recorded — PO status updated' : 'GRN failed',
                          error: !ok);
                      if (ok) _load();
                    },
              child: const Text('Save GRN',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // BILL DIALOG
  // ---------------------------------------------------------------
  void _showBookBillDialog() {
    if (_pos.isEmpty) {
      _toast('No purchase orders — create a PO first', error: true);
      return;
    }
    final formKey = GlobalKey<FormState>();
    final billNoC = TextEditingController();
    final amountC = TextEditingController();
    final tdsC = TextEditingController(text: '0');
    String? poId = _pos.first['id'].toString();
    bool saving = false;

    Map<String, dynamic> selectedPO() => _pos.firstWhere(
        (p) => p['id'].toString() == poId,
        orElse: () => _pos.first);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Book Vendor Bill',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: poId,
                  dropdownColor: _cardBg,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dropDecoration('Purchase Order'),
                  items: _pos
                      .map((p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(
                                '${p['po_no'] ?? ''} — ${p['vendor_name'] ?? ''}'),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => poId = v),
                ),
                const SizedBox(height: 12),
                _field(billNoC, 'Bill / Invoice No', Icons.receipt_rounded,
                    validator: _required),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _field(
                          amountC, 'Bill Amount (₹)', Icons.currency_rupee_rounded,
                          keyboard: TextInputType.number, validator: _amount)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field(tdsC, 'TDS (₹)', Icons.percent_rounded,
                          keyboard: TextInputType.number, validator: _amount)),
                ]),
                const SizedBox(height: 8),
                const Text('Payable = Bill Amount − TDS (auto-calculated)',
                    style: TextStyle(color: _textSec, fontSize: 11)),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: _textSec))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => saving = true);
                      final po = selectedPO();
                      final amt = double.tryParse(amountC.text.trim()) ?? 0;
                      final tds = double.tryParse(tdsC.text.trim()) ?? 0;
                      final ok = await _service.bookBill({
                        'po_id': poId,
                        'vendor_name': po['vendor_name'],
                        'bill_no': billNoC.text.trim(),
                        'bill_amount': amt,
                        'tds_amount': tds,
                        'payable_amount': amt - tds,
                        'created_by': 'accountant',
                      });
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _toast(ok ? 'Bill booked successfully' : 'Bill booking failed',
                          error: !ok);
                      if (ok) _load();
                    },
              child: const Text('Book Bill',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Purchase-to-Pay',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/accountant-dashboard'),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: Colors.white,
          unselectedLabelColor: _textSec,
          tabs: [
            Tab(text: 'Indents (${_indents.length})'),
            Tab(text: 'Purchase Orders (${_pos.length})'),
            Tab(text: 'Bills (${_bills.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabController.index == 0
              ? 'Raise Indent'
              : _tabController.index == 1
                  ? 'Create PO'
                  : 'Book Bill',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showRaiseIndentDialog();
          } else if (_tabController.index == 1) {
            _showCreatePODialog();
          } else {
            _showBookBillDialog();
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildIndentsTab(),
                _buildPOsTab(),
                _buildBillsTab(),
              ],
            ),
    );
  }

  Widget _emptyState(IconData icon, String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _textSec, size: 44),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSec, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _statusChip(String? status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text((status ?? '').replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  // ---------------------------------------------------------------
  // TAB 1 — INDENTS
  // ---------------------------------------------------------------
  Widget _buildIndentsTab() {
    if (_indents.isEmpty) {
      return _emptyState(Icons.request_quote_rounded, 'No indents yet',
          'Raise the first purchase indent using the button below.');
    }
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _indents.length,
        itemBuilder: (ctx, i) {
          final ind = _indents[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              color: _cardBg,
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            '${ind['indent_no'] ?? ''} • ${ind['item_name'] ?? ''}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      _statusChip(ind['status'] as String?),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '${ind['department'] ?? ''} • Qty: ${ind['quantity'] ?? ''} • Est: ${_formatCurrency(ind['estimated_cost'])}',
                      style: const TextStyle(color: _textSec, fontSize: 12),
                    ),
                    if ((ind['justification'] as String?)?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(ind['justification'],
                            style: const TextStyle(
                                color: _textSec, fontSize: 12)),
                      ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (ind['status'] == 'raised') ...[
                        _actionBtn('Approve (HOD)', _ok,
                            () => _changeIndentStatus(ind, 'hod_approved')),
                        _actionBtn('Reject', _danger,
                            () => _changeIndentStatus(ind, 'rejected')),
                      ],
                      if (ind['status'] == 'hod_approved') ...[
                        _actionBtn('Issue from Store', _info,
                            () => _changeIndentStatus(ind, 'store_issued')),
                        _actionBtn('Send to Purchase', _warn,
                            () => _changeIndentStatus(ind, 'purchase_pending')),
                      ],
                      if (ind['status'] == 'store_issued')
                        _actionBtn('Close', _ok,
                            () => _changeIndentStatus(ind, 'closed')),
                    ]),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // TAB 2 — PURCHASE ORDERS
  // ---------------------------------------------------------------
  Widget _buildPOsTab() {
    if (_pos.isEmpty) {
      return _emptyState(Icons.shopping_cart_rounded, 'No purchase orders',
          'Create a PO against an approved indent.');
    }
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _pos.length,
        itemBuilder: (ctx, i) {
          final po = _pos[i];
          final items = (po['items'] is List) ? (po['items'] as List) : [];
          final firstItem = items.isNotEmpty && items.first is Map
              ? items.first as Map
              : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              color: _cardBg,
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            '${po['po_no'] ?? ''} • ${po['vendor_name'] ?? 'Vendor'}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      _statusChip(po['status'] as String?),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Total: ${_formatCurrency(po['total_amount'])} • GST: ${_formatCurrency(po['gst_amount'])}'
                      '${firstItem != null ? ' • Item: ${firstItem['item_name'] ?? ''} × ${firstItem['quantity'] ?? ''}' : ''}',
                      style: const TextStyle(color: _textSec, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (po['status'] == 'draft')
                        _actionBtn('Approve PO', _ok, () async {
                          final ok = await _service.updatePOStatus(
                              po['id'].toString(), 'approved',
                              approvedBy: 'accountant');
                          _toast(ok ? 'PO approved' : 'Failed', error: !ok);
                          if (ok) _load();
                        }),
                      if (po['status'] == 'approved')
                        _actionBtn('Mark Sent', _info, () async {
                          final ok = await _service
                              .updatePOStatus(po['id'].toString(), 'sent');
                          _toast(ok ? 'PO marked sent' : 'Failed', error: !ok);
                          if (ok) _load();
                        }),
                      if (po['status'] == 'approved' ||
                          po['status'] == 'sent' ||
                          po['status'] == 'partially_received')
                        _actionBtn('Enter GRN', _warn, () => _showGRNDialog(po)),
                      if (po['status'] != 'cancelled' &&
                          po['status'] != 'received')
                        _actionBtn('Cancel', _danger, () async {
                          final ok = await _service
                              .updatePOStatus(po['id'].toString(), 'cancelled');
                          _toast(ok ? 'PO cancelled' : 'Failed', error: !ok);
                          if (ok) _load();
                        }),
                    ]),
                  ]),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // TAB 3 — VENDOR BILLS
  // ---------------------------------------------------------------
  Widget _buildBillsTab() {
    if (_bills.isEmpty) {
      return _emptyState(Icons.receipt_long_rounded, 'No bills booked',
          'Book a vendor bill after goods are received (GRN).');
    }
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _bills.length,
        itemBuilder: (ctx, i) {
          final bill = _bills[i];
          final po = _pos.firstWhere((p) => p['id'] == bill['po_id'],
              orElse: () => {});
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              color: _cardBg,
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            'Bill ${bill['bill_no'] ?? ''} • ${bill['vendor_name'] ?? ''}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      _statusChip(bill['status'] as String?),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '${po.isNotEmpty ? 'PO: ${po['po_no']} • ' : ''}Amount: ${_formatCurrency(bill['bill_amount'])} • TDS: ${_formatCurrency(bill['tds_amount'])} • Payable: ${_formatCurrency(bill['payable_amount'])}',
                      style: const TextStyle(color: _textSec, fontSize: 12),
                    ),
                    if (bill['status'] != 'paid') ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (bill['status'] == 'booked')
                          _actionBtn('Approve Bill', _ok, () async {
                            final ok = await _service.updateBillStatus(
                                bill['id'].toString(), 'approved');
                            _toast(ok ? 'Bill approved' : 'Failed',
                                error: !ok);
                            if (ok) _load();
                          }),
                        if (bill['status'] == 'booked' ||
                            bill['status'] == 'approved')
                          _actionBtn('Mark Paid', _accent, () async {
                            final ok = await _service.updateBillStatus(
                                bill['id'].toString(), 'paid');
                            _toast(ok ? 'Bill marked paid' : 'Failed',
                                error: !ok);
                            if (ok) _load();
                          }),
                        if (bill['status'] != 'on_hold')
                          _actionBtn('Put On Hold', _danger, () async {
                            final ok = await _service.updateBillStatus(
                                bill['id'].toString(), 'on_hold');
                            _toast(ok ? 'Bill put on hold' : 'Failed',
                                error: !ok);
                            if (ok) _load();
                          }),
                      ]),
                    ],
                  ]),
            ),
          );
        },
      ),
    );
  }
}
