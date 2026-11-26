import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../services/school_recruitment_service.dart';
import '../widgets/recruitment_widgets.dart';

/// Administrator screen for the master ("base") question list.
///
/// Edits here never change a vacancy that was already published: each vacancy
/// stores a frozen snapshot in `school_vacancies.form_schema`.
class SchoolQuestionTemplatesScreen extends StatefulWidget {
  const SchoolQuestionTemplatesScreen({super.key});

  @override
  State<SchoolQuestionTemplatesScreen> createState() =>
      _SchoolQuestionTemplatesScreenState();
}

class _SchoolQuestionTemplatesScreenState
    extends State<SchoolQuestionTemplatesScreen> {
  final _service = SchoolRecruitmentService();
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final liveRole = await AuthService().getLiveUserRole();
    final templates = await _service.getQuestionTemplates();
    if (!mounted) return;
    setState(() {
      _isAdmin = SchoolRecruitmentService.isAdminRole(liveRole);
      _templates = templates;
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    showRecruitmentMessage(context, message, isError: isError);
  }

  Future<void> _showEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final textCtrl = TextEditingController(
      text: existing?['question_text']?.toString() ?? '',
    );
    final helpCtrl = TextEditingController(
      text: existing?['help_text']?.toString() ?? '',
    );
    final optionsCtrl = TextEditingController(
      text: (existing?['options'] is List)
          ? (existing!['options'] as List).join(', ')
          : '',
    );
    String type = existing?['question_type']?.toString() ?? 'short_answer';
    bool required = existing?['is_required'] != false;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final needsOptions = const {
            'multiple_choice',
            'checkboxes',
            'dropdown',
          }.contains(type);
          return AlertDialog(
            title: Text(isEdit ? 'Edit base question' : 'Add base question'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: textCtrl,
                      decoration: recruitmentFieldDecoration(
                        'Question text *',
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
                          icon: Icons.list_alt_rounded,
                          hint: 'Option 1, Option 2, Option 3',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: helpCtrl,
                      decoration: recruitmentFieldDecoration(
                        'Helper text (optional)',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: RecruitmentColors.blue,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (textCtrl.text.trim().isEmpty) {
                          _showMessage('Question text is required.',
                              isError: true);
                          return;
                        }
                        final options = optionsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (needsOptions && options.isEmpty) {
                          _showMessage('Add at least one option.',
                              isError: true);
                          return;
                        }
                        setDialogState(() => saving = true);
                        final result =
                            await _service.saveQuestionTemplate(
                          id: existing?['id']?.toString(),
                          questionText: textCtrl.text,
                          questionType: type,
                          options: options,
                          isRequired: required,
                          helpText: helpCtrl.text,
                          sortOrder:
                              int.tryParse(existing?['sort_order']?.toString() ?? '') ??
                                  0,
                          templateKey: existing?['template_key']?.toString(),
                        );
                        if (!ctx.mounted) return;
                        setDialogState(() => saving = false);
                        if (result['success'] != true) {
                          _showMessage(
                            result['message']?.toString() ??
                                'Could not save the question.',
                            isError: true,
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? 'Save changes' : 'Add question'),
              ),
            ],
          );
        },
      ),
    );

    textCtrl.dispose();
    helpCtrl.dispose();
    optionsCtrl.dispose();
    if (saved == true) {
      _showMessage('Base question saved.');
      _load();
    }
  }

  Future<void> _toggle(Map<String, dynamic> template, bool active) async {
    final ok = await _service.setQuestionTemplateActive(
      template['id'].toString(),
      active,
    );
    if (!ok) {
      _showMessage('Could not update the question.', isError: true);
      return;
    }
    _load();
  }

  Future<void> _delete(Map<String, dynamic> template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete base question?'),
        content: Text(
          'Remove "${template['question_text']}" from the base list? '
          'Existing vacancy forms keep their snapshot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: RecruitmentColors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok =
        await _service.deleteQuestionTemplate(template['id'].toString());
    if (!ok) {
      _showMessage('Could not delete the question.', isError: true);
      return;
    }
    _showMessage('Base question deleted.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecruitmentColors.surface,
      appBar: recruitmentAppBar(
        'Base Question List',
        actions: [
          IconButton(
            tooltip: 'Add question',
            onPressed: _isAdmin ? () => _showEditor() : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: RecruitmentColors.blue),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
              children: [
                const RecruitmentHero(
                  eyebrow: 'Admin only',
                  title: 'Base application questions',
                  subtitle:
                      'These questions are offered to every new vacancy. Edit them here; each published vacancy keeps its own frozen copy.',
                  icon: Icons.quiz_outlined,
                ),
                const SizedBox(height: 14),
                if (!_isAdmin)
                  const RecruitmentNotice(
                    text:
                        'You can review the base questions, but only an administrator can edit them.',
                    icon: Icons.lock_outline_rounded,
                    color: RecruitmentColors.amber,
                  ),
                if (!_isAdmin) const SizedBox(height: 14),
                if (_templates.isEmpty)
                  RecruitmentEmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'No base questions yet',
                    subtitle:
                        'Add the questions every vacancy should start with.',
                    actionLabel: _isAdmin ? 'Add question' : null,
                    onAction: _isAdmin ? () => _showEditor() : null,
                  )
                else
                  ..._templates.map(_buildTemplateCard),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: RecruitmentColors.navy,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed:
                      _isAdmin ? () => _showEditor() : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add another base question'),
                ),
              ],
            ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final active = template['is_active'] != false;
    final type = template['question_type']?.toString() ?? 'short_answer';
    final options = template['options'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? RecruitmentColors.border : RecruitmentColors.slate,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (active ? RecruitmentColors.blue : RecruitmentColors.slate)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _iconForType(type),
              size: 18,
              color:
                  active ? RecruitmentColors.blue : RecruitmentColors.slate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template['question_text']?.toString() ?? 'Question',
                  style: kRecruitmentTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  '${SchoolRecruitmentService.questionTypeLabel(type)}'
                  '${template['is_required'] == true ? ' • Required' : ' • Optional'}'
                  '${active ? '' : ' • Disabled'}',
                  style: kRecruitmentCaption,
                ),
                if (options is List && options.isNotEmpty)
                  Text(
                    options.map((e) => e.toString()).join(' · '),
                    style: kRecruitmentCaption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Switch(
            value: active,
            onChanged: _isAdmin ? (v) => _toggle(template, v) : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
            onPressed: _isAdmin ? () => _showEditor(existing: template) : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete',
            onPressed: _isAdmin ? () => _delete(template) : null,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: RecruitmentColors.red,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'paragraph':
        return Icons.notes_rounded;
      case 'number':
        return Icons.pin_rounded;
      case 'date':
        return Icons.event_outlined;
      case 'multiple_choice':
      case 'checkboxes':
      case 'dropdown':
        return Icons.checklist_rounded;
      case 'yes_no':
        return Icons.toggle_on_outlined;
      case 'file_upload':
        return Icons.attach_file_rounded;
      default:
        return Icons.short_text_rounded;
    }
  }
}
