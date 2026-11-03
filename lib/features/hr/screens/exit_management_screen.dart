import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/hr_workflow_service.dart';

class ExitManagementScreen extends StatefulWidget {
  final String username;
  const ExitManagementScreen({super.key, this.username = ''});

  @override
  State<ExitManagementScreen> createState() => _ExitManagementScreenState();
}

class _ExitManagementScreenState extends State<ExitManagementScreen> {
  final _service = HrWorkflowService();
  List<Map<String, dynamic>> _exits = [];
  List<Map<String, dynamic>> _noDues = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _selectedExit;
  bool _isLoading = true;
  bool _isLoadingDues = false;

  static const List<String> _exitTypes = [
    'resignation',
    'retirement',
    'termination',
    'end_of_contract',
    'death',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final exits = await _service.getExits();
    final stats = await _service.getExitStats();
    if (mounted) {
      setState(() {
        _exits = exits;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectExit(Map<String, dynamic> exit) async {
    setState(() {
      _selectedExit = exit;
      _isLoadingDues = true;
    });
    final dues = await _service.getExitNoDues(exit['id'].toString());
    if (mounted) {
      setState(() {
        _noDues = dues;
        _isLoadingDues = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'relieved':
      case 'completed':
      case 'clear':
        return AppTheme.success;
      case 'fnf_pending':
        return AppTheme.accentTeal;
      case 'due':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _statusChip(String? status) {
    final s = status ?? 'pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(s).withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        s.replaceAll('_', ' ').toUpperCase(),
        style: AppTheme.caption.copyWith(color: _statusColor(s)),
      ),
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.teacherPrimary,
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.teacherPrimary, width: 2),
      ),
    );
  }

  // ---------------- Initiate Exit ----------------
  Future<void> _showInitiateExitDialog() async {
    final formKey = GlobalKey<FormState>();
    final employeeCtrl = TextEditingController();
    final noticeCtrl = TextEditingController(text: '30');
    final remarksCtrl = TextEditingController();
    String exitType = 'resignation';
    DateTime? lastDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Initiate Employee Exit'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: employeeCtrl,
                    decoration: _fieldDecoration('Employee Username *',
                        icon: Icons.person),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Employee username is required'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    value: exitType,
                    decoration: _fieldDecoration('Exit Type'),
                    items: _exitTypes
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => exitType = v ?? 'resignation'),
                  ),
                  const SizedBox(height: AppTheme.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(lastDate == null
                        ? 'Select Last Working Date'
                        : 'Last date: ${DateFormat('dd MMM yyyy').format(lastDate!)}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => lastDate = picked);
                      }
                    },
                  ),
                  TextFormField(
                    controller: noticeCtrl,
                    decoration: _fieldDecoration('Notice Period (days)',
                        icon: Icons.timer_outlined),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return int.tryParse(v.trim()) == null
                          ? 'Enter a valid number'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: remarksCtrl,
                    decoration: _fieldDecoration('Remarks'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teacherPrimary),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Initiate',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final exitId = await _service.initiateExit({
        'employee_id': employeeCtrl.text.trim(),
        'exit_type': exitType,
        'last_working_date': lastDate?.toIso8601String().split('T')[0],
        'notice_period_days': int.tryParse(noticeCtrl.text.trim()) ?? 0,
        'remarks':
            remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        'initiated_by': widget.username.isEmpty ? null : widget.username,
      });
      _showMessage(
          exitId != null
              ? 'Exit initiated — no-dues checklist created'
              : 'Failed to initiate exit',
          isError: exitId == null);
      if (exitId != null) _loadData();
    }
    employeeCtrl.dispose();
    noticeCtrl.dispose();
    remarksCtrl.dispose();
  }

  // ---------------- No-Dues Actions ----------------
  Future<void> _markClear(Map<String, dynamic> row) async {
    final exit = _selectedExit;
    if (exit == null) return;
    final ok = await _service.updateExitClearance(
      exit['id'].toString(),
      row['department'].toString(),
      'clear',
      dueAmount: 0,
      updatedBy: widget.username.isEmpty ? null : widget.username,
    );
    _showMessage(ok ? 'Marked clear' : 'Failed to update clearance',
        isError: !ok);
    if (ok) {
      await _selectExit(exit);
      _loadData();
    }
  }

  Future<void> _markDue(Map<String, dynamic> row) async {
    final exit = _selectedExit;
    if (exit == null) return;
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Due — ${row['department']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                decoration:
                    _fieldDecoration('Due Amount (₹)', icon: Icons.money_off),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Due amount is required';
                  }
                  return double.tryParse(v.trim()) == null
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: AppTheme.md),
              TextFormField(
                controller: remarksCtrl,
                decoration: _fieldDecoration('Remarks'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child:
                const Text('Mark Due', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final ok = await _service.updateExitClearance(
        exit['id'].toString(),
        row['department'].toString(),
        'due',
        dueAmount: double.tryParse(amountCtrl.text.trim()),
        remarks:
            remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        updatedBy: widget.username.isEmpty ? null : widget.username,
      );
      _showMessage(ok ? 'Marked as due' : 'Failed to update clearance',
          isError: !ok);
      if (ok) _selectExit(exit);
    }
    amountCtrl.dispose();
    remarksCtrl.dispose();
  }

  // ---------------- Complete FnF ----------------
  Future<void> _completeFnF() async {
    final exit = _selectedExit;
    if (exit == null) return;
    double totalDue = 0;
    for (var r in _noDues) {
      totalDue += (r['due_amount'] as num?)?.toDouble() ?? 0;
    }
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Full & Final'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (totalDue > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: Text(
                    'Outstanding dues of ₹${totalDue.toStringAsFixed(2)} will be adjusted in FnF.',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
                  ),
                ),
              TextFormField(
                controller: amountCtrl,
                decoration: _fieldDecoration('FnF Payable Amount (₹) *',
                    icon: Icons.payments_outlined),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'FnF amount is required';
                  }
                  return double.tryParse(v.trim()) == null
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Relieve Employee',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      final ok = await _service.completeFnF(exit['id'].toString(), amount);
      _showMessage(
          ok ? 'FnF completed — employee relieved' : 'Failed to complete FnF',
          isError: !ok);
      if (ok) {
        await _loadData();
        final refreshed = _exits.firstWhere(
          (e) => e['id'] == exit['id'],
          orElse: () => {...exit, 'status': 'relieved', 'fnf_amount': amount},
        );
        _selectExit(refreshed);
      }
    }
    amountCtrl.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.teacherPrimary,
        onPressed: _showInitiateExitDialog,
        icon: const Icon(Icons.logout, color: Colors.white),
        label:
            const Text('Initiate Exit', style: TextStyle(color: Colors.white)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.teacherPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.teacherGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.lg, 56, AppTheme.lg, AppTheme.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Exit & Full-and-Final',
                          style: AppTheme.h3.copyWith(color: AppTheme.white),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Resignation, retirement, no-dues & FnF settlement',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: AppTheme.md),
                        Row(
                          children: [
                            _statMini('In Progress',
                                _stats['inProgress']?.toString() ?? '0'),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('No-Dues Pending',
                                _stats['noDuesPending']?.toString() ?? '0'),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Relieved',
                                _stats['relieved']?.toString() ?? '0'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.teacherPrimary),
              ),
            )
          else if (_exits.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.door_front_door_outlined,
                        size: 64, color: AppTheme.lightGray),
                    const SizedBox(height: AppTheme.md),
                    Text('No exit cases yet',
                        style: AppTheme.h5
                            .copyWith(color: AppTheme.mediumGray)),
                    const SizedBox(height: AppTheme.sm),
                    const Text('Initiate an exit to start no-dues clearance.',
                        style: TextStyle(color: AppTheme.lightGray)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ..._exits.map(_buildExitCard),
                  if (_selectedExit != null) ...[
                    const SizedBox(height: AppTheme.lg),
                    _buildNoDuesSection(),
                  ],
                  const SizedBox(height: 80),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statMini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTheme.h4.copyWith(color: AppTheme.white)),
        Text(label, style: AppTheme.caption.copyWith(color: Colors.white70)),
      ],
    );
  }

  Widget _buildExitCard(Map<String, dynamic> exit) {
    final employee = exit['employee_id']?.toString() ?? '-';
    final isSelected = _selectedExit?['id'] == exit['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        elevated: isSelected,
        onTap: () => _selectExit(exit),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.teacherPrimary.withOpacity(0.12),
              child: Text(
                employee.isNotEmpty ? employee[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppTheme.teacherPrimary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee, style: AppTheme.bodyLarge),
                  Text(
                    '${(exit['exit_type'] ?? '').toString().replaceAll('_', ' ')} • Last date ${_formatDate(exit['last_working_date'])}',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.mediumGray),
                  ),
                  if (exit['fnf_amount'] != null)
                    Text(
                      'FnF: ₹${(exit['fnf_amount'] as num).toStringAsFixed(2)}',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.teacherDark),
                    ),
                ],
              ),
            ),
            _statusChip(exit['status']?.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDuesSection() {
    final exit = _selectedExit!;
    final cleared =
        _noDues.where((r) => r['status'] == 'clear').length;
    final allClear =
        _noDues.isNotEmpty && cleared == _noDues.length;
    final isRelieved = exit['status'] == 'relieved';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No-Dues Checklist — ${exit['employee_id'] ?? ''}',
            style: AppTheme.h5),
        const SizedBox(height: AppTheme.xs),
        Text('$cleared of ${_noDues.length} departments cleared',
            style:
                AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray)),
        const SizedBox(height: AppTheme.md),
        if (_isLoadingDues)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.lg),
              child: CircularProgressIndicator(
                  color: AppTheme.teacherPrimary),
            ),
          )
        else if (_noDues.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text('No checklist rows found for this exit.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.mediumGray)),
              ),
            ),
          )
        else
          ..._noDues.map(_buildNoDuesRow),
        if (!isRelieved) ...[
          const SizedBox(height: AppTheme.md),
          GradientButton(
            text: allClear
                ? 'Complete FnF & Relieve'
                : 'Complete FnF (dues will be adjusted)',
            icon: Icons.verified_outlined,
            gradient: AppTheme.teacherGradient,
            onPressed: _completeFnF,
          ),
        ],
      ],
    );
  }

  Widget _buildNoDuesRow(Map<String, dynamic> row) {
    final dept = row['department']?.toString() ?? '';
    final status = row['status']?.toString() ?? 'pending';
    final due = (row['due_amount'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.md, vertical: AppTheme.sm),
        child: Row(
          children: [
            Icon(
              status == 'clear'
                  ? Icons.check_circle
                  : status == 'due'
                      ? Icons.error
                      : Icons.hourglass_empty,
              color: _statusColor(status),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dept[0].toUpperCase() + dept.substring(1),
                      style: AppTheme.bodyLarge),
                  if (status == 'due')
                    Text('Due: ₹${due.toStringAsFixed(2)}',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.error)),
                  if (row['remarks'] != null)
                    Text(row['remarks'].toString(),
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.mediumGray)),
                ],
              ),
            ),
            _statusChip(status),
            if (status != 'clear') ...[
              const SizedBox(width: AppTheme.sm),
              TextButton(
                onPressed: () => _markClear(row),
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => _markDue(row),
                child: const Text('Due',
                    style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
