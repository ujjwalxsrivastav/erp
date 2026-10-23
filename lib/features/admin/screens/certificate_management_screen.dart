import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/admin_workflow_service.dart';

/// Admin centre for certificate requests: request -> processing ->
/// approved -> issued (a CERT-YYYY-#### serial is generated on issue).
class CertificateManagementScreen extends StatefulWidget {
  const CertificateManagementScreen({super.key});

  @override
  State<CertificateManagementScreen> createState() =>
      _CertificateManagementScreenState();
}

class _CertificateManagementScreenState
    extends State<CertificateManagementScreen> {
  final _service = AdminWorkflowService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _statusFilter = 'all';

  static const _statusFilters = [
    'all',
    'requested',
    'processing',
    'approved',
    'issued',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final requests = await _service.getCertificateRequests();
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

  String _label(String value) => value
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _statusColor(String status) {
    switch (status) {
      case 'issued':
        return AppTheme.success;
      case 'approved':
        return AppTheme.accentTeal;
      case 'processing':
        return AppTheme.info;
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
      child: Text(text, style: AppTheme.caption.copyWith(color: color)),
    );
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Future<void> _changeStatus(Map<String, dynamic> request, String status) async {
    final ok = await _service.updateCertificateStatus(
      id: request['id'] as String,
      status: status,
      approvedBy: 'admin',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Certificate moved to ${_label(status)}'
            : 'Failed to update certificate'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ),
    );
    if (ok) _loadData();
  }

  Future<void> _showNewRequestDialog() async {
    final formKey = GlobalKey<FormState>();
    final studentCtrl = TextEditingController();
    final copiesCtrl = TextEditingController(text: '1');
    final feeCtrl = TextEditingController();
    String certType = AdminWorkflowService.certificateTypes.first;
    String delivery = AdminWorkflowService.deliveryModes.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Text('New Certificate Request'),
          content: SingleChildScrollView(
            child: Form(
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
                    initialValue: certType,
                    decoration: const InputDecoration(
                      labelText: 'Certificate Type',
                      prefixIcon: Icon(Icons.workspace_premium_outlined),
                    ),
                    items: AdminWorkflowService.certificateTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_label(t)),
                            ))
                        .toList(),
                    onChanged: (v) => setInner(() => certType = v ?? certType),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: copiesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Copies',
                      prefixIcon: Icon(Icons.copy_outlined),
                    ),
                    validator: (v) {
                      final parsed = int.tryParse(v?.trim() ?? '');
                      if (parsed == null || parsed < 1) {
                        return 'Enter at least 1 copy';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    initialValue: delivery,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Mode',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: AdminWorkflowService.deliveryModes
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(_label(m)),
                            ))
                        .toList(),
                    onChanged: (v) => setInner(() => delivery = v ?? delivery),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: feeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Fee Amount (₹) — optional',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v.trim()) == null) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ],
              ),
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
                final created = await _service.createCertificateRequest(
                  studentId: studentCtrl.text.trim(),
                  certificateType: certType,
                  copies: int.parse(copiesCtrl.text.trim()),
                  deliveryMode: delivery,
                  feeAmount: feeCtrl.text.trim().isEmpty
                      ? 0
                      : double.parse(feeCtrl.text.trim()),
                  requestedBy: 'admin',
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(created != null
                          ? 'Certificate request created'
                          : 'Failed to create request'),
                      backgroundColor:
                          created != null ? AppTheme.success : AppTheme.error,
                    ),
                  );
                  if (created != null) _loadData();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    studentCtrl.dispose();
    copiesCtrl.dispose();
    feeCtrl.dispose();
  }

  Widget _actionButton(
      String label, Color color, VoidCallback onPressed, IconData icon) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  List<Widget> _actionsFor(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'requested';
    switch (status) {
      case 'requested':
        return [
          _actionButton('Start Processing', AppTheme.info,
              () => _changeStatus(request, 'processing'), Icons.play_arrow),
          _actionButton('Reject', AppTheme.error,
              () => _changeStatus(request, 'rejected'), Icons.close),
        ];
      case 'processing':
        return [
          _actionButton('Approve', AppTheme.accentTeal,
              () => _changeStatus(request, 'approved'), Icons.check),
          _actionButton('Reject', AppTheme.error,
              () => _changeStatus(request, 'rejected'), Icons.close),
        ];
      case 'approved':
        return [
          _actionButton('Issue Certificate', AppTheme.success,
              () => _changeStatus(request, 'issued'), Icons.workspace_premium),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          Text('Certificate Management',
                              style: TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          Text('Requests, approval & issuance',
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
                        GradientButton(
                          text: 'New Certificate Request',
                          icon: Icons.add_circle_outline,
                          gradient: AppTheme.adminGradient,
                          onPressed: _showNewRequestDialog,
                        ),
                        const SizedBox(height: AppTheme.lg),
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
                                Icon(Icons.workspace_premium_outlined,
                                    size: 56, color: AppTheme.lightGray),
                                const SizedBox(height: AppTheme.md),
                                Text('No certificate requests found',
                                    style: AppTheme.bodyLarge
                                        .copyWith(color: AppTheme.mediumGray)),
                              ],
                            ),
                          )
                        else
                          ..._filtered.map((r) {
                            final status =
                                r['status']?.toString() ?? 'requested';
                            final fee =
                                (r['fee_amount'] as num?)?.toDouble() ?? 0;
                            final actions = _actionsFor(r);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppTheme.md),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppTheme.adminPrimary
                                              .withOpacity(0.12),
                                          child: const Icon(
                                              Icons.workspace_premium_outlined,
                                              color: AppTheme.adminPrimary),
                                        ),
                                        const SizedBox(width: AppTheme.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _label(r['certificate_type']
                                                        ?.toString() ??
                                                    ''),
                                                style: AppTheme.h5.copyWith(
                                                    color: AppTheme.dark),
                                              ),
                                              Text(
                                                r['student_id']?.toString() ??
                                                    '-',
                                                style: AppTheme.bodySmall
                                                    .copyWith(
                                                        color:
                                                            AppTheme.mediumGray),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _chip(_label(status),
                                            _statusColor(status)),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.md),
                                    Wrap(
                                      spacing: AppTheme.md,
                                      runSpacing: AppTheme.sm,
                                      children: [
                                        _meta(Icons.copy_outlined,
                                            '${r['copies'] ?? 1} copy(ies)'),
                                        _meta(
                                            Icons.local_shipping_outlined,
                                            _label(r['delivery_mode']
                                                    ?.toString() ??
                                                'collect')),
                                        _meta(Icons.currency_rupee,
                                            fee.toStringAsFixed(0)),
                                        _meta(Icons.calendar_today_outlined,
                                            _fmtDate(r['created_at'])),
                                        if ((r['serial_no']?.toString() ?? '')
                                            .isNotEmpty)
                                          _meta(Icons.qr_code,
                                              r['serial_no'].toString()),
                                      ],
                                    ),
                                    if (actions.isNotEmpty) ...[
                                      const SizedBox(height: AppTheme.md),
                                      Wrap(
                                        spacing: AppTheme.sm,
                                        runSpacing: AppTheme.sm,
                                        children: actions,
                                      ),
                                    ],
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

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.lightGray),
        const SizedBox(width: 4),
        Text(text,
            style:
                AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray)),
      ],
    );
  }
}
