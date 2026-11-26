import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/auth_service.dart';
import '../services/school_recruitment_service.dart'
    show SchoolRecruitmentService, ApplicantUpload;
import '../widgets/dynamic_question_field.dart';
import '../widgets/recruitment_widgets.dart';

/// Public Google-Forms-style application screen for a school teacher vacancy.
///
/// Route: /apply/vacancy?id=<vacancy_id>
/// Works for logged-in teachers and anonymous applicants.
class SchoolVacancyApplyScreen extends StatefulWidget  {
  final String vacancyId;

  const SchoolVacancyApplyScreen({super.key, required this.vacancyId});

  @override
  State<SchoolVacancyApplyScreen> createState() => _SchoolVacancyApplyScreenState();
}

class _SchoolVacancyApplyScreenState extends State<SchoolVacancyApplyScreen> {
  final _service = SchoolRecruitmentService();
  final _authService = AuthService();

  Map<String, dynamic>? _vacancy;
  List<Map<String, dynamic>> _schema = [];
  List<Map<String, dynamic>> _requiredDocs = [];

  final Map<String, dynamic> _answers = {};
  final Map<String, ApplicantUpload> _documents = {};

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _applicantUsername;
  String? _applicantName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final username = await _authService.getCurrentUsername();
    _applicantUsername = username;
    if (username != null) {
      // Pre-fill from teacher profile if logged in.
      _prefillFromProfile(username);
    }

    final vacancy = await _service.getVacancy(widget.vacancyId);
    if (!mounted) return;

    if (vacancy == null) {
      setState(() {
        _isLoading = false;
        _vacancy = null;
      });
      return;
    }

    final schema = vacancy['form_schema'];
    final docs = vacancy['required_documents'];
    final questions = schema is List ? schema.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    final requiredDocs = docs is List ? docs.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

