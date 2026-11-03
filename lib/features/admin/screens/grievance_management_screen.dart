import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/admin_workflow_service.dart';

/// Central Grievance centre for Admin: all categories (including the
/// UGC-mandated ragging / ICC / SC-ST cells) with assignment,
/// resolution and SLA-overdue tracking.
class GrievanceManagementScreen extends StatefulWidget {
  const GrievanceManagementScreen({super.key});

  @override
  State<GrievanceManagementScreen> createState() =>
      _GrievanceManagementScreenState();
}

class _GrievanceManagementScreenState extends State<GrievanceManagementScreen> {
  final _service = AdminWorkflowService();
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String _statusFilter = 'all';
  String _categoryFilter = 'all';

  static const _statusFilters = [
    'all',
    'open',
    'in_progress',
    'escalated',
    'resolved',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final tickets = await _service.getGrievances();
    final stats = await _service.getDashboardStats();
    if (mounted) {
      setState(() {
        _tickets = tickets;
        _stats = stats;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered => _tickets.where((t) {
        final statusOk =
            _statusFilter == 'all' || t['status'] == _statusFilter;
        final categoryOk =
            _categoryFilter == 'all' || t['category'] == _categoryFilter;
        return statusOk && categoryOk;
      }).toList();

  String _label(String value) {
    if (value == 'icc') return 'ICC';
    if (value == 'sc_st') return 'SC/ST Cell';
    return value
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
      case 'closed':
        return AppTheme.success;
      case 'in_progress':
        return AppTheme.info;
      case 'escalated':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  bool _isOverdue(Map<String, dynamic> ticket) {
    final status = ticket['status']?.toString() ?? 'open';
    if (status == 'resolved' || status == 'closed') return false;
    final sla = ticket['sla_due_at'] as String?;
    if (sla == null) return false;
    final due = DateTime.tryParse(sla);
    return due != null && due.isBefore(DateTime.now());
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: AppTheme.caption.copyWith(color: color)),
    );
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
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

  Future<void> _openTicketSheet(Map<String, dynamic> ticket) async {
    final assignCtrl =
        TextEditingController(text: ticket['assigned_to']?.toString() ?? '');
    final resolutionCtrl =
        TextEditingController(text: ticket['resolution']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    String status = ticket['status']?.toString() ?? 'open';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
            ),
            padding: const EdgeInsets.all(AppTheme.lg),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppTheme.md),
                      decoration: BoxDecoration(
                        color: AppTheme.extraLightGray,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                    ),
                  ),
                  Text(ticket['subject']?.toString() ?? 'Grievance',
                      style: AppTheme.h4.copyWith(color: AppTheme.dark)),
                  const SizedBox(height: AppTheme.sm),
                  Wrap(
                    spacing: AppTheme.sm,
                    children: [
                      _chip(_label(ticket['category']?.toString() ?? 'other'),
                          AppTheme.adminPrimary),
                      _chip(_label(status), _statusColor(status)),
                      if (_isOverdue(ticket))
                        _chip('SLA Overdue', AppTheme.error),
                    ],
                  ),
                  const SizedBox(height: AppTheme.md),
                  Text(
                    'Raised by ${ticket['raised_by'] ?? '-'} (${ticket['raised_by_role'] ?? '-'}) • ${_fmtDate(ticket['created_at'])}',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.mediumGray),
                  ),
                  if ((ticket['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppTheme.sm),
                    Text(ticket['description'].toString(),
                        style: AppTheme.bodyMedium
                            .copyWith(color: AppTheme.darkGray)),
                  ],
                  const SizedBox(height: AppTheme.lg),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: _statusFilters
                        .where((s) => s != 'all')
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_label(s)),
                            ))
                        .toList(),
                    onChanged: (v) => setInner(() => status = v ?? status),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: assignCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Assigned To (username)',
                      prefixIcon: Icon(Icons.person_search_outlined),
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: resolutionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Resolution',
                      prefixIcon: Icon(Icons.task_alt_outlined),
                    ),
                    validator: (v) {
                      if ((status == 'resolved' || status == 'closed') &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Resolution is required to close a ticket';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.adminPrimary,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.md),
                      ),
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final ok = await _service.updateGrievance(
                          id: ticket['id'] as String,
                          status: status,
                          assignedTo: assignCtrl.text.trim().isEmpty
                              ? null
                              : assignCtrl.text.trim(),
                          resolution: resolutionCtrl.text.trim().isEmpty
                              ? null
                              : resolutionCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Ticket updated'
                                  : 'Failed to update ticket'),
                              backgroundColor:
                                  ok ? AppTheme.success : AppTheme.error,
                            ),
                          );
                          if (ok) _loadData();
                        }
                      },
                      child: const Text('Save Update'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    assignCtrl.dispose();
    resolutionCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _stats['openGrievances'] as int? ?? 0;
    final overdueCount = _stats['overdueGrievances'] as int? ?? 0;

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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grievance Centre',
                              style: TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          Text('SGRC • Anti-Ragging • ICC • SC/ST Cell',
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
                            _statCard('Open Tickets', '$openCount',
                                Icons.support_agent, AppTheme.warning),
                            const SizedBox(width: AppTheme.md),
                            _statCard('SLA Overdue', '$overdueCount',
                                Icons.alarm_off, AppTheme.error),
                            const SizedBox(width: AppTheme.md),
                            _statCard('Total Tickets', '${_tickets.length}',
                                Icons.confirmation_number_outlined,
                                AppTheme.adminPrimary),
                          ],
                        ),
                        const SizedBox(height: AppTheme.lg),
                        // Category filter
                        DropdownButtonFormField<String>(
                          initialValue: _categoryFilter,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: 'all', child: Text('All Categories')),
                            ...AdminWorkflowService.grievanceCategories.map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(_label(c)),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _categoryFilter = v ?? 'all'),
                        ),
                        const SizedBox(height: AppTheme.md),
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
                                Icon(Icons.support_agent,
                                    size: 56, color: AppTheme.lightGray),
                                const SizedBox(height: AppTheme.md),
                                Text('No grievance tickets found',
                                    style: AppTheme.bodyLarge
                                        .copyWith(color: AppTheme.mediumGray)),
                              ],
                            ),
                          )
                        else
                          ..._filtered.map((t) {
                            final status = t['status']?.toString() ?? 'open';
                            final overdue = _isOverdue(t);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppTheme.md),
                              child: GlassCard(
                                color: overdue
                                    ? AppTheme.error.withOpacity(0.05)
                                    : null,
                                onTap: () => _openTicketSheet(t),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t['subject']?.toString() ??
                                                'Grievance',
                                            style: AppTheme.h5
                                                .copyWith(color: AppTheme.dark),
                                          ),
                                        ),
                                        _chip(_label(status),
                                            _statusColor(status)),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.sm),
                                    Wrap(
                                      spacing: AppTheme.sm,
                                      runSpacing: AppTheme.sm,
                                      children: [
                                        _chip(
                                            _label(t['category']?.toString() ??
                                                'other'),
                                            AppTheme.adminPrimary),
                                        if (overdue)
                                          _chip('SLA Overdue', AppTheme.error),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.sm),
                                    Text(
                                      '${t['raised_by'] ?? '-'} • ${_fmtDate(t['created_at'])}'
                                      '${t['sla_due_at'] != null ? ' • SLA ${_fmtDate(t['sla_due_at'])}' : ''}'
                                      '${(t['assigned_to']?.toString() ?? '').isNotEmpty ? ' • Assigned: ${t['assigned_to']}' : ''}',
                                      style: AppTheme.bodySmall.copyWith(
                                          color: overdue
                                              ? AppTheme.error
                                              : AppTheme.mediumGray),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
