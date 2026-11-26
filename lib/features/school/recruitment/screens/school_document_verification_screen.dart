import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../services/school_recruitment_service.dart'
    show SchoolRecruitmentService;
import '../widgets/recruitment_widgets.dart';

/// Admin screen to verify applicant documents one by one.
class SchoolDocumentVerificationScreen extends StatefulWidget {
  final String applicationId;

  const SchoolDocumentVerificationScreen({super.key, required this.applicationId});

  @override
  State<SchoolDocumentVerificationScreen> createState() => _SchoolDocumentVerificationScreenState();
}

class _SchoolDocumentVerificationScreenState extends State<SchoolDocumentVerificationScreen> {
  final _service = SchoolRecruitmentService();
  final _authService = AuthService();

  Map<String, dynamic>? _application;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _applicantName = '';
  String _docStatus = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final role = await _authService.getLiveUserRole();
    final app = await _service.getApplication(widget.applicationId);
    if (!mounted) return;

    if (app != null) {
      final docs = await _service.getDocuments(widget.applicationId);
      setState(() {
        _isAdmin = SchoolRecruitmentService.isAdminRole(role);
        _application = app;
        _documents = docs;
        _applicantName = app['applicant_name']?.toString() ?? 'Unknown';
        _docStatus = app['document_status']?.toString() ?? 'pending';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    showRecruitmentMessage(context, message, isError: isError);
  }

  Future<void> _reviewDocument(String docId, bool approve) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Verify document' : 'Reject document'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: recruitmentFieldDecoration('Remarks (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: approve ? RecruitmentColors.green : RecruitmentColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Verify' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _service.reviewDocument(
      documentId: docId,
      approve: approve,
      remarks: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    if (ok) {
      _showMessage(approve ? 'Document verified.' : 'Document rejected.');
      // Refresh document status and application state
      await _service.refreshDocumentStatus(widget.applicationId);
      _load();
    } else {
      _showMessage('Could not update document.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: RecruitmentColors.surface,
        appBar: recruitmentAppBar('Documents'),
        body: const Center(child: CircularProgressIndicator(color: RecruitmentColors.blue)),
      );
    }

    if (_application == null) {
      return Scaffold(
        backgroundColor: RecruitmentColors.surface,
        appBar: recruitmentAppBar('Documents'),
        body: const Center(child: Text('Application not found.')),
      );
    }

    return Scaffold(
      backgroundColor: RecruitmentColors.surface,
      appBar: recruitmentAppBar(
        'Verify documents',
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
          : _documents.isEmpty
              ? _buildNoDocs()
              : _buildDocs(),
    );
  }

  Widget _buildAccessDenied() {
    return const Center(child: Text('Administrator access required.'));
  }

  Widget _buildNoDocs() {
    return RecruitmentBody(children: [
      RecruitmentEmptyState(
        icon: Icons.description_outlined,
        title: 'No documents uploaded',
        subtitle: '$_applicantName has not uploaded any documents yet.',
      ),
    ]);
  }

  Widget _buildDocs() {
    final verifiedCount = _documents.where((d) => d['status'] == 'verified').length;
    final total = _documents.length;
    final allVerified = total > 0 && verifiedCount == total;

    return RecruitmentBody(children: [
      RecruitmentHero(
        eyebrow: 'Applicant: $_applicantName',
        title: 'Document verification',
        subtitle: 'Review each document and mark as verified or rejected. All required documents must be verified before scheduling an interview.',
        icon: Icons.verified_user_rounded,
        stats: [
          RecruitmentStat(value: '$verifiedCount', label: 'Verified', color: Colors.white),
          RecruitmentStat(value: '${total - verifiedCount}', label: 'Pending', color: Colors.white),
          RecruitmentStat(value: '$total', label: 'Total', color: Colors.white),
        ],
        trailing: RecruitmentStatusChip(status: _docStatus),
      ),
      const SizedBox(height: 14),
      if (allVerified)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RecruitmentColors.greenSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RecruitmentColors.green),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: RecruitmentColors.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'All documents verified! You can now schedule an interview.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RecruitmentColors.green),
                ),
              ),
            ],
          ),
        ),
      ..._documents.map(_buildDocCard),
    ]);
  }

  Widget _buildDocCard(Map<String, dynamic> doc) {
    final status = doc['status']?.toString() ?? 'pending';
    final label = doc['document_label']?.toString() ?? doc['document_type']?.toString() ?? 'Document';
    final fileName = doc['file_name']?.toString() ?? '';
    final fileUrl = doc['file_url']?.toString() ?? '';
    final verifiedBy = doc['verified_by']?.toString();
    final verifiedAt = doc['verified_at']?.toString();
    final remarks = doc['remarks']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'verified'
              ? RecruitmentColors.green
              : status == 'rejected'
                  ? RecruitmentColors.red
                  : RecruitmentColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RecruitmentColors.blueSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file_rounded, color: RecruitmentColors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: kRecruitmentTitle),
                      if (fileName.isNotEmpty)
                        Text(fileName, style: kRecruitmentCaption),
                    ],
                  ),
                ),
                RecruitmentStatusChip(status: status),
              ],
            ),
            if (fileUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Open: $fileUrl'), action: SnackBarAction(label: 'Copy', onPressed: () {})),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open document'),
              ),
            ],
            if (verifiedBy != null || verifiedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Verified by $verifiedBy on ${recruitmentDateTime(verifiedAt)}',
                style: kRecruitmentCaption,
              ),
            ],
            if (remarks != null && remarks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RecruitmentColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Remarks: $remarks', style: kRecruitmentBody),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (status == 'pending') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewDocument(doc['id'].toString(), true),
                      icon: const Icon(Icons.check_rounded, size: 16, color: RecruitmentColors.green),
                      label: const Text('Verify', style: TextStyle(color: RecruitmentColors.green)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewDocument(doc['id'].toString(), false),
                      icon: const Icon(Icons.close_rounded, size: 16, color: RecruitmentColors.red),
                      label: const Text('Reject', style: TextStyle(color: RecruitmentColors.red)),
                    ),
                  ),
                ],
                if (status == 'rejected')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewDocument(doc['id'].toString(), true),
                      icon: const Icon(Icons.check_rounded, size: 16, color: RecruitmentColors.green),
                      label: const Text('Re-verify', style: TextStyle(color: RecruitmentColors.green)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}