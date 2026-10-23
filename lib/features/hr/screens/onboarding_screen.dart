import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/teacher_lifecycle_service.dart';

/// Employee Onboarding — joining cases for hired teachers: generated
/// username + employee id, document checklist, subject competency
/// and the Complete Joining action that creates the login account,
/// teacher profile and payroll record.
class EmployeeOnboardingScreen extends StatefulWidget {
  final String username;
  const EmployeeOnboardingScreen({super.key, this.username = ''});

  @override
  State<EmployeeOnboardingScreen> createState() =>
      _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends State<EmployeeOnboardingScreen> {
  final _service = TeacherLifecycleService();
  List<Map<String, dynamic>> _cases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cases = await _service.getOnboardings();
    if (mounted) {
      setState(() {
        _cases = cases;
        _isLoading = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  int _docsDone(Map<String, dynamic> ob) {
    final docs = ob['documents'];
    if (docs is! Map) return 0;
    return TeacherLifecycleService.documentKeys
        .where((k) => docs[k] == true)
        .length;
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'documents_pending':
        return AppTheme.info;
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

  Future<void> _openCase(Map<String, dynamic> ob) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _OnboardingDetailPage(onboarding: ob),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _cases.where((c) => c['status'] != 'completed').length;
    final completedCount =
        _cases.where((c) => c['status'] == 'completed').length;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                decoration:
                    const BoxDecoration(gradient: AppTheme.teacherGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.lg, 56, AppTheme.lg, AppTheme.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Employee Onboarding',
                          style: AppTheme.h3.copyWith(color: AppTheme.white),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Documents, competency & joining — zero to hero',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: AppTheme.md),
                        Row(
                          children: [
                            _statMini('Total Cases', _cases.length.toString()),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('In Progress', pendingCount.toString()),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Joined', completedCount.toString()),
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
                child:
                    CircularProgressIndicator(color: AppTheme.teacherPrimary),
              ),
            )
          else if (_cases.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_outlined,
                        size: 64, color: AppTheme.lightGray),
                    const SizedBox(height: AppTheme.md),
                    Text('No onboarding cases yet',
                        style:
                            AppTheme.h5.copyWith(color: AppTheme.mediumGray)),
                    const SizedBox(height: AppTheme.sm),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.xl),
                      child: Text(
                        'Start onboarding from a candidate\'s offer in the Hiring Pipeline — the case will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.lightGray),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ..._cases.map(_buildCaseCard),
                  const SizedBox(height: 40),
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

  Widget _buildCaseCard(Map<String, dynamic> ob) {
    final name = ob['full_name']?.toString() ?? 'New Teacher';
    final done = _docsDone(ob);
    final total = TeacherLifecycleService.documentKeys.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        onTap: () => _openCase(ob),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.teacherPrimary.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                  Text(name, style: AppTheme.bodyLarge),
                  Text(
                    '${ob['designation'] ?? '-'} • ${ob['department'] ?? '-'}',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.mediumGray),
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Wrap(
                    spacing: AppTheme.sm,
                    runSpacing: AppTheme.xs,
                    children: [
                      _miniTag(Icons.badge_outlined,
                          ob['employee_id']?.toString() ?? '-'),
                      _miniTag(Icons.person_outline,
                          ob['username']?.toString() ?? '-'),
                      _miniTag(Icons.folder_open_outlined,
                          'Docs $done/$total'),
                      _miniTag(Icons.event_outlined,
                          'Joining ${_formatDate(ob['joining_date'])}'),
                    ],
                  ),
                ],
              ),
            ),
            _statusChip(ob['status']?.toString()),
            const Icon(Icons.chevron_right, color: AppTheme.lightGray),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.lightGray),
        const SizedBox(width: 3),
        Text(text,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray)),
      ],
    );
  }
}

// ============================================================
// ONBOARDING DETAIL — documents, competency, salary, joining
// ============================================================
class _OnboardingDetailPage extends StatefulWidget {
  final Map<String, dynamic> onboarding;
  const _OnboardingDetailPage({required this.onboarding});

  @override
  State<_OnboardingDetailPage> createState() => _OnboardingDetailPageState();
}

