import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../services/auth_service.dart';
import '../../hr/services/hr_workflow_service.dart';

/// Administrator-only form for publishing a teacher vacancy.
///
/// Access is checked twice:
///   1. The screen shows an access-denied state for non-admin roles.
///   2. [HrWorkflowService.createPostingWithResult] re-reads the live role
///      before writing to `job_postings`.
class TeacherVacancyFormScreen extends StatefulWidget {
  const TeacherVacancyFormScreen({super.key});

  @override
  State<TeacherVacancyFormScreen> createState() =>
      _TeacherVacancyFormScreenState();
}

class _TeacherVacancyFormScreenState extends State<TeacherVacancyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _hrService = HrWorkflowService();

  final _titleCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _vacanciesCtrl = TextEditingController(text: '1');
  final _eligibilityCtrl = TextEditingController();

  static const List<Map<String, String>> _employmentTypes = [
    {'value': 'permanent', 'label': 'Permanent'},
    {'value': 'contract', 'label': 'Contract'},
    {'value': 'adjunct', 'label': 'Adjunct'},
    {'value': 'visiting', 'label': 'Visiting'},
  ];

  String _employmentType = 'permanent';
  String _status = 'draft';
  DateTime? _closingDate;

  bool _isCheckingAccess = true;
  bool _isAdmin = false;
  bool _isSaving = false;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _departmentCtrl.dispose();
    _vacanciesCtrl.dispose();
    _eligibilityCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final role = await _authService.getLiveUserRole();
    if (!mounted) return;
    setState(() {
      _role = role ?? 'unknown';
      _isAdmin = HrWorkflowService.isAdminRole(role);
      _isCheckingAccess = false;
    });
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
        borderSide: const BorderSide(color: AppTheme.adminPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.error, width: 2),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.adminPrimary,
      ),
    );
  }

  Future<void> _pickClosingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _closingDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
    );
    if (picked != null && mounted) {
      setState(() => _closingDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_isAdmin) {
      _showMessage(
        'Only administrators can create teacher vacancies.',
        isError: true,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final vacancies = int.tryParse(_vacanciesCtrl.text.trim()) ?? 1;
    final result = await _hrService.createPostingWithResult({
      'title': _titleCtrl.text.trim(),
      'department': _departmentCtrl.text.trim().isEmpty
          ? null
          : _departmentCtrl.text.trim(),
      'post_type': _employmentType,
      'vacancies': vacancies,
      'eligibility': _eligibilityCtrl.text.trim().isEmpty
          ? null
          : _eligibilityCtrl.text.trim(),
      'status': _status,
      'closing_date': _closingDate?.toIso8601String().split('T').first,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);

    final success = result['success'] == true;
    _showMessage(
      result['message']?.toString() ??
          (success ? 'Vacancy created.' : 'Failed to create vacancy.'),
      isError: !success,
    );

    if (success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.dark,
        foregroundColor: AppTheme.white,
        title: const Text('Create Teacher Vacancy'),
        elevation: 0,
      ),
      body: _isCheckingAccess
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.adminPrimary),
            )
          : !_isAdmin
              ? _buildAccessDenied()
              : _buildForm(),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.lg),
            Text('Administrator access required', style: AppTheme.h4),
            const SizedBox(height: AppTheme.sm),
            Text(
              'Only administrators can create teacher vacancies. '
              'Your current role is "$_role".',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
            const SizedBox(height: AppTheme.lg),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.md,
          AppTheme.md,
          AppTheme.md,
          AppTheme.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroBanner(),
            const SizedBox(height: AppTheme.lg),
            _sectionHeader(
              'Vacancy Details',
              Icons.work_outline_rounded,
            ),
            const SizedBox(height: AppTheme.md),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration(
                'Vacancy Title *  (e.g. PGT Mathematics)',
                icon: Icons.badge_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vacancy title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.md),
            TextFormField(
              controller: _departmentCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration(
                'Department / Subject  (e.g. Mathematics)',
                icon: Icons.account_tree_outlined,
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _employmentType,
                    decoration: _fieldDecoration(
                      'Employment Type',
                      icon: Icons.badge_outlined,
                    ),
                    items: _employmentTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type['value']!,
                            child: Text(type['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _employmentType = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: TextFormField(
                    controller: _vacanciesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      'Vacancies *',
                      icon: Icons.groups_outlined,
                    ),
                    validator: (value) {
                      final count = int.tryParse(value?.trim() ?? '');
                      if (count == null || count < 1) {
                        return 'Enter 1 or more';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.lg),
            _sectionHeader(
              'Eligibility & Requirements',
              Icons.verified_user_outlined,
            ),
            const SizedBox(height: AppTheme.md),
            TextFormField(
              controller: _eligibilityCtrl,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(
                'Qualifications, experience, pay scale or other notes',
                icon: Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: AppTheme.lg),
            _sectionHeader(
              'Timeline & Publishing',
              Icons.schedule_outlined,
            ),
            const SizedBox(height: AppTheme.md),
            InkWell(
              onTap: _pickClosingDate,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.md),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.extraLightGray),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Closing Date',
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.mediumGray),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _closingDate == null
                                ? 'Not set — applications stay open'
                                : DateFormat('dd MMM yyyy')
                                    .format(_closingDate!),
                            style: AppTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_closingDate != null)
                      IconButton(
                        tooltip: 'Clear date',
                        onPressed: () => setState(() => _closingDate = null),
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppTheme.lightGray,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.lightGray,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.md),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: _fieldDecoration(
                'Visibility',
                icon: Icons.visibility_outlined,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'draft',
                  child: Text('Save as draft (admin only)'),
                ),
                DropdownMenuItem(
                  value: 'published',
                  child: Text('Publish to vacancies board'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: AppTheme.xl),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text:
                    _status == 'published' ? 'Publish Vacancy' : 'Save Vacancy',
                icon: Icons.check_circle_outline_rounded,
                gradient: AppTheme.adminGradient,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              'Only administrators can create or publish teacher vacancies.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.lightGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.adminPrimary.withOpacity(0.12),
            AppTheme.adminLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.adminPrimary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: AppTheme.adminPrimary,
            size: 28,
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Text(
              'Admin-only action. Published vacancies appear on the '
              'Teacher Vacancies board and in the recruitment pipeline.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.adminDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.adminPrimary),
        const SizedBox(width: AppTheme.sm),
        Text(title, style: AppTheme.h5.copyWith(fontSize: 16)),
      ],
    );
  }
}
