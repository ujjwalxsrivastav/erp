import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../services/school_recruitment_service.dart'
    show SchoolRecruitmentService;
import '../widgets/recruitment_widgets.dart';
import 'school_document_verification_screen.dart';
import 'school_interview_board_screen.dart';

/// Admin screen to view and manage all applications for a vacancy.
class SchoolVacancyReviewScreen extends StatefulWidget {
  final String vacancyId;

  const SchoolVacancyReviewScreen({super.key, required this.vacancyId});

  @override
  State<SchoolVacancyReviewScreen> createState() => _SchoolVacancyReviewScreenState();
}

class _SchoolVacancyReviewScreenState extends State<SchoolVacancyReviewScreen> {
  final _service = SchoolRecruitmentService();
  final _authService = AuthService();

  Map<String, dynamic>? _vacancy;
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final role = await _authService.getLiveUserRole();
    final vacancy = await _service.getVacancy(widget.vacancyId);
    final apps = await _service.getApplications(vacancyId: widget.vacancyId);
    if (!mounted) return;
    setState(() {
      _isAdmin = SchoolRecruitmentService.isAdminRole(role);
      _vacancy = vacancy;
      _applications = apps;
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    showRecruitmentMessage(context, message, isError: isError);
  }

  Future<void> _selectApplication(String id) async {
    final ok = await _service.selectApplication(id);
    if (ok) {
      _showMessage('Candidate selected.');
      _load();
    } else {
      _showMessage('Could not select candidate.', isError: true);
    }
  }

  Future<void> _rejectApplication(String id) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject candidate'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: recruitmentFieldDecoration('Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _service.rejectApplication(id, reasonCtrl.text);
    if (ok) {
      _showMessage('Candidate rejected.');
      _load();
    } else {
      _showMessage('Could not reject candidate.', isError: true);
    }
  }

  Future<void> _openDocuments(String applicationId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchoolDocumentVerificationScreen(applicationId: applicationId),
      ),
    ).then((_) => _load());
  }

  Future<void> _openInterview(String applicationId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchoolInterviewBoardScreen(applicationId: applicationId),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: RecruitmentColors.surface,
        appBar: recruitmentAppBar('Loading...'),
        body: const Center(child: CircularProgressIndicator(color: RecruitmentColors.blue)),
      );
    }

    return Scaffold(
      backgroundColor: RecruitmentColors.surface,
      appBar: recruitmentAppBar(
        _vacancy?['title']?.toString() ?? 'Applications',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !_isAdmin
          ? _buildAccessDenied()
          : _applications.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildAccessDenied() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Administrator access required.', textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildEmpty() {
    return RecruitmentBody(children: [
      RecruitmentEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No applications yet',
        subtitle: 'Published vacancies will show applicants here.',
      ),
    ]);
  }

  Widget _buildList() {
    return RecruitmentBody(children: [
      RecruitmentHero(
        eyebrow: 'Vacancy: ${_vacancy?['title'] ?? ''}',
        title: '${_applications.length} applications',
        subtitle: 'Review, verify documents, schedule interviews, or select/reject candidates.',
        icon: Icons.assignment_rounded,
        stats: [
          RecruitmentStat(
            value: _applications.where((a) => a['status'] == 'applied').length.toString(),
            label: 'New',
            color: Colors.white,
          ),
          RecruitmentStat(
            value: _applications.where((a) => a['document_status'] == 'verified').length.toString(),
            label: 'Documents Verified',
            color: Colors.white,
          ),
          RecruitmentStat(
            value: _applications.where((a) => a['interview_status'] == 'scheduled').length.toString(),
            label: 'Interviews',
            color: Colors.white,
          ),
          RecruitmentStat(
            value: _applications.where((a) => a['status'] == 'selected').length.toString(),
            label: 'Selected',
            color: Colors.white,
          ),
        ],
      ),
      const SizedBox(height: 14),
      ..._applications.map(_buildAppCard),
    ]);
  }

  Widget _buildAppCard(Map<String, dynamic> app) {
    final status = app['status']?.toString() ?? 'applied';
    final docStatus = app['document_status']?.toString() ?? 'pending';
    final interviewStatus = app['interview_status']?.toString() ?? 'not_scheduled';
    final docs = app['school_vacancy_documents'];
    final docList = docs is List ? docs.whereType<Map>().toList() : <Map>[];
    final interviews = app['school_vacancy_interviews'];
    final interviewList = interviews is List ? interviews.whereType<Map>().toList() : <Map>[];
    final nextInterview = interviewList.isNotEmpty
        ? interviewList.firstWhere(
            (i) => i['status'] == 'scheduled',
            orElse: () => interviewList.first)
        : null;

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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: RecruitmentColors.blueSoft,
                  child: Text(
                    app['applicant_name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: RecruitmentColors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app['applicant_name']?.toString() ?? 'Unknown', style: kRecruitmentTitle),
                      Text(
                        app['applicant_username'] != null
                            ? 'Username: ${app['applicant_username']}'
                            : 'Anonymous applicant',
                        style: kRecruitmentCaption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RecruitmentStatusChip(status: status),
                    const SizedBox(height: 4),
                    RecruitmentStatusChip(status: docStatus, compact: true),
                    if (interviewStatus != 'not_scheduled')
                      RecruitmentStatusChip(status: interviewStatus, compact: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('Qualification', app['qualification']?.toString() ?? '—'),
                _chip('Experience', '${app['experience_years'] ?? 0} yrs'),
                _chip('Email', app['email']?.toString() ?? '—'),
                _chip('Phone', app['phone']?.toString() ?? '—'),
              ],
            ),
            if (docList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Documents: ', style: kRecruitmentCaption),
                  ...docList.map((d) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: RecruitmentStatusChip(
                      status: d['status']?.toString() ?? 'pending',
                      compact: true,
                    ),
                  )),
                ],
              ),
            ],
            if (nextInterview != null) ...[
              const SizedBox(height: 8),
              Text(
                'Next interview: ${recruitmentDateTime(nextInterview['scheduled_at'])}',
                style: TextStyle(fontSize: 11.5, color: RecruitmentColors.blue, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (docStatus != 'verified')
                  OutlinedButton.icon(
                    onPressed: () => _openDocuments(app['id'].toString()),
                    icon: const Icon(Icons.verified_user_rounded, size: 16),
                    label: Text(docList.isEmpty ? 'Upload docs' : 'Verify docs (${docList.length})'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _openInterview(app['id'].toString()),
                    icon: const Icon(Icons.event_available_rounded, size: 16),
                    label: Text(interviewStatus == 'scheduled' ? 'Interview scheduled' : 'Schedule interview'),
                  ),
                const SizedBox(width: 8),
                if (status == 'applied' || status == 'documents_pending' || status == 'documents_verified')
                  OutlinedButton.icon(
                    onPressed: () => _selectApplication(app['id'].toString()),
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('Select'),
                  ),
                if (status == 'selected')
                  OutlinedButton.icon(
                    onPressed: () => _openInterview(app['id'].toString()),
                    icon: const Icon(Icons.event_available_rounded, size: 16),
                    label: const Text('Manage interview'),
                  ),
                const Spacer(),
                if (status != 'rejected' && status != 'enrolled')
                  OutlinedButton.icon(
                    onPressed: () => _rejectApplication(app['id'].toString()),
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: RecruitmentColors.red),
                    label: const Text('Reject', style: TextStyle(color: RecruitmentColors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: RecruitmentColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RecruitmentColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 10.5, color: RecruitmentColors.slate)),
          Text(value, style: const TextStyle(fontSize: 10.5, color: RecruitmentColors.navy, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}