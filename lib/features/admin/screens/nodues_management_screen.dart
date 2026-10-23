import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/admin_workflow_service.dart';

/// Admin centre for No-Dues clearance: opens a case for a student,
/// tracks the 9 department clearances and auto-completes the case
/// when every department has cleared.
class NoDuesManagementScreen extends StatefulWidget {
  const NoDuesManagementScreen({super.key});

  @override
  State<NoDuesManagementScreen> createState() =>
      _NoDuesManagementScreenState();
}

class _NoDuesManagementScreenState extends State<NoDuesManagementScreen> {
  final _service = AdminWorkflowService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _statusFilter = 'all';

  static const _statusFilters = [
    'all',
    'pending',
    'in_progress',
    'cleared',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final requests = await _service.getNoDuesRequests();
    if (mounted) {
      setState(() {
        _requests = requests;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered => _statusFilter == 'all'
      ? _requests
      : _requests.where((r) => r['status'] == _statusFilter).toList();

  int _countByStatus(List<String> statuses) =>
      _requests.where((r) => statuses.contains(r['status'])).length;

  String _label(String value) => value
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _statusColor(String status) {
    switch (status) {
      case 'cleared':
      case 'clear':
        return AppTheme.success;
      case 'in_progress':
        return AppTheme.info;
      case 'due':
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: AppTheme.caption.copyWith(color: color),
      ),
    );
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Future<void> _showInitiateDialog() async {
    final formKey = GlobalKey<FormState>();
    final studentCtrl = TextEditingController();
    String reason = AdminWorkflowService.noDuesReasons.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Text('Initiate No-Dues'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: studentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student ID (username)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Student ID is required'
                      : null,
                ),
                const SizedBox(height: AppTheme.md),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: AdminWorkflowService.noDuesReasons
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(_label(r)),
                          ))
                      .toList(),
                  onChanged: (v) => setInner(() => reason = v ?? reason),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                foregroundColor: AppTheme.white,
              ),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final created = await _service.initiateNoDues(
                    studentCtrl.text.trim(), reason);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(created != null
                          ? 'No-Dues case opened for ${studentCtrl.text.trim()}'
                          : 'Failed to open No-Dues case'),
                      backgroundColor:
                          created != null ? AppTheme.success : AppTheme.error,
                    ),
                  );
                  if (created != null) _loadData();
                }
              },
              child: const Text('Initiate'),
            ),
          ],
        ),
      ),
    );
    studentCtrl.dispose();
  }

  Future<void> _openDetail(Map<String, dynamic> request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoDuesDetailScreen(request: request),
      ),
    );
    if (mounted) _loadData();
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(AppTheme.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppTheme.sm),
            Text(value, style: AppTheme.h3.copyWith(color: AppTheme.dark)),
            Text(title,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ---- Gradient header ----
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppTheme.adminGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.sm, AppTheme.md, AppTheme.lg, AppTheme.lg),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: AppTheme.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppTheme.sm),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No-Dues Management',
                              style: TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          Text('Department clearance tracker',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.white),
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- Body ----
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.adminPrimary))
                : RefreshIndicator(
                    color: AppTheme.adminPrimary,
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(AppTheme.lg),
                      children: [
                        Row(
                          children: [
                            _statCard(
                                'Pending',
                                '${_countByStatus(['pending', 'in_progress'])}',
                                Icons.hourglass_top,
                                AppTheme.warning),
                            const SizedBox(width: AppTheme.md),
                            _statCard('Cleared', '${_countByStatus(['cleared'])}',
                                Icons.verified, AppTheme.success),
                            const SizedBox(width: AppTheme.md),
                            _statCard('Total Cases', '${_requests.length}',
                                Icons.folder_open, AppTheme.adminPrimary),
                          ],
                        ),
                        const SizedBox(height: AppTheme.lg),
                        GradientButton(
                          text: 'Initiate No-Dues',
                          icon: Icons.add_circle_outline,
                          gradient: AppTheme.adminGradient,
                          onPressed: _showInitiateDialog,
                        ),
                        const SizedBox(height: AppTheme.lg),
                        // Status filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _statusFilters.map((s) {
                              final selected = _statusFilter == s;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: AppTheme.sm),
                                child: ChoiceChip(
                                  label: Text(_label(s)),
                                  selected: selected,
                                  selectedColor:
                                      AppTheme.adminPrimary.withOpacity(0.15),
                                  onSelected: (_) =>
                                      setState(() => _statusFilter = s),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: AppTheme.md),
                        if (_filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: Column(
                              children: [
                                Icon(Icons.assignment_turned_in_outlined,
                                    size: 56, color: AppTheme.lightGray),
                                const SizedBox(height: AppTheme.md),
                                Text('No No-Dues requests found',
                                    style: AppTheme.bodyLarge
                                        .copyWith(color: AppTheme.mediumGray)),
                              ],
                            ),
                          )
                        else
                          ..._filtered.map((r) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppTheme.md),
                                child: GlassCard(
                                  onTap: () => _openDetail(r),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.adminPrimary
                                            .withOpacity(0.12),
                                        child: const Icon(
                                            Icons.person_outline,
                                            color: AppTheme.adminPrimary),
                                      ),
                                      const SizedBox(width: AppTheme.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r['student_id']?.toString() ?? '-',
                                              style: AppTheme.h5.copyWith(
                                                  color: AppTheme.dark),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_label(r['reason']?.toString() ?? '')} • ${_fmtDate(r['requested_at'] ?? r['created_at'])}',
                                              style: AppTheme.bodySmall.copyWith(
                                                  color: AppTheme.mediumGray),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _chip(
                                          _label(r['status']?.toString() ??
                                              'pending'),
                                          _statusColor(
                                              r['status']?.toString() ??
                                                  'pending')),
                                      const Icon(Icons.chevron_right,
                                          color: AppTheme.lightGray),
                                    ],
                                  ),
                                ),
                              )),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Detail page for one No-Dues request: lists the 9 department
