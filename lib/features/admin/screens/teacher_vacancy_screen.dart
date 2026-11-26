import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../hr/services/hr_workflow_service.dart';
import 'teacher_vacancy_form_screen.dart';

/// Teacher Vacancy board.
///
/// Everyone with access to the page can view vacancies, but the create /
/// publish actions are shown only to administrators. The form and data layer
/// enforce the same rule, so hiding the button is not the only protection.
class TeacherVacancyScreen extends StatefulWidget {
  const TeacherVacancyScreen({super.key});

  @override
  State<TeacherVacancyScreen> createState() => _TeacherVacancyScreenState();
}

class _TeacherVacancyScreenState extends State<TeacherVacancyScreen> {
  final _service = HrWorkflowService();
  final _authService = AuthService();

  List<Map<String, dynamic>> _vacancies = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final role = await _authService.getLiveUserRole();
    final isAdmin = HrWorkflowService.isAdminRole(role);
    // Drafts are internal to the administrator; everyone else sees only
    // published vacancies.
    final vacancies = await _service.getPostings(
      status: isAdmin ? null : 'published',
    );

    if (!mounted) return;
    setState(() {
      _role = role ?? 'unknown';
      _isAdmin = isAdmin;
      _vacancies = vacancies;
      _isLoading = false;
    });
  }

  int get _publishedCount =>
      _vacancies.where((v) => v['status'] == 'published').length;

  int get _totalPositions => _vacancies.fold<int>(
        0,
        (sum, v) => sum + ((v['vacancies'] as num?)?.toInt() ?? 0),
      );

  String _formatDate(dynamic value) {
    if (value == null) return 'Open until filled';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'published':
        return AppTheme.success;
      case 'closed':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _statusChip(String? status) {
    final value = status ?? 'draft';
    final color = _statusColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        value.toUpperCase(),
        style: AppTheme.caption.copyWith(color: color),
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

  Future<void> _openCreateForm() async {
    if (!_isAdmin) {
      _showMessage(
        'Only administrators can create teacher vacancies.',
        isError: true,
      );
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherVacancyFormScreen(),
      ),
    );
    if (created == true && mounted) {
      _showMessage('Teacher vacancy created successfully.');
      _loadData();
    }
  }

  Future<void> _changeStatus(
    Map<String, dynamic> vacancy,
    String status,
  ) async {
    if (!_isAdmin) {
      _showMessage(
        'Only administrators can update teacher vacancies.',
        isError: true,
      );
      return;
    }
    final ok = await _service.updatePostingStatus(
      vacancy['id'].toString(),
      status,
    );
    if (!mounted) return;
    _showMessage(
      ok ? 'Vacancy marked as $status.' : 'Failed to update vacancy.',
      isError: !ok,
    );
    if (ok) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.dark,
        foregroundColor: AppTheme.white,
        elevation: 0,
        title: const Text('Teacher Vacancies'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.adminPrimary,
              foregroundColor: AppTheme.white,
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Vacancy'),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.adminPrimary),
            )
          : RefreshIndicator(
              color: AppTheme.adminPrimary,
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.md,
                  AppTheme.md,
                  AppTheme.md,
                  96,
                ),
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppTheme.md),
                  if (!_isAdmin) ...[
                    _buildReadOnlyBanner(),
                    const SizedBox(height: AppTheme.md),
                  ],
                  if (_vacancies.isEmpty)
                    _buildEmptyState()
                  else
                    ..._vacancies.map(_buildVacancyCard),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: AppTheme.adminGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: AppTheme.white,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faculty Recruitment Board',
                      style: AppTheme.h5.copyWith(color: AppTheme.white),
                    ),
                    Text(
                      'Publish teacher openings and track active vacancies',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              _statusChipForRole(),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Row(
            children: [
              _stat('$_publishedCount', 'Published'),
              const SizedBox(width: AppTheme.xl),
              _stat('${_vacancies.length}', 'Total'),
              const SizedBox(width: AppTheme.xl),
              _stat('$_totalPositions', 'Positions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChipForRole() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        _isAdmin ? 'ADMIN' : 'VIEW ONLY',
        style: AppTheme.caption.copyWith(color: AppTheme.white),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTheme.h4.copyWith(color: AppTheme.white)),
        Text(
          label,
          style: AppTheme.caption.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.warning, size: 20),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Text(
              'Read-only access. Only administrators can create, publish or '
              'close teacher vacancies. Your role: $_role.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.extraLightGray),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.work_off_outlined,
            size: 56,
            color: AppTheme.lightGray,
          ),
          const SizedBox(height: AppTheme.md),
          Text('No teacher vacancies yet', style: AppTheme.h5),
          const SizedBox(height: AppTheme.sm),
          Text(
            _isAdmin
                ? 'Create the first vacancy to open the recruitment board.'
                : 'Administrators have not published any teacher vacancies yet.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: AppTheme.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                foregroundColor: AppTheme.white,
              ),
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add),
              label: const Text('Create Vacancy'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVacancyCard(Map<String, dynamic> vacancy) {
    final status = vacancy['status']?.toString() ?? 'draft';
    final eligibility = vacancy['eligibility']?.toString();
    final department = vacancy['department']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.extraLightGray),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.adminPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: AppTheme.adminPrimary,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vacancy['title']?.toString() ?? 'Untitled vacancy',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (department != null && department.isNotEmpty)
                          department,
                        (vacancy['post_type'] ?? 'permanent')
                            .toString()
                            .replaceAll('_', ' '),
                      ].join(' • '),
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.mediumGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              _statusChip(status),
              if (_isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppTheme.mediumGray,
                  ),
                  onSelected: (value) => _changeStatus(vacancy, value),
                  itemBuilder: (context) => [
                    if (status != 'published')
                      const PopupMenuItem(
                        value: 'published',
                        child: Text('Publish'),
                      ),
                    if (status != 'closed')
                      const PopupMenuItem(
                        value: 'closed',
                        child: Text('Close vacancy'),
                      ),
                    if (status != 'draft')
                      const PopupMenuItem(
                        value: 'draft',
                        child: Text('Move to draft'),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Wrap(
            spacing: AppTheme.lg,
            runSpacing: AppTheme.sm,
            children: [
              _meta(
                Icons.groups_outlined,
                '${vacancy['vacancies'] ?? 1} position(s)',
              ),
              _meta(
                Icons.event_outlined,
                'Closes ${_formatDate(vacancy['closing_date'])}',
              ),
              if (vacancy['created_by'] != null)
                _meta(
                  Icons.person_outline,
                  vacancy['created_by'].toString(),
                ),
            ],
          ),
          if (eligibility != null && eligibility.trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                eligibility,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.lightGray),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
        ),
      ],
    );
  }
}