class _OnboardingDetailPageState extends State<_OnboardingDetailPage> {
  final _service = TeacherLifecycleService();
  late Map<String, dynamic> _ob;
  List<Map<String, dynamic>> _competency = [];
  bool _isLoading = true;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _ob = Map<String, dynamic>.from(widget.onboarding);
    _reload();
  }

  Future<void> _reload() async {
    final fresh = await _service.getOnboarding(_ob['id'].toString());
    final username = (fresh ?? _ob)['username']?.toString();
    final competency = username == null || username.isEmpty
        ? <Map<String, dynamic>>[]
        : await _service.getCompetency(username);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _ob = fresh;
      _competency = competency;
      _isLoading = false;
    });
  }

  Map<String, dynamic> get _documents {
    final docs = _ob['documents'];
    final map = <String, dynamic>{
      for (var k in TeacherLifecycleService.documentKeys) k: false,
    };
    if (docs is Map) {
      for (var k in TeacherLifecycleService.documentKeys) {
        map[k] = docs[k] == true;
      }
    }
    return map;
  }

  bool get _allDocsDone => _documents.values.every((v) => v == true);
  bool get _isCompleted => _ob['status'] == 'completed';

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
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

  Future<void> _toggleDocument(String key, bool value) async {
    final docs = _documents;
    docs[key] = value;
    setState(() => _ob = {..._ob, 'documents': docs});
    final ok =
        await _service.updateOnboardingDocuments(_ob['id'].toString(), docs);
    if (!ok) {
      _showMessage('Failed to save document status', isError: true);
      _reload();
    }
  }

  Future<void> _addCompetency() async {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String proficiency = 'primary';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Competency Subject'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: idCtrl,
                    decoration: _fieldDecoration('Subject Code / ID *',
                        icon: Icons.book_outlined),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Subject ID is required'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: nameCtrl,
                    decoration:
                        _fieldDecoration('Subject Name', icon: Icons.subject),
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    value: proficiency,
                    decoration: _fieldDecoration('Proficiency'),
                    items: const [
                      DropdownMenuItem(
                          value: 'primary',
                          child: Text('Primary (core expertise)')),
                      DropdownMenuItem(
                          value: 'secondary',
                          child: Text('Secondary (can also teach)')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => proficiency = v ?? 'primary'),
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
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final username = _ob['username']?.toString() ?? '';
      final ok = await _service.setCompetency(username, [
        {
          'subject_id': idCtrl.text.trim(),
          'subject_name':
              nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
          'proficiency': proficiency,
        },
      ]);
      _showMessage(ok ? 'Competency added' : 'Failed to add competency',
          isError: !ok);
      if (ok) _reload();
    }
    idCtrl.dispose();
    nameCtrl.dispose();
  }

  Future<void> _removeCompetency(Map<String, dynamic> comp) async {
    final username = _ob['username']?.toString() ?? '';
    final ok = await _service.removeCompetency(
        username, comp['subject_id'].toString());
    _showMessage(ok ? 'Competency removed' : 'Failed to remove',
        isError: !ok);
    if (ok) _reload();
  }

  Future<void> _completeJoining() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Joining?'),
        content: Text(
          'This will create the login account (${_ob['username']}), the teacher '
          'profile (${_ob['employee_id']}) and seed payroll from the offer. '
          'The candidate will be marked as Joined.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete Joining',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isJoining = true);
    final result = await _service.completeOnboarding(_ob['id'].toString());
    if (!mounted) return;
    setState(() => _isJoining = false);
    await _showJoiningResult(result);
    _reload();
  }

  Future<void> _showJoiningResult(Map<String, dynamic> result) async {
    final steps = (result['steps'] as Map?) ?? {};
    final errors = (result['errors'] as List?) ?? [];
    final success = result['success'] == true;
    String stepLabel(String key) {
      final v = steps[key]?.toString();
      return switch (v) {
        'created' => 'Done',
        'exists' => 'Already existed (skipped)',
        'completed' => 'Done',
        'joined' => 'Done',
        'already_completed' => 'Already completed',
        'skipped' => 'Skipped',
        'failed' => 'FAILED',
        _ => v ?? '-',
      };
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error_outline,
                color: success ? AppTheme.success : AppTheme.error),
            const SizedBox(width: AppTheme.sm),
            Text(success ? 'Teacher Joined' : 'Joining Incomplete'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Username: ${result['username'] ?? '-'}',
                  style: AppTheme.bodyLarge),
              Text('Employee ID: ${result['employee_id'] ?? '-'}',
                  style: AppTheme.bodyLarge),
              if (success)
                Text('Default password = username (same as Add Teacher flow)',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.mediumGray)),
              const Divider(height: AppTheme.lg),
              _resultRow('Login account', stepLabel('user_account')),
              _resultRow('Teacher profile', stepLabel('teacher_details')),
              _resultRow('Payroll seeding', stepLabel('teacher_salary')),
              _resultRow('Onboarding case', stepLabel('onboarding')),
              if (errors.isNotEmpty) ...[
                const Divider(height: AppTheme.lg),
                Text('Issues:',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.error)),
                ...errors.map((e) => Text('• $e',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.error))),
                if (!success)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTheme.sm),
                    child: Text(
                      'Fix the issue and press Complete Joining again — completed steps are safely skipped on retry.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    final failed = value == 'FAILED';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.xs),
      child: Row(
        children: [
          Icon(failed ? Icons.cancel_outlined : Icons.check_circle_outline,
              size: 16,
              color: failed ? AppTheme.error : AppTheme.success),
          const SizedBox(width: AppTheme.sm),
          Expanded(child: Text(label, style: AppTheme.bodyMedium)),
          Text(value,
              style: AppTheme.bodySmall.copyWith(
                  color: failed ? AppTheme.error : AppTheme.mediumGray)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _ob['full_name']?.toString() ?? 'New Teacher';
    final offer = _ob['offer'] as Map<String, dynamic>?;
    final app = _ob['application'] as Map<String, dynamic>?;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppTheme.teacherPrimary,
        foregroundColor: Colors.white,
        title: const Text('Onboarding Case'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.teacherPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(name, app),
                  const SizedBox(height: AppTheme.lg),
                  _buildDocumentsCard(),
                  const SizedBox(height: AppTheme.lg),
                  _buildCompetencyCard(),
                  const SizedBox(height: AppTheme.lg),
                  _buildSalaryCard(offer),
                  const SizedBox(height: AppTheme.lg),
                  _buildJoiningButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(String name, Map<String, dynamic>? app) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.teacherPrimary.withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppTheme.teacherPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTheme.h5),
                    Text(
                      '${_ob['designation'] ?? '-'} • ${_ob['department'] ?? '-'}',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.mediumGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_isCompleted ? AppTheme.success : AppTheme.warning)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  (_ob['status'] ?? 'pending')
                      .toString()
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  style: AppTheme.caption.copyWith(
                      color:
                          _isCompleted ? AppTheme.success : AppTheme.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          _infoRow(Icons.badge_outlined, 'Employee ID',
              _ob['employee_id']?.toString() ?? '-'),
          _infoRow(Icons.person_outline, 'Login Username',
              _ob['username']?.toString() ?? '-'),
          _infoRow(Icons.event_outlined, 'Joining Date',
              _formatDate(_ob['joining_date'])),
          if (app != null) ...[
            _infoRow(Icons.email_outlined, 'Email',
                app['email']?.toString() ?? '-'),
            _infoRow(Icons.phone_outlined, 'Phone',
                app['phone']?.toString() ?? '-'),
            _infoRow(Icons.school_outlined, 'Qualification',
                app['qualification']?.toString() ?? '-'),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.lightGray),
          const SizedBox(width: AppTheme.sm),
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray)),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard() {
    final docs = _documents;
    final done =
        TeacherLifecycleService.documentKeys.where((k) => docs[k] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Document Checklist', style: AppTheme.h5)),
            Text('$done/${TeacherLifecycleService.documentKeys.length}',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.mediumGray)),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
          child: Column(
            children: TeacherLifecycleService.documentKeys.map((key) {
              return CheckboxListTile(
                value: docs[key] == true,
                activeColor: AppTheme.teacherPrimary,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                    TeacherLifecycleService.documentLabels[key] ?? key),
                subtitle: Text(docs[key] == true ? 'Received' : 'Pending',
                    style: AppTheme.bodySmall.copyWith(
                        color: docs[key] == true
                            ? AppTheme.success
                            : AppTheme.warning)),
                onChanged: _isCompleted
                    ? null
                    : (v) => _toggleDocument(key, v ?? false),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompetencyCard() {
    final username = _ob['username']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Subject Competency', style: AppTheme.h5)),
            TextButton.icon(
              onPressed: username.isEmpty ? null : _addCompetency,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Subject'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Subjects this teacher can teach — the HOD sees these while allotting subjects.',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
        ),
        const SizedBox(height: AppTheme.md),
        if (_competency.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text('No competency subjects added yet.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.mediumGray)),
              ),
            ),
          )
        else
          Wrap(
            spacing: AppTheme.sm,
            runSpacing: AppTheme.sm,
            children: _competency.map((comp) {
              final primary = comp['proficiency'] == 'primary';
              return Chip(
                avatar: Icon(
                  primary ? Icons.star : Icons.star_border,
                  size: 16,
                  color: primary
                      ? AppTheme.teacherPrimary
                      : AppTheme.mediumGray,
                ),
                label: Text(
                    '${comp['subject_name'] ?? comp['subject_id']} (${comp['subject_id']})'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: _isCompleted
                    ? null
                    : () => _removeCompetency(comp),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSalaryCard(Map<String, dynamic>? offer) {
    final fmt = NumberFormat('#,##0');
    if (offer == null) {
      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppTheme.warning),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Text(
                'No offer letter linked to this case — salary cannot be seeded until an offer exists.',
                style: AppTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final basic = (offer['basic_salary'] as num?)?.toDouble() ?? 0;
    final hra = (offer['hra'] as num?)?.toDouble() ?? 0;
    final other = (offer['other_allowances'] as num?)?.toDouble() ?? 0;
    final pf = (basic * 0.12 * 100).round() / 100;
    final gross = basic + hra + other;
    final net = gross - pf - TeacherLifecycleService.defaultProfessionalTax;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Salary from Offer (seeds payroll on joining)',
            style: AppTheme.h5),
        const SizedBox(height: AppTheme.md),
        GlassCard(
          child: Column(
            children: [
              _salaryRow('Basic Salary', '₹${fmt.format(basic)}'),
              _salaryRow('HRA', '₹${fmt.format(hra)}'),
              _salaryRow('Other Allowances', '₹${fmt.format(other)}'),
              const Divider(height: AppTheme.lg),
              _salaryRow('Gross / month', '₹${fmt.format(gross)}', bold: true),
              _salaryRow('Provident Fund (12% of basic)', '− ₹${fmt.format(pf)}'),
              _salaryRow('Professional Tax',
                  '− ₹${fmt.format(TeacherLifecycleService.defaultProfessionalTax)}'),
              const Divider(height: AppTheme.lg),
              _salaryRow('Estimated Net / month', '₹${fmt.format(net)}',
                  bold: true, color: AppTheme.teacherPrimary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _salaryRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTheme.bodyMedium.copyWith(
                    fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          ),
          Text(value,
              style: AppTheme.bodyMedium.copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildJoiningButton() {
    if (_isCompleted) {
      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Joining completed', style: AppTheme.bodyLarge),
                  Text(
                    'Login: ${_ob['username']} • Employee ID: ${_ob['employee_id']} • Default password is the username.',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: _allDocsDone ? 1 : 0.5,
          child: GradientButton(
            text: _allDocsDone
                ? 'Complete Joining'
                : 'Complete Joining (documents pending)',
            icon: Icons.rocket_launch_outlined,
            gradient: AppTheme.teacherGradient,
            isLoading: _isJoining,
            onPressed: _allDocsDone ? _completeJoining : () {},
          ),
        ),
        if (!_allDocsDone)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.sm),
            child: Text(
              'All ${TeacherLifecycleService.documentKeys.length} documents must be marked received before joining can be completed.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.warning),
            ),
          ),
      ],
    );
  }
}
