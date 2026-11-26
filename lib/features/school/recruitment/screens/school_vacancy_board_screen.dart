import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../services/school_recruitment_service.dart';
import '../widgets/recruitment_widgets.dart';
import 'vacancy_form_builder_screen.dart'
    show SchoolVacancyBuilderScreen;
import 'question_templates_screen.dart';
import 'school_vacancy_review_screen.dart';

/// School admin board: list all vacancies, create/edit, open applications.
class SchoolVacancyBoardScreen extends StatefulWidget {
  const SchoolVacancyBoardScreen({super.key});

  @override
  State<SchoolVacancyBoardScreen> createState() => _SchoolVacancyBoardScreenState();
}

class _SchoolVacancyBoardScreenState extends State<SchoolVacancyBoardScreen> {
  final _service = SchoolRecruitmentService();
  final _authService = AuthService();

  List<Map<String, dynamic>> _vacancies = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final role = await _authService.getLiveUserRole();
    final vacancies = await _service.getVacancies();
    if (!mounted) return;
    setState(() {
      _role = role ?? 'unknown';
      _isAdmin = SchoolRecruitmentService.isAdminRole(role);
      _vacancies = vacancies;
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    showRecruitmentMessage(context, message, isError: isError);
  }

  Future<void> _openBuilder({String? vacancyId}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SchoolVacancyBuilderScreen(vacancyId: vacancyId),
      ),
    );
    if (created == true && mounted) {
      _showMessage('Vacancy saved.');
      _load();
    }
  }

  Future<void> _setStatus(String id, String status) async {
    if (!_isAdmin) {
      _showMessage('Only administrators can change vacancy status.', isError: true);
      return;
    }
    final ok = await _service.setVacancyStatus(id, status);
    if (!ok) {
      _showMessage('Could not update status.', isError: true);
      return;
    }
    _showMessage('Status updated to $status.');
    _load();
  }

  Future<void> _deleteVacancy(String id) async {
    if (!_isAdmin) {
      _showMessage('Only administrators can delete vacancies.', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vacancy?'),
        content: const Text('This will remove the vacancy and all its applications.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _service.deleteVacancy(id);
    if (!ok) {
      _showMessage('Could not delete vacancy.', isError: true);
      return;
    }
    _showMessage('Vacancy deleted.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecruitmentColors.surface,
      appBar: recruitmentAppBar(
        'Teacher Vacancy Board',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Base questions',
            onPressed: _isAdmin ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SchoolQuestionTemplatesScreen()),
            ).then((_) => _load()) : null,
            icon: const Icon(Icons.quiz_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RecruitmentColors.blue))
          : !_isAdmin
              ? _buildAccessDenied()
              : _buildBoard(),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: RecruitmentColors.blue,
              foregroundColor: Colors.white,
              onPressed: () => _openBuilder(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Vacancy'),
            )
          : null,
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 54, color: RecruitmentColors.red),
            const SizedBox(height: 12),
            const Text('Administrator access required',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RecruitmentColors.navy)),
            const SizedBox(height: 6),
            Text('Only administrators can manage vacancies. Your role: "$_role".',
                textAlign: TextAlign.center, style: kRecruitmentBody),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    if (_vacancies.isEmpty) {
      return RecruitmentBody(children: [
        RecruitmentEmptyState(
          icon: Icons.work_outline_rounded,
          title: 'No vacancies yet',
          subtitle: 'Create your first teacher vacancy form.',
          actionLabel: 'Create Vacancy',
          onAction: () => _openBuilder(),
        ),
      ]);
    }

    return RecruitmentBody(children: [
      RecruitmentHero(
        eyebrow: 'Admin view',
        title: 'School Teacher Vacancies',
        subtitle: 'Build forms, track applications, verify documents, schedule interviews.',
        icon: Icons.work_outline_rounded,
        stats: [
          RecruitmentStat(
            value: _vacancies.length.toString(),
            label: 'Total',
            color: Colors.white,
          ),
          RecruitmentStat(
            value: _vacancies.where((v) => v['status'] == 'published').length.toString(),
            label: 'Published',
            color: Colors.white,
          ),
          RecruitmentStat(
            value: _vacancies
                .expand((v) => v['school_vacancy_applications'] is List
                    ? v['school_vacancy_applications'] as List
                    : const [])
                .length
                .toString(),
            label: 'Applications',
            color: Colors.white,
          ),
        ],
      ),
      const SizedBox(height: 14),
      ..._vacancies.map(_buildVacancyCard),
    ]);
  }

  Widget _buildVacancyCard(Map<String, dynamic> v) {
    final status = v['status']?.toString() ?? 'draft';
    final applicantCount = v['applicant_count'] as int? ?? 0;
    final interviewCount = v['interview_count'] as int? ?? 0;
    final verifiedCount = v['verified_count'] as int? ?? 0;
    final closingDate = v['closing_date']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RecruitmentColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: RecruitmentColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.work_outline_rounded, color: RecruitmentColors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              v['title']?.toString() ?? 'Untitled',
                              style: kRecruitmentTitle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RecruitmentStatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (v['department'] != null) v['department'].toString(),
                          (v['post_type'] ?? 'permanent').toString().replaceAll('_', ' '),
                          if (v['vacancies'] != null) '${v['vacancies']} position${v['vacancies'] == 1 ? '' : 's'}',
                        ].join(' · '),
                        style: kRecruitmentBody,
                      ),
                      if (closingDate != null)
                        Text('Closes: ${recruitmentDate(closingDate)}', style: kRecruitmentCaption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniStat(applicantCount.toString(), 'Applied', RecruitmentColors.blue),
                const SizedBox(width: 16),
                _miniStat(verifiedCount.toString(), 'Verified', RecruitmentColors.green),
                const SizedBox(width: 16),
                _miniStat(interviewCount.toString(), 'Interviews', RecruitmentColors.amber),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'draft')
                  OutlinedButton.icon(
                    onPressed: () => _setStatus(v['id'].toString(), 'published'),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Publish'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _setStatus(v['id'].toString(), 'draft'),
                    icon: const Icon(Icons.drafts_rounded, size: 16),
                    label: const Text('Move to draft'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SchoolVacancyReviewScreen(vacancyId: v['id'].toString()),
                    ),
                  ),
                  icon: const Icon(Icons.assignment_rounded, size: 16),
                  label: Text('$applicantCount applications'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openBuilder(vacancyId: v['id'].toString()),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                const Spacer(),
                if (status == 'published')
                  OutlinedButton.icon(
                    onPressed: () => _setStatus(v['id'].toString(), 'closed'),
                    icon: const Icon(Icons.lock_rounded, size: 16, color: RecruitmentColors.red),
                    label: const Text('Close', style: TextStyle(color: RecruitmentColors.red)),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'delete') _deleteVacancy(v['id'].toString());
                    if (value == 'copy_link') _copyLink(v['id'].toString());
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'copy_link', child: Text('Copy share link')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: RecruitmentColors.red))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: kRecruitmentCaption),
      ],
    );
  }

  void _copyLink(String id) {
    final link = _service.shareLinkFor(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $link'), backgroundColor: RecruitmentColors.navy),
    );
  }
}