    setState(() {
      _vacancy = vacancy;
      _schema = questions;
      _requiredDocs = requiredDocs;
      _isLoading = false;
    });
  }

  Future<void> _prefillFromProfile(String username) async {
    // Try to get teacher name from users table
    try {
      final supabase = Supabase.instance.client;
      final user = await supabase
          .from('users')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      if (user != null && mounted) {
        _applicantName = user['username']?.toString() ?? '';
      }
    } catch (_) {}
  }

  void _showMessage(String message, {bool isError = false}) {
    showRecruitmentMessage(context, message, isError: isError);
  }

  Future<void> _pickDocument(String key, String label) async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (result == null) return;

      final bytes = await result.readAsBytes();
      _documents[key] = ApplicantUpload(
        type: key,
        label: label,
        fileName: result.name,
        bytes: bytes,
      );
      if (mounted) setState(() {});
    } catch (e) {
      _showMessage('Could not pick file: $e', isError: true);
    }
  }

  void _removeDocument(String key) {
    _documents.remove(key);
    setState(() {});
  }

  Future<void> _submit() async {
    if (_vacancy == null) return;
    if (_schema.isEmpty) {
      _showMessage('This vacancy has no application questions.', isError: true);
      return;
    }

    // Validate required questions
    for (final q in _schema) {
      if (q['required'] == true) {
        final key = q['key'].toString();
        final val = _answers[key];
        if (val == null || (val is String && val.trim().isEmpty)) {
          _showMessage('Please answer "${q['label']}"', isError: true);
          return;
        }
      }
    }

    // Validate required documents
    for (final doc in _requiredDocs) {
      if (doc['required'] == true) {
        final key = doc['key'].toString();
        if (!_documents.containsKey(key)) {
          _showMessage('Please upload "${doc['label']}"', isError: true);
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);

    final name = _applicantName ?? 'Anonymous applicant';

    final result = await _service.submitApplication(
      vacancyId: widget.vacancyId,
      applicantName: name,
      applicantUsername: _applicantUsername,
      answers: _answers,
      documents: _documents.values.toList(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] != true) {
      _showMessage(result['message']?.toString() ?? 'Could not submit.', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Application submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thank you for applying! Your reference number is:'),
            const SizedBox(height: 8),
            SelectableText(
              result['reference']?.toString() ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RecruitmentColors.blue),
            ),
            if (_applicantUsername == null) ...[
              const SizedBox(height: 10),
              const Text('Save this reference to track your application later.'),
            ],
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.blue),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: RecruitmentColors.surface,
        appBar: recruitmentAppBar('Apply'),
        body: const Center(child: CircularProgressIndicator(color: RecruitmentColors.blue)),
      );
    }

    if (_vacancy == null) {
      return Scaffold(
        backgroundColor: RecruitmentColors.surface,
        appBar: recruitmentAppBar('Apply'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This vacancy no longer exists or is not published.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final status = _vacancy!['status']?.toString() ?? 'draft';
    final closingDate = _vacancy!['closing_date']?.toString();
    final isOpen = status == 'published' && (closingDate == null || DateTime.tryParse(closingDate)?.isAfter(DateTime.now()) != false);

    return Scaffold(
      backgroundColor: RecruitmentColors.surface,
      appBar: recruitmentAppBar('Apply for ${_vacancy!['title']}'),
      body: RecruitmentBody(children: [
        RecruitmentHero(
          eyebrow: 'Teacher vacancy',
          title: _vacancy!['title']?.toString() ?? 'Untitled',
          subtitle: [
            if (_vacancy!['department'] != null) _vacancy!['department'].toString(),
            (_vacancy!['post_type'] ?? 'permanent').toString().replaceAll('_', ' '),
            if (_vacancy!['vacancies'] != null) '${_vacancy!['vacancies']} position${_vacancy!['vacancies'] == 1 ? '' : 's'}',
          ].join(' · '),
          icon: Icons.work_outline_rounded,
          stats: [
            if (closingDate != null)
              RecruitmentStat(value: 'Closes', label: recruitmentDate(closingDate), color: Colors.white),
            RecruitmentStat(value: status.toUpperCase(), label: 'Status', color: Colors.white),
          ],
        ),
        const SizedBox(height: 14),
        if (!isOpen)
          const RecruitmentNotice(
            text: 'This vacancy is not currently accepting applications.',
            icon: Icons.lock_outline_rounded,
            color: RecruitmentColors.red,
          ),
        if (!isOpen) const SizedBox(height: 14),
        if (_vacancy!['description'] != null && _vacancy!['description'].toString().isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RecruitmentColors.border),
            ),
            child: Text(_vacancy!['description'].toString(), style: kRecruitmentBody),
          ),
        if (_vacancy!['description'] != null && _vacancy!['description'].toString().isNotEmpty)
          const SizedBox(height: 14),
        RecruitmentSectionCard(
          title: 'Application questions',
          icon: Icons.quiz_outlined,
          child: Column(
            children: _schema.map((q) => DynamicQuestionField(
              question: q,
              value: _answers[q['key']?.toString() ?? ''],
              onChanged: (val) => setState(() {
                _answers[q['key'].toString()] = val;
              }),
              enabled: isOpen,
            )).toList(),
          ),
        ),
        if (_requiredDocs.isNotEmpty) ...[
          const SizedBox(height: 14),
          RecruitmentSectionCard(
            title: 'Documents to upload',
            icon: Icons.attach_file_rounded,
            child: Column(
              children: _requiredDocs.map((doc) {
                final key = doc['key']?.toString() ?? '';
                final label = doc['label']?.toString() ?? key;
                final required = doc['required'] == true;
                final uploaded = _documents.containsKey(key);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RecruitmentColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, color: RecruitmentColors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: kRecruitmentTitle),
                            Text(
                              uploaded ? 'Uploaded ✓' : (required ? 'Required' : 'Optional'),
                              style: TextStyle(
                                fontSize: 11,
                                color: uploaded ? RecruitmentColors.green : RecruitmentColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: isOpen
                            ? (uploaded ? () => _removeDocument(key) : () => _pickDocument(key, label))
                            : null,
                        icon: Icon(uploaded ? Icons.delete_outline_rounded : Icons.cloud_upload_outlined, size: 16),
                        label: Text(uploaded ? 'Remove' : 'Upload'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            if (_applicantUsername == null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isOpen && !_isSubmitting ? _submit : null,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Submit application'),
                ),
              ),
            if (_applicantUsername != null)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: RecruitmentColors.blue,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: isOpen && !_isSubmitting ? _submit : null,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Submit application'),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}