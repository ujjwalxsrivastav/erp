import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/hr_workflow_service.dart';

class AppraisalScreen extends StatefulWidget {
  final String username;
  const AppraisalScreen({super.key, this.username = ''});

  @override
  State<AppraisalScreen> createState() => _AppraisalScreenState();
}

class _AppraisalScreenState extends State<AppraisalScreen> {
  final _service = HrWorkflowService();
  List<Map<String, dynamic>> _appraisals = [];
  bool _isLoading = true;
  String? _selectedYear;

  static const List<String> _categories = ['teaching', 'research', 'service'];

  List<String> get _years {
    final now = DateTime.now();
    final currentStart = now.month >= 4 ? now.year : now.year - 1;
    return List.generate(
        4, (i) => '${currentStart - i}-${(currentStart - i + 1) % 100}');
  }

  @override
  void initState() {
    super.initState();
    _selectedYear = _years.first;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _service.getAppraisals(year: _selectedYear);
    if (mounted) {
      setState(() {
        _appraisals = data;
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return AppTheme.success;
      case 'submitted':
        return AppTheme.info;
      case 'hod_verified':
      case 'committee_reviewed':
        return AppTheme.accentTeal;
      case 'returned':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _statusChip(String? status) {
    final s = status ?? 'draft';
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

  String? _numberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
  }

  // ---------------- Submit Appraisal ----------------
  Future<void> _showSubmitDialog() async {
    final formKey = GlobalKey<FormState>();
    final employeeCtrl = TextEditingController();
    final selfCtrl = TextEditingController();
    final feedbackCtrl = TextEditingController();
    String category = 'teaching';
    String year = _selectedYear ?? _years.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Submit Appraisal'),
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
                    value: year,
                    decoration: _fieldDecoration('Appraisal Year'),
                    items: _years
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => year = v ?? year),
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: _fieldDecoration('Category'),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c[0].toUpperCase() + c.substring(1))))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => category = v ?? 'teaching'),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: selfCtrl,
                    decoration:
                        _fieldDecoration('Self Score', icon: Icons.score),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _numberValidator,
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: feedbackCtrl,
                    decoration: _fieldDecoration('Student Feedback Score',
                        icon: Icons.feedback_outlined),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _numberValidator,
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
              child: const Text('Submit',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final ok = await _service.submitAppraisal({
        'employee_id': employeeCtrl.text.trim(),
        'appraisal_year': year,
        'category': category,
        'self_score': double.tryParse(selfCtrl.text.trim()),
        'student_feedback_score': double.tryParse(feedbackCtrl.text.trim()),
        'status': 'submitted',
      });
      _showMessage(ok ? 'Appraisal submitted' : 'Failed to submit appraisal',
          isError: !ok);
      if (ok) _loadData();
    }
    employeeCtrl.dispose();
    selfCtrl.dispose();
    feedbackCtrl.dispose();
  }

  // ---------------- Score Entry Actions ----------------
  Future<void> _scoreAction(
    Map<String, dynamic> appraisal,
    String status,
    String title,
    String fieldLabel, {
    bool isFinal = false,
    bool isHod = false,
  }) async {
    final scoreCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: scoreCtrl,
                decoration: _fieldDecoration(fieldLabel, icon: Icons.score),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Score is required';
                  return double.tryParse(v.trim()) == null
                      ? 'Enter a valid number'
                      : null;
                },
              ),
              const SizedBox(height: AppTheme.md),
              TextFormField(
                controller: remarksCtrl,
                decoration: _fieldDecoration('Remarks (optional)'),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final score = double.tryParse(scoreCtrl.text.trim());
      final ok = await _service.updateAppraisalStatus(
        appraisal['id'].toString(),
        status,
        hodScore: isHod ? score : null,
        finalScore: isFinal ? score : null,
        remarks: remarksCtrl.text.trim().isEmpty
            ? null
            : remarksCtrl.text.trim(),
      );
      _showMessage(ok ? 'Appraisal updated' : 'Failed to update appraisal',
          isError: !ok);
      if (ok) _loadData();
    }
    scoreCtrl.dispose();
    remarksCtrl.dispose();
  }

  Future<void> _simpleStatus(
      Map<String, dynamic> appraisal, String status, String label) async {
    final ok = await _service.updateAppraisalStatus(
        appraisal['id'].toString(), status);
    _showMessage(ok ? label : 'Failed to update appraisal', isError: !ok);
    if (ok) _loadData();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _appraisals.where((a) => a['status'] != 'approved').length;
    final approvedCount =
        _appraisals.where((a) => a['status'] == 'approved').length;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.teacherPrimary,
        onPressed: _showSubmitDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('New Appraisal', style: TextStyle(color: Colors.white)),
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
                          'Appraisal (PBAS / API)',
                          style: AppTheme.h3.copyWith(color: AppTheme.white),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Self appraisal, HOD verification & API approval',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: AppTheme.md),
                        Row(
                          children: [
                            _statMini('In Process', pendingCount.toString()),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Approved', approvedCount.toString()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.md, AppTheme.md, AppTheme.md, 0),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined,
                      color: AppTheme.teacherPrimary),
                  const SizedBox(width: AppTheme.sm),
                  const Text('Appraisal Year:'),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: _years
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _selectedYear = v);
                        _loadData();
                      },
                    ),
                  ),
                ],
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
          else if (_appraisals.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.assessment_outlined,
                        size: 64, color: AppTheme.lightGray),
                    const SizedBox(height: AppTheme.md),
                    Text('No appraisals for this year',
                        style: AppTheme.h5
                            .copyWith(color: AppTheme.mediumGray)),
                    const SizedBox(height: AppTheme.sm),
                    const Text('Submit the first appraisal to begin.',
                        style: TextStyle(color: AppTheme.lightGray)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildAppraisalCard(_appraisals[i]),
                  childCount: _appraisals.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
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

  Widget _scoreTile(String label, dynamic value) {
    return Expanded(
      child: Column(
        children: [
          Text(value?.toString() ?? '-',
              style: AppTheme.h5.copyWith(color: AppTheme.teacherDark)),
          Text(label,
              style: AppTheme.caption.copyWith(color: AppTheme.mediumGray)),
        ],
      ),
    );
  }

  Widget _buildAppraisalCard(Map<String, dynamic> a) {
    final employee = a['employee_id']?.toString() ?? '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        '${a['category'] ?? ''} • ${a['appraisal_year'] ?? ''}',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                _statusChip(a['status']?.toString()),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'hod':
                        _scoreAction(a, 'hod_verified', 'HOD Verification',
                            'HOD Score',
                            isHod: true);
                        break;
                      case 'committee':
                        _simpleStatus(a, 'committee_reviewed',
                            'Sent to committee review');
                        break;
                      case 'approve':
                        _scoreAction(a, 'approved', 'Approve Appraisal',
                            'Final API Score',
                            isFinal: true);
                        break;
                      case 'return':
                        _simpleStatus(a, 'returned', 'Appraisal returned');
                        break;
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                        value: 'hod', child: Text('HOD Verify (Score)')),
                    PopupMenuItem(
                        value: 'committee', child: Text('Committee Review')),
                    PopupMenuItem(
                        value: 'approve',
                        child: Text('Approve (Final API Score)')),
                    PopupMenuItem(value: 'return', child: Text('Return')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                _scoreTile('Self', a['self_score']),
                _scoreTile('Feedback', a['student_feedback_score']),
                _scoreTile('HOD', a['hod_score']),
                _scoreTile('Final API', a['final_api_score']),
              ],
            ),
            if (a['remarks'] != null) ...[
              const SizedBox(height: AppTheme.sm),
              Text('Remarks: ${a['remarks']}',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.mediumGray)),
            ],
          ],
        ),
      ),
    );
  }
}
