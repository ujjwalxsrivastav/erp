import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/entrance_exam_service.dart';
import '../../../services/entrance_test_service.dart';

/// Admin-authored entrance test builder.
///
/// One tab per subject — each subject page carries its own questions, mirroring
/// a Google-Form style flow. Every subject targets the fixed 50-mark weightage
/// (five 10-mark questions by default).
class EntranceTestBuilderDialog extends StatefulWidget {
  const EntranceTestBuilderDialog({
    super.key,
    required this.className,
    required this.subjects,
    required this.createdBy,
    this.existingTest,
    this.existingQuestions = const [],
  });

  final String className;
  final List<Map<String, dynamic>> subjects;
  final String createdBy;
  final Map<String, dynamic>? existingTest;
  final List<Map<String, dynamic>> existingQuestions;

  @override
  State<EntranceTestBuilderDialog> createState() =>
      _EntranceTestBuilderDialogState();
}

class _EntranceTestBuilderDialogState extends State<EntranceTestBuilderDialog>
    with SingleTickerProviderStateMixin {
  static const _ink = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  final _testService = EntranceTestService();
  final _examService = EntranceExamService();
  final _titleCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '90');

  late TabController _tabController;
  final List<String> _subjectNames = [];
  final Map<String, List<Map<String, dynamic>>> _bySubject = {};

  /// Catalog entries for the subjects currently in the builder, keyed by name.
  /// Preserves each subject's topics and id so the catalog can be re-persisted
  /// without losing customisations.
  final Map<String, Map<String, dynamic>> _subjectMeta = {};

  /// Subjects removed in this session, remembered so their catalog rows can be
  /// deleted when the test is saved.
  final Map<String, Map<String, dynamic>> _removedSubjects = {};

  bool _saving = false;
  bool _subjectsBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existingTitle = widget.existingTest?['title']?.toString() ?? '';
    _titleCtrl.text = existingTitle.isNotEmpty
        ? existingTitle
        : 'Entrance Test — ${widget.className}';
    _durationCtrl.text =
        (widget.existingTest?['duration_minutes'] ?? 90).toString();

    final names = <String>[];
    for (final s in widget.subjects) {
      final name = (s['subject'] ?? '').toString().trim();
      if (name.isNotEmpty && !names.contains(name)) {
        names.add(name);
        _subjectMeta[name] = Map<String, dynamic>.from(s);
      }
    }
    for (final q in widget.existingQuestions) {
      final name = (q['subject'] ?? '').toString().trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
    _subjectNames.addAll(names.isEmpty ? const ['General'] : names);

    for (final subject in _subjectNames) {
      _bySubject[subject] = widget.existingQuestions
          .where((q) => (q['subject'] ?? '').toString() == subject)
          .map((q) => <String, dynamic>{
                'subject': subject,
                'question': (q['question'] ?? q['question_text'] ?? '').toString(),
                'options': ((q['options'] as List?) ?? const [])
                    .map((o) => o?.toString() ?? '')
                    .toList(),
                'answer': (q['answer'] ?? q['correct_answer'] ?? '').toString(),
                'marks': (q['marks'] as num?)?.toInt() ?? 10,
              })
          .toList();
    }

    _tabController = TabController(length: _subjectNames.length, vsync: this);
  }

  /// Rebuilds the tab controller after the subject list changes, keeping the
  /// user on a sensible tab. The old controller is disposed after the frame so
  /// the visible TabBar/TabBarView are not using it while it is torn down.
  void _rebuildTabs({int? index}) {
    final old = _tabController;
    final length = _subjectNames.isEmpty ? 1 : _subjectNames.length;
    final safeIndex = (index ?? old.index).clamp(0, length - 1);
    _tabController =
        TabController(length: length, vsync: this, initialIndex: safeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  int _subjectTotal(String subject) => (_bySubject[subject] ?? const [])
      .fold<int>(0, (sum, q) => sum + ((q['marks'] as num?)?.toInt() ?? 10));

  int get _questionCount =>
      _bySubject.values.fold<int>(0, (sum, list) => sum + list.length);

  Future<void> _editQuestion(String subject, {int? index}) async {
    final existing = index != null ? _bySubject[subject]![index] : null;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _QuestionEditorDialog(
        subject: subject,
        existing: existing,
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _bySubject[subject]!.add(result);
      } else {
        _bySubject[subject]![index] = result;
      }
      _error = null;
    });
  }

  void _deleteQuestion(String subject, int index) {
    setState(() => _bySubject[subject]!.removeAt(index));
  }

  // ==========================================
  // SUBJECT MANAGEMENT
  // ==========================================

  static const _suggestedSubjects = [
    'Computer Science',
    'Hindi',
    'Sanskrit',
    'French',
    'General Knowledge',
    'Drawing',
    'Physical Education',
  ];

  /// Adds [rawName] as a new subject page. Returns an error message when the
  /// name is blank, duplicated, or otherwise rejected.
  Future<String?> _addSubject(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return 'Enter a subject name.';
    if (name.length > 40) return 'Keep the subject name under 40 characters.';
    if (_subjectNames.any((s) => s.toLowerCase() == name.toLowerCase())) {
      return '$name is already part of this test.';
    }

    setState(() {
      _subjectNames.add(name);
      _bySubject[name] = [];
      _subjectMeta[name] = {
        'id': '',
        'class_name': widget.className,
        'subject': name,
        'weightage': 50,
        'topics': const <String>[],
        'is_active': true,
      };
      _removedSubjects.removeWhere(
          (key, _) => key.toLowerCase() == name.toLowerCase());
      _rebuildTabs(index: _subjectNames.length - 1);
      _error = null;
    });
    return null;
  }

  /// Removes a subject page after confirmation. Its questions are dropped from
  /// the test and the catalog row is deleted when the test is saved.
  Future<String?> _removeSubject(String subject) async {
    if (_subjectNames.length <= 1) {
      return 'Keep at least one subject in the test.';
    }

    final questionCount = (_bySubject[subject] ?? const []).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $subject?',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
        content: Text(
          questionCount == 0
              ? 'This subject will be removed from ${widget.className} and from the test.'
              : 'This subject and its $questionCount question(s) will be removed from the test. '
                  'The subject is also removed from the ${widget.className} catalog when you save.',
          style: const TextStyle(fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;

    setState(() {
      _subjectNames.remove(subject);
      _bySubject.remove(subject);
      final meta = _subjectMeta.remove(subject);
      if (meta != null) {
        _removedSubjects[subject] = meta;
      } else {
        _removedSubjects[subject] = {'subject': subject};
      }
      _rebuildTabs();
      _error = null;
    });
    return null;
  }

  /// Panel for adding extra subjects and removing existing ones without
  /// leaving the builder. Works on the builder's live state so every change is
  /// reflected in the tabs immediately.
  Future<void> _openManageSubjects() async {
    final addCtrl = TextEditingController();
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          Future<void> addSubject([String? preset]) async {
            final error = await _addSubject(preset ?? addCtrl.text);
            if (!mounted || !ctx.mounted) return;
            setDState(() {
              dialogError = error;
              if (error == null) addCtrl.clear();
            });
          }

          Future<void> removeSubject(String subject) async {
            final error = await _removeSubject(subject);
            if (!mounted || !ctx.mounted) return;
            setDState(() => dialogError = error);
          }

          final suggestions = _suggestedSubjects
              .where((s) => !_subjectNames
                  .any((existing) => existing.toLowerCase() == s.toLowerCase()))
              .toList();

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 18, color: _blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Subjects • ${widget.className}',
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Each subject becomes its own page in the test. Add subjects beyond the default English, Mathematics, Science and Social Studies — or remove ones you do not need.',
                      style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: addCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'New subject',
                                hintText: 'e.g. Computer Science',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => addSubject(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => addSubject(),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestions
                            .map((s) => ActionChip(
                                  label: Text(s,
                                      style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => addSubject(s),
                                ))
                            .toList(),
                      ),
                    ],
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(dialogError!,
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFFDC2626))),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Subjects in this test',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _ink)),
                        const Spacer(),
                        Text('${_subjectNames.length}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _muted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._subjectNames.map((subject) {
                      final count = (_bySubject[subject] ?? const []).length;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book_rounded,
                                size: 15, color: _blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(subject,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155))),
                            ),
                            Text('$count Q',
                                style: const TextStyle(
                                    fontSize: 10.5, color: _muted)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Remove $subject',
                              onPressed: _subjectNames.length <= 1
                                  ? null
                                  : () => removeSubject(subject),
                              icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 17,
                                  color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done')),
            ],
          );
        },
      ),
    );
    addCtrl.dispose();
  }

  /// Persists the builder-level subject additions and removals into the class
  /// catalog so the rest of the entrance desk (offline marks, AI papers) sees
  /// the same subject list.
  Future<void> _persistCatalogChanges() async {
    if (_subjectsBusy) return;
    _subjectsBusy = true;
    try {
      for (final meta in _removedSubjects.values) {
        final id = meta['id']?.toString() ?? '';
        if (_looksLikeUuid(id)) {
          await _examService.deleteSubject(id);
        }
      }
      for (final name in _subjectNames) {
        final meta = _subjectMeta[name];
        final topics = ((meta?['topics'] as List?) ?? const [])
            .map((t) => t?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .toList();
        await _examService.saveSubject(
          className: widget.className,
          subject: name,
          topics: topics,
        );
      }
      _removedSubjects.clear();
    } catch (_) {
      // The catalog save is best-effort; the test itself still saves.
    } finally {
      _subjectsBusy = false;
    }
  }

  static bool _looksLikeUuid(String value) => RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      .hasMatch(value.trim());

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 90;
    if (title.isEmpty) {
      setState(() => _error = 'Give the test a title.');
      return;
    }
    if (_questionCount == 0) {
      setState(() => _error = 'Add at least one question.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    // Keep the class catalog in sync with any subjects added or removed in the
    // builder before saving the test itself.
    await _persistCatalogChanges();

    final questions = <Map<String, dynamic>>[];
    for (final subject in _subjectNames) {
      for (final q in _bySubject[subject] ?? const []) {
        questions.add({...q, 'subject': subject});
      }
    }

    try {
      await _testService.saveTest(
        testId: widget.existingTest?['id']?.toString(),
        className: widget.className,
        title: title,
        durationMinutes: duration.clamp(10, 240),
        questions: questions,
        createdBy: widget.createdBy,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The test could not be saved. Please try again.';
        });
      }
    }
  }

  Future<void> _deleteTest() async {
    final id = widget.existingTest?['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this test?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            'The test and all of its questions will be removed for ${widget.className}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _testService.deleteTest(id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: media.width < 1040 ? media.width * 0.95 : 1000,
        height: media.height < 820 ? media.height * 0.92 : 740,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _border),
            if (_subjectNames.isNotEmpty) _buildSubjectTabs(),
            Expanded(
              child: _subjectNames.isEmpty
                  ? const Center(
                      child: Text('Add subjects in the catalog first.',
                          style: TextStyle(fontSize: 12.5, color: _muted)),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children:
                          _subjectNames.map(_buildSubjectPage).toList(),
                    ),
            ),
            const Divider(height: 1, color: _border),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.quiz_rounded, color: _blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingTest == null
                      ? 'Create Entrance Test • ${widget.className}'
                      : 'Edit Entrance Test • ${widget.className}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                ),
                const SizedBox(height: 2),
                const Text(
                  'One page per subject. Add or remove subjects with the Subjects button. Questions are objective with 4 options; five 10-mark questions make the fixed 50-mark subject weightage.',
                  style: TextStyle(fontSize: 11.5, color: _muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Test title',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTabs() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _blue,
              unselectedLabelColor: _muted,
              indicatorColor: _blue,
              indicatorWeight: 2.5,
              labelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              tabs: _subjectNames
                  .map((s) => Tab(
                        text: '${s} (${(_bySubject[s] ?? const []).length})',
                      ))
                  .toList(),
            ),
          ),
          Container(
            height: 34,
            margin: const EdgeInsets.only(right: 10, left: 4),
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _openManageSubjects,
              icon: const Icon(Icons.tune_rounded, size: 15),
              label: const Text('Subjects',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPage(String subject) {
    final questions = _bySubject[subject] ?? const <Map<String, dynamic>>[];
    final total = _subjectTotal(subject);
    final totalOk = total == 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              Flexible(
                child: Text(subject,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _ink)),
              ),
              const SizedBox(width: 8),
              _pill('50 marks', const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
              const SizedBox(width: 6),
              _pill('Total $total / 50',
                  totalOk ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  totalOk ? const Color(0xFF047857) : const Color(0xFFB45309)),
              const Spacer(),
              IconButton(
                tooltip: 'Remove $subject',
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed:
                    _saving ? null : () => _removeSubject(subject),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: Color(0xFFDC2626)),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () => _editQuestion(subject),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Question',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.post_add_rounded,
                          size: 34, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 8),
                      Text('No questions for $subject yet.',
                          style: const TextStyle(
                              fontSize: 12.5, color: _muted)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _editQuestion(subject),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add the first question'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    final options = ((q['options'] as List?) ?? const [])
                        .map((o) => o?.toString() ?? '')
                        .toList();
                    final correct =
                        int.tryParse((q['answer'] ?? '').toString()) ?? -1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Q${index + 1}.',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: _blue)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  (q['question'] ?? '').toString(),
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                      height: 1.35),
                                ),
                              ),
                              _pill('${q['marks'] ?? 10} marks',
                                  const Color(0xFFF1F5F9), _muted),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _editQuestion(subject, index: index),
                                icon: const Icon(Icons.edit_rounded,
                                    size: 16, color: _muted),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _deleteQuestion(subject, index),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                          if (options.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: options.asMap().entries.map((entry) {
                                final isCorrect = entry.key == correct;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                        color: isCorrect
                                            ? const Color(0xFFA7F3D0)
                                            : _border),
                                  ),
                                  child: Text(
                                    '${String.fromCharCode(65 + entry.key)}. ${entry.value}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isCorrect
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isCorrect
                                          ? const Color(0xFF047857)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
      child: Row(
        children: [
          if (_error != null)
            Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFFDC2626))),
            )
          else
            Expanded(
              child: Text(
                '$_questionCount question(s) • ${_subjectNames.length} subject page(s)',
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
            ),
          if (widget.existingTest != null)
            TextButton.icon(
              onPressed: _saving ? null : _deleteTest,
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Delete Test'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626)),
            ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.publish_rounded, size: 16),
            label: Text(_saving ? 'Publishing…' : 'Save & Publish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foreground)),
    );
  }
}

/// Small editor for one MCQ.
class _QuestionEditorDialog extends StatefulWidget {
  const _QuestionEditorDialog({required this.subject, this.existing});

  final String subject;
  final Map<String, dynamic>? existing;

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  final _questionCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '10');
  final List<TextEditingController> _optionCtrls =
      List.generate(4, (_) => TextEditingController());
  int _correct = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _questionCtrl.text = (existing['question'] ?? '').toString();
      _marksCtrl.text = (existing['marks'] ?? 10).toString();
      final options = ((existing['options'] as List?) ?? const [])
          .map((o) => o?.toString() ?? '')
          .toList();
      for (var i = 0; i < _optionCtrls.length; i++) {
        if (i < options.length) _optionCtrls[i].text = options[i];
      }
      _correct = int.tryParse((existing['answer'] ?? '').toString()) ?? 0;
      if (_correct < 0 || _correct > 3) _correct = 0;
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _marksCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'Enter the question text.');
      return;
    }
    final rawOptions =
        _optionCtrls.map((c) => c.text.trim()).toList();
    if (rawOptions[_correct].isEmpty) {
      setState(() =>
          _error = 'The selected correct option has no text.');
      return;
    }
    // Compute the index within the filtered list so a blank option slot does
    // not shift the stored answer key.
    final correctIndex =
        rawOptions.take(_correct).where((o) => o.isNotEmpty).length;
    final options =
        rawOptions.where((o) => o.isNotEmpty).toList();
    if (options.length < 2) {
      setState(() => _error = 'Provide at least two options.');
      return;
    }
    final marks = int.tryParse(_marksCtrl.text.trim()) ?? 10;
    Navigator.pop(context, <String, dynamic>{
      'subject': widget.subject,
      'question': question,
      'options': options,
      'answer': correctIndex.toString(),
      'marks': marks.clamp(1, 50),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add Question • ${widget.subject}'
            : 'Edit Question • ${widget.subject}',
        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _questionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _correct = i),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _correct == i
                                ? const Color(0xFF2563EB)
                                : Colors.white,
                            border: Border.all(
                                color: _correct == i
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFCBD5E1)),
                          ),
                          child: _correct == i
                              ? const Icon(Icons.check_rounded,
                                  size: 13, color: Colors.white)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _optionCtrls[i],
                          decoration: InputDecoration(
                            labelText:
                                'Option ${String.fromCharCode(65 + i)}',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Text(
                'Tap the circle next to the correct option.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _marksCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Marks',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white),
          child: Text(widget.existing == null ? 'Add Question' : 'Save'),
        ),
      ],
    );
  }
}