/// clearances with Clear / Mark Due actions.
class _NoDuesDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const _NoDuesDetailScreen({required this.request});

  @override
  State<_NoDuesDetailScreen> createState() => _NoDuesDetailScreenState();
}

class _NoDuesDetailScreenState extends State<_NoDuesDetailScreen> {
  final _service = AdminWorkflowService();
  List<Map<String, dynamic>> _clearances = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClearances();
  }

  Future<void> _loadClearances() async {
    setState(() => _loading = true);
    final rows =
        await _service.getClearances(widget.request['id'] as String);
    if (mounted) {
      setState(() {
        _clearances = rows;
        _loading = false;
      });
    }
  }

  String _label(String value) => value
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _statusColor(String status) {
    switch (status) {
      case 'clear':
        return AppTheme.success;
      case 'due':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Future<void> _markClear(Map<String, dynamic> clearance) async {
    final ok = await _service.updateClearance(
      id: clearance['id'] as String,
      status: 'clear',
      dueAmount: 0,
      clearedBy: 'admin',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '${_label(clearance['department'] as String)} cleared'
            : 'Failed to update clearance'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ),
    );
    if (ok) _loadClearances();
  }

  Future<void> _showMarkDueDialog(Map<String, dynamic> clearance) async {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(
        text: ((clearance['due_amount'] as num?)?.toDouble() ?? 0) > 0
            ? clearance['due_amount'].toString()
            : '');
    final remarkCtrl =
        TextEditingController(text: clearance['remarks']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text('Mark Due — ${_label(clearance['department'] as String)}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Due Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.md),
              TextFormField(
                controller: remarkCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Remark is required for a due'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: AppTheme.white,
            ),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final ok = await _service.updateClearance(
                id: clearance['id'] as String,
                status: 'due',
                dueAmount: double.parse(amountCtrl.text.trim()),
                remarks: remarkCtrl.text.trim(),
                clearedBy: 'admin',
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(ok ? 'Due marked' : 'Failed to mark due'),
                    backgroundColor: ok ? AppTheme.success : AppTheme.error,
                  ),
                );
                if (ok) _loadClearances();
              }
            },
            child: const Text('Mark Due'),
          ),
        ],
      ),
    );
    amountCtrl.dispose();
    remarkCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clearedCount =
        _clearances.where((c) => c['status'] == 'clear').length;
    final allClear =
        _clearances.isNotEmpty && clearedCount == _clearances.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppTheme.adminGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.sm, AppTheme.md, AppTheme.lg, AppTheme.lg),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: AppTheme.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppTheme.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.request['student_id']?.toString() ?? '-',
                              style: const TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              'No-Dues • ${_label(widget.request['reason']?.toString() ?? '')}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.adminPrimary))
                : ListView(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    children: [
                      GlassCard(
                        color: allClear
                            ? AppTheme.success.withOpacity(0.08)
                            : null,
                        child: Row(
                          children: [
                            Icon(
                              allClear
                                  ? Icons.verified
                                  : Icons.hourglass_top,
                              color: allClear
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                            const SizedBox(width: AppTheme.md),
                            Expanded(
                              child: Text(
                                allClear
                                    ? 'All departments cleared — No-Dues complete'
                                    : '$clearedCount of ${_clearances.length} departments cleared',
                                style: AppTheme.h5.copyWith(
                                  color: allClear
                                      ? AppTheme.success
                                      : AppTheme.dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.lg),
                      ..._clearances.map((c) {
                        final status = c['status']?.toString() ?? 'pending';
                        final due =
                            (c['due_amount'] as num?)?.toDouble() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.md),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _label(c['department'] as String),
                                        style: AppTheme.h5
                                            .copyWith(color: AppTheme.dark),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusFull),
                                        border: Border.all(
                                            color: _statusColor(status)
                                                .withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        _label(status),
                                        style: AppTheme.caption.copyWith(
                                            color: _statusColor(status)),
                                      ),
                                    ),
                                  ],
                                ),
                                if (due > 0)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: AppTheme.sm),
                                    child: Text('Due: ₹${due.toStringAsFixed(2)}',
                                        style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.error,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                if ((c['remarks']?.toString() ?? '').isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: AppTheme.sm),
                                    child: Text(c['remarks'].toString(),
                                        style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.mediumGray)),
                                  ),
                                const SizedBox(height: AppTheme.md),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.success,
                                          foregroundColor: AppTheme.white,
                                        ),
                                        onPressed: status == 'clear'
                                            ? null
                                            : () => _markClear(c),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Clear'),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.md),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.error,
                                          side: const BorderSide(
                                              color: AppTheme.error),
                                        ),
                                        onPressed: () => _showMarkDueDialog(c),
                                        icon: const Icon(
                                            Icons.warning_amber, size: 18),
                                        label: const Text('Mark Due'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
