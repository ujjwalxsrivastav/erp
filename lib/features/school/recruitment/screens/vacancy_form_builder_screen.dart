import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/auth_service.dart';
import '../services/school_recruitment_service.dart';
import '../widgets/dynamic_question_field.dart';
import '../widgets/recruitment_widgets.dart';
import 'question_templates_screen.dart';

/// Google-Forms-style builder for a school teacher vacancy.
///
/// The base questions come from `school_vacancy_question_templates`. The
/// administrator can pick which base questions to use, override whether each
/// one is required, add custom questions, and choose the documents applicants
/// must upload. Publishing freezes a snapshot in `form_schema`.
class SchoolVacancyBuilderScreen extends StatefulWidget {
  final String? vacancyId;

  const SchoolVacancyBuilderScreen({super.key, this.vacancyId});

  @override
  State<SchoolVacancyBuilderScreen> createState() =>
      _SchoolVacancyBuilderScreenState();
}

class _SchoolVacancyBuilderScreenState
    extends State<SchoolVacancyBuilderScreen> {
  void _openTemplates() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SchoolQuestionTemplatesScreen()),
    ).then((_) => _load());
  }
  final _service = SchoolRecruitmentService();
  final _authService = AuthService();

  final _titleCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _vacanciesCtrl = TextEditingController(text: '1');
  final _eligibilityCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _postType = 'permanent';
  String _status = 'draft';
  DateTime? _closingDate;

  List<Map<String, dynamic>> _templates = [];
  final Set<String> _selectedTemplateKeys = {};
  final Map<String, bool> _requiredOverrides = {};
  final List<Map<String, dynamic>> _customQuestions = [];
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>? _vacancy;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAdmin = false;
  String _role = '';

  static const _postTypes = [
    {'value': 'permanent', 'label': 'Permanent'},
    {'value': 'contract', 'label': 'Contract'},
    {'value': 'adjunct', 'label': 'Adjunct'},
    {'value': 'visiting', 'label': 'Visiting'},
  ];

  bool get _isEditing => widget.vacancyId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _departmentCtrl.dispose();
    _vacanciesCtrl.dispose();
    _eligibilityCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final role = await _authService.getLiveUserRole();
    final templates = await _service.getQuestionTemplates();
    Map<String, dynamic>? vacancy;
    if (_isEditing) {
      vacancy = await _service.getVacancy(widget.vacancyId!);
    }
    if (!mounted) return;

    _vacancy = vacancy;
    _templates = templates;
    _isAdmin = SchoolRecruitmentService.isAdminRole(role);
    _role = role ?? 'unknown';

    if (vacancy != null) {
      _titleCtrl.text = vacancy['title']?.toString() ?? '';
      _departmentCtrl.text = vacancy['department']?.toString() ?? '';
      _vacanciesCtrl.text = vacancy['vacancies']?.toString() ?? '1';
      _eligibilityCtrl.text = vacancy['eligibility']?.toString() ?? '';
      _descriptionCtrl.text = vacancy['description']?.toString() ?? '';
      _postType = vacancy['post_type']?.toString() ?? 'permanent';
      _status = vacancy['status']?.toString() ?? 'draft';
      _closingDate =
          DateTime.tryParse(vacancy['closing_date']?.toString() ?? '');

      final schema = vacancy['form_schema'];
      final questions = schema is List ? schema.whereType<Map>().toList() : [];
      final templateKeys =
          _templates.map((t) => _templateKey(t)).whereType<String>().toSet();
      for (final q in questions) {
        final key = q['key']?.toString() ??
            q['template_key']?.toString() ??
            '';
        if (templateKeys.contains(key)) {
          _selectedTemplateKeys.add(key);
          _requiredOverrides[key] = q['required'] == true;
        } else {
          _customQuestions.add(Map<String, dynamic>.from(q));
        }
      }
      if (questions.isEmpty) {
        _selectAllActiveTemplates();
      }

      final docs = vacancy['required_documents'];
      if (docs is List && docs.isNotEmpty) {
        _documents = docs
            .whereType<Map>()
            .map((d) => <String, dynamic>{
                  'key': d['key']?.toString() ?? '',
                  'label': d['label']?.toString() ?? '',
                  'required': d['required'] != false,
                  'included': true,
                })
            .where((d) => (d['key'] as String).isNotEmpty)
            .toList();
        _mergeDefaultDocuments();
      } else {
        _initDefaultDocuments();
      }
    } else {
      _selectAllActiveTemplates();
      _initDefaultDocuments();
    }

    setState(() => _isLoading = false);
  }

  String? _templateKey(Map<String, dynamic> template) {
    final key = template['template_key']?.toString();
    if (key != null && key.isNotEmpty) return key;
    final id = template['id']?.toString();
    return id == null ? null : 't_$id';
  }

  void _selectAllActiveTemplates() {
    for (final t in _templates) {
      if (t['is_active'] == false) continue;
      final key = _templateKey(t);
      if (key != null) _selectedTemplateKeys.add(key);
    }
  }

  void _initDefaultDocuments() {
    _documents = SchoolRecruitmentService.defaultRequiredDocuments
        .map((d) => <String, dynamic>{
              'key': d['key'],
              'label': d['label'],
              'required': d['required'] == true,
              'included': d['required'] == true,
            })
        .toList();
  }

  void _mergeDefaultDocuments() {
    for (final d in SchoolRecruitmentService.defaultRequiredDocuments) {
      if (!_documents.any((e) => e['key'] == d['key'])) {
        _documents.add(<String, dynamic>{
          'key': d['key'],
          'label': d['label'],
          'required': false,
          'included': false,
        });
      }
    }
  }

  Future<void> _pickClosingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _closingDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 540)),
    );
    if (picked != null && mounted) {
      setState(() => _closingDate = picked);
    }
  }

  List<Map<String, dynamic>> _buildSchema() {
    final schema = <Map<String, dynamic>>[];
    for (final t in _templates) {
      final key = _templateKey(t);
      if (key == null || !_selectedTemplateKeys.contains(key)) continue;
      schema.add({
        'key': key,
        'label': t['question_text']?.toString() ?? 'Question',
        'type': t['question_type']?.toString() ?? 'short_answer',
        'required': _requiredOverrides[key] ?? (t['is_required'] == true),
        'options': t['options'] is List ? t['options'] : <String>[],
        'help_text': t['help_text'],
      });
    }
    for (final q in _customQuestions) {
      if (q['key'] == null || q['key'].toString().isEmpty) continue;
      schema.add(Map<String, dynamic>.from(q));
    }
    return schema;
  }

  List<Map<String, dynamic>> _buildDocuments(List<Map<String, dynamic>> schema) {
    final docs = _documents
        .where((d) => d['included'] == true && (d['key'] as String).isNotEmpty)
        .map((d) => <String, dynamic>{
              'key': d['key'],
              'label': d['label'],
              'required': d['required'] == true,
            })
        .toList();

    // File-upload questions become document requirements automatically.
    for (final q in schema.where((q) => q['type'] == 'file_upload')) {
      final key = q['key'].toString();
      if (!docs.any((d) => d['key'] == key)) {
        docs.add({
          'key': key,
          'label': q['label'] ?? key,
          'required': q['required'] == true,
        });
      }
    }
    return docs;
  }

  Future<void> _save({required bool publish}) async {
    if (!_isAdmin) {
      showRecruitmentMessage(
        context,
        'Only administrators can create teacher vacancies.',
        isError: true,
      );
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      showRecruitmentMessage(context, 'Vacancy title is required.',
          isError: true);
      return;
    }
    final positions = int.tryParse(_vacanciesCtrl.text.trim()) ?? 1;
    if (positions < 1) {
      showRecruitmentMessage(context, 'Enter at least one position.',
          isError: true);
      return;
    }
    final schema = _buildSchema();
    if (schema.isEmpty) {
      showRecruitmentMessage(
        context,
        'Add at least one application question before publishing.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    final result = await _service.saveVacancy(
      id: widget.vacancyId,
      title: _titleCtrl.text,
      department: _departmentCtrl.text,
      postType: _postType,
      vacancies: positions,
      eligibility: _eligibilityCtrl.text,
      description: _descriptionCtrl.text,
      closingDate: _closingDate,
      status: publish ? 'published' : _status,
      formSchema: schema,
      requiredDocuments: _buildDocuments(schema),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] != true) {
      showRecruitmentMessage(
        context,
        result['message']?.toString() ?? 'Could not save the vacancy.',
        isError: true,
      );
      return;
    }

    final data = result['data'];
    final id = data is Map ? data['id']?.toString() : widget.vacancyId;
    if (publish && id != null) {
      final link = _service.shareLinkFor(id);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vacancy published'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The form is live. Share this link with teachers:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  link,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RecruitmentColors.blue,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _showPreview() {
    final schema = _buildSchema();
    final docs = _buildDocuments(schema);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Applicant preview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: RecruitmentColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _titleCtrl.text.trim().isEmpty
                  ? 'Untitled vacancy'
                  : _titleCtrl.text.trim(),
              style: kRecruitmentTitle,
            ),
            const SizedBox(height: 12),
            ...schema.map(
              (q) => DynamicQuestionField(
                question: q,
                enabled: false,
                onChanged: (_) {},
              ),
            ),
            if (docs.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Documents', style: kRecruitmentTitle),
              const SizedBox(height: 6),
              ...docs.map(
                (d) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file_rounded, size: 18),
                  title: Text(
                    d['label']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    d['required'] == true ? 'Required' : 'Optional',
                    style: kRecruitmentCaption,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const RecruitmentNotice(
              text:
                  'This is a preview. Nothing is submitted from here. Publishing freezes these questions for this vacancy.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCustomQuestion({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final labelCtrl = TextEditingController(
      text: existing?['label']?.toString() ?? '',
    );
    final helpCtrl = TextEditingController(
      text: existing?['help_text']?.toString() ?? '',
    );
    final optionsCtrl = TextEditingController(
      text: existing?['options'] is List
          ? (existing!['options'] as List).join(', ')
          : '',
    );
    String type = existing?['type']?.toString() ?? 'short_answer';
    bool required = existing?['required'] != false;

    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final needsOptions = const {
            'multiple_choice',
            'checkboxes',
            'dropdown',
          }.contains(type);
          return AlertDialog(
            title: Text(isEdit ? 'Edit question' : 'Add question'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: recruitmentFieldDecoration(
                        'Question *',
                        icon: Icons.help_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: recruitmentFieldDecoration('Answer type'),
                      items: SchoolRecruitmentService.questionTypes
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t['value'],
                              child: Text(t['label'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => type = v);
                      },
                    ),
                    if (needsOptions) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: optionsCtrl,
                        decoration: recruitmentFieldDecoration(
                          'Options (comma separated) *',
                          hint: 'Option 1, Option 2',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: helpCtrl,
                      decoration: recruitmentFieldDecoration(
                        'Helper text (optional)',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: required,
                      onChanged: (v) => setDialogState(() => required = v),
                      title: const Text(
                        'Required question',
                        style: TextStyle(fontSize: 13),
                      ),
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
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: RecruitmentColors.blue,
                ),
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty) {
                    showRecruitmentMessage(ctx, 'Question text is required.',
                        isError: true);
                    return;
                  }
                  final options = optionsCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  if (needsOptions && options.isEmpty) {
                    showRecruitmentMessage(ctx, 'Add at least one option.',
                        isError: true);
                    return;
                  }
                  Navigator.pop(ctx, <String, dynamic>{
                    'key': existing?['key']?.toString() ??
                        'custom_${DateTime.now().microsecondsSinceEpoch}',
                    'label': labelCtrl.text.trim(),
                    'type': type,
                    'required': required,
                    'options': options,
                    'help_text': helpCtrl.text.trim().isEmpty
                        ? null
                        : helpCtrl.text.trim(),
                  });
                },
                child: Text(isEdit ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      ),
    );

    labelCtrl.dispose();
    helpCtrl.dispose();
    optionsCtrl.dispose();
    if (saved == null) return;
    setState(() {
      if (isEdit) {
        final index = _customQuestions.indexWhere(
          (q) => q['key'] == existing!['key'],
        );
        if (index >= 0) {
          _customQuestions[index] = saved;
        }
      } else {
        _customQuestions.add(saved);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecruitmentColors.surface,
      appBar: recruitmentAppBar(
        _isEditing ? 'Edit Vacancy' : 'Create Vacancy',
        actions: [
          IconButton(
            tooltip: 'Preview form',
            onPressed: _isAdmin ? _showPreview : null,
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: RecruitmentColors.blue),
            )
          : !_isAdmin
              ? _buildAccessDenied()
              : _buildBody(),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 54, color: RecruitmentColors.red),
            const SizedBox(height: 12),
            const Text(
              'Administrator access required',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: RecruitmentColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Only administrators can create teacher vacancies. '
              'Your current role is "$_role".',
              textAlign: TextAlign.center,
              style: kRecruitmentBody,
            ),
            const SizedBox(height: 14),
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

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        RecruitmentHero(
          eyebrow: _isEditing ? 'Editing vacancy' : 'New vacancy',
          title: 'Build the application form',
          subtitle:
              'Pick base questions, add your own, choose the documents applicants must upload, then publish a shareable form.',
          icon: Icons.dynamic_form_rounded,
          trailing: RecruitmentStatusChip(status: _status),
        ),
        const SizedBox(height: 14),
        RecruitmentSectionCard(
          title: 'Vacancy details',
          icon: Icons.work_outline_rounded,
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: recruitmentFieldDecoration(
                  'Vacancy title *',
                  icon: Icons.badge_outlined,
                  hint: 'e.g. PGT Mathematics',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _departmentCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: recruitmentFieldDecoration(
                        'Department / subject',
                        icon: Icons.account_tree_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _vacanciesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: recruitmentFieldDecoration(
                        'Positions *',
                        icon: Icons.groups_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _postType,
                decoration: recruitmentFieldDecoration('Employment type'),
                items: _postTypes
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t['value'],
                        child: Text(t['label'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _postType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _eligibilityCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: recruitmentFieldDecoration(
                  'Eligibility & requirements',
                  icon: Icons.verified_user_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: recruitmentFieldDecoration(
                  'About the role (optional)',
                  icon: Icons.notes_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RecruitmentSectionCard(
          title: 'Base questions',
          icon: Icons.quiz_outlined,
          action: TextButton(
            onPressed: _openTemplates,
            child: const Text('Edit base list'),
          ),
          child: Column(
            children: [
              const RecruitmentNotice(
                text:
                    'These questions come from the shared base list. Select the ones this vacancy should ask and override "required" if needed.',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 8),
              if (_templates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No base questions found. Add them from "Edit base list".',
                    style: kRecruitmentBody,
                  ),
                )
              else
                ..._templates.map(_buildTemplateRow),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RecruitmentSectionCard(
          title: 'Additional questions',
          icon: Icons.add_circle_outline_rounded,
          child: Column(
            children: [
              if (_customQuestions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'No additional questions yet. Add school-specific questions such as "Which CBSE subject do you teach?"',
                    style: kRecruitmentBody,
                  ),
                )
              else
                ..._customQuestions.map(_buildCustomQuestionCard),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _editCustomQuestion(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add question'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RecruitmentSectionCard(
          title: 'Documents applicants must upload',
          icon: Icons.attach_file_rounded,
          child: Column(
            children: _documents.map(_buildDocumentRow).toList(),
          ),
        ),
        const SizedBox(height: 14),
        RecruitmentSectionCard(
          title: 'Publishing',
          icon: Icons.schedule_outlined,
          child: Column(
            children: [
              InkWell(
                onTap: _pickClosingDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RecruitmentColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined,
                          size: 19, color: RecruitmentColors.slate),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Closing date', style: kRecruitmentCaption),
                            Text(
                              _closingDate == null
                                  ? 'Open until filled'
                                  : DateFormat('dd MMM yyyy')
                                      .format(_closingDate!),
                              style: kRecruitmentBody,
                            ),
                          ],
                        ),
                      ),
                      if (_closingDate != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _closingDate = null),
                          icon: const Icon(Icons.close, size: 16),
                        )
                      else
                        const Icon(Icons.chevron_right,
                            color: RecruitmentColors.slate),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: recruitmentFieldDecoration('Visibility'),
                items: const [
                  DropdownMenuItem(
                    value: 'draft',
                    child: Text('Draft (admin only)'),
                  ),
                  DropdownMenuItem(
                    value: 'published',
                    child: Text('Published to teachers'),
                  ),
                  DropdownMenuItem(
                    value: 'closed',
                    child: Text('Closed'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : () => _save(publish: false),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save draft'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: RecruitmentColors.blue,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: _isSaving ? null : () => _save(publish: true),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Publish form'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateRow(Map<String, dynamic> template) {
    final key = _templateKey(template);
    if (key == null) return const SizedBox.shrink();
    final selected = _selectedTemplateKeys.contains(key);
    final required = _requiredOverrides[key] ?? (template['is_required'] == true);
    final type = template['question_type']?.toString() ?? 'short_answer';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: BoxDecoration(
        color: selected
            ? RecruitmentColors.blue.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? RecruitmentColors.blue : RecruitmentColors.border,
        ),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 4, right: 4),
            controlAffinity: ListTileControlAffinity.leading,
            value: selected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedTemplateKeys.add(key);
                } else {
                  _selectedTemplateKeys.remove(key);
                }
              });
            },
            title: Text(
              template['question_text']?.toString() ?? 'Question',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: RecruitmentColors.navy,
              ),
            ),
            subtitle: Text(
              '${SchoolRecruitmentService.questionTypeLabel(type)}'
              '${template['is_active'] == false ? ' • disabled in base list' : ''}',
              style: kRecruitmentCaption,
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 4, bottom: 2),
              child: Row(
                children: [
                  const Text('Required', style: kRecruitmentCaption),
                  const SizedBox(width: 4),
                  Switch(
                    value: required,
                    onChanged: (v) =>
                        setState(() => _requiredOverrides[key] = v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomQuestionCard(Map<String, dynamic> question) {
    final type = question['type']?.toString() ?? 'short_answer';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RecruitmentColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['label']?.toString() ?? 'Question',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: RecruitmentColors.navy,
                  ),
                ),
                Text(
                  '${SchoolRecruitmentService.questionTypeLabel(type)}'
                  '${question['required'] == true ? ' • Required' : ' • Optional'}',
                  style: kRecruitmentCaption,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
            onPressed: () => _editCustomQuestion(existing: question),
            icon: const Icon(Icons.edit_outlined, size: 17),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            onPressed: () =>
                setState(() => _customQuestions.remove(question)),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 17,
              color: RecruitmentColors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(Map<String, dynamic> doc) {
    final included = doc['included'] == true;
    final required = doc['required'] == true;
    return Column(
      children: [
        CheckboxListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: included,
          onChanged: (v) => setState(() {
            doc['included'] = v == true;
            if (v != true) doc['required'] = false;
          }),
          title: Text(
            doc['label']?.toString() ?? 'Document',
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        if (included)
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 2),
            child: Row(
              children: [
                const Text('Required', style: kRecruitmentCaption),
                Switch(
                  value: required,
                  onChanged: (v) => setState(() => doc['required'] = v),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
