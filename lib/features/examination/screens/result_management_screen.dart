import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/examination_service.dart';

/// COE result desk: pick a session, enter results paper-wise,
/// optionally import from student_marks, and publish the result.
class ResultManagementScreen extends StatefulWidget {
  const ResultManagementScreen({super.key});

  @override
  State<ResultManagementScreen> createState() =>
      _ResultManagementScreenState();
}

class _ResultManagementScreenState extends State<ResultManagementScreen> {
  final _service = ExaminationService();
  bool _isLoading = true;
  bool _isPublishing = false;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedSession;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final sessions = await _service.getSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSession(Map<String, dynamic> session) async {
    setState(() {
      _selectedSession = session;
      _isLoading = true;
    });
    final results =
        await _service.getSessionResults(session['id'].toString());
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.adminPrimary))
                    : _selectedSession == null
                        ? _buildSessionPicker()
                        : _buildResultsView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.adminGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_selectedSession != null) {
                setState(() => _selectedSession = null);
                _loadSessions();
              } else {
                context.pop();
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Result Management',
                    style: AppTheme.h4.copyWith(color: Colors.white)),
                Text(
                  _selectedSession?['name']?.toString() ??
                      'Select a session to manage its results',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white.withOpacity(0.9)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPicker() {
    if (_sessions.isEmpty) {
      return _emptyState(
          'No sessions found. Create an exam session first.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _sessions.length,
      itemBuilder: (context, i) {
        final s = _sessions[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            onTap: () => _selectSession(s),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.grading,
                      color: AppTheme.adminPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name']?.toString() ?? 'Session',
                          style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.dark,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${s['academic_year'] ?? ''} • Sem ${s['semester'] ?? '-'} • ${(s['status'] ?? '').toString().replaceAll('_', ' ')}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: AppTheme.lightGray),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsView() {
    final session = _selectedSession!;
    final declared = session['status'] == 'result_declared';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Column(
            children: [
              GradientButton(
                text: 'Enter Result',
                gradient: AppTheme.adminGradient,
                icon: Icons.add,
                height: 48,
                onPressed: _showEnterResultDialog,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Import from Marks'),
                      onPressed: () async {
                        final count = await _service.importResultsFromMarks(
                            session['id'].toString());
                        _snack(count > 0
                            ? '$count result(s) imported from student marks'
                            : 'No marks found to import for session papers');
                        if (count > 0) _selectSession(session);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.publish, size: 18),
                      label:
                          Text(declared ? 'Result Published' : 'Publish Result'),
                      onPressed: declared || _results.isEmpty || _isPublishing
                          ? null
                          : _publish,
                    ),
                  ),
                ],
              ),
              if (declared)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Results for this session are published and visible to students.',
                    style: AppTheme.caption.copyWith(color: AppTheme.success),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? _emptyState(
                  'No results entered yet for this session. Use "Enter Result" or import from marks.')
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _results.length,
                  itemBuilder: (context, i) => _buildResultCard(_results[i]),
                ),
        ),
      ],
    );
  }

  Future<void> _publish() async {
    setState(() => _isPublishing = true);
    final ok =
        await _service.publishResults(_selectedSession!['id'].toString());
    if (mounted) {
      setState(() => _isPublishing = false);
      if (ok) {
        _snack('Results published — students can now see them');
        final updated = Map<String, dynamic>.from(_selectedSession!);
        updated['status'] = 'result_declared';
        _selectedSession = updated;
      } else {
        _snack('Could not publish results', error: true);
      }
    }
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final passed = r['status'] == 'pass';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (passed ? AppTheme.success : AppTheme.error)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                r['grade']?.toString() ?? '-',
                style: AppTheme.bodyMedium.copyWith(
                  color: passed ? AppTheme.success : AppTheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['student_id']} • ${r['subject_name'] ?? r['subject_id'] ?? ''}',
                    style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.dark, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Int ${r['internal_marks']} + Ext ${r['external_marks']} = ${r['total']} • GP ${r['grade_point']} • ${r['is_published'] == true ? 'Published' : 'Draft'}',
                    style: AppTheme.caption
                        .copyWith(color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
            _chip(passed ? 'PASS' : 'FAIL',
                passed ? AppTheme.success : AppTheme.error),
          ],
        ),
      ),
    );
  }

  Future<void> _showEnterResultDialog() async {
    final session = _selectedSession!;
    final subjects =
        await _service.getSessionSubjects(session['id'].toString());
    if (!mounted) return;
    final formKey = GlobalKey<FormState>();
    final studentCtrl = TextEditingController();
    final internalCtrl = TextEditingController(text: '0');
    final externalCtrl = TextEditingController(text: '0');
    Map<String, dynamic>? selectedSubject =
        subjects.isNotEmpty ? subjects.first : null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Enter Result'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: studentCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Student ID / Username *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Student ID is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (subjects.isNotEmpty)
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedSubject,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Subject Paper'),
                        items: subjects
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                      s['subject_name']?.toString() ??
                                          'Subject',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedSubject = v),
                      )
                    else
                      const Text(
                          'No papers in this session — add subjects first from the session detail screen.'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: internalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Internal Marks *'),
                            validator: (v) =>
                                double.tryParse(v ?? '') == null
                                    ? 'Enter a number'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: externalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'External Marks *'),
                            validator: (v) =>
                                double.tryParse(v ?? '') == null
                                    ? 'Enter a number'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: subjects.isEmpty
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final sub = selectedSubject!;
                        final ok = await _service.enterResult(
                          sessionId: session['id'].toString(),
                          studentId: studentCtrl.text.trim(),
                          subjectId: sub['subject_id']?.toString(),
                          subjectName: sub['subject_name']?.toString(),
                          internalMarks:
                              double.tryParse(internalCtrl.text) ?? 0,
                          externalMarks:
                              double.tryParse(externalCtrl.text) ?? 0,
                          maxMarks:
                              (sub['max_marks'] as num?)?.toDouble() ?? 100,
                          passingMarks:
                              (sub['passing_marks'] as num?)?.toDouble() ??
                                  40,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (ok) {
                          _snack('Result saved');
                          _selectSession(session);
                        } else {
                          _snack('Could not save result', error: true);
                        }
                      },
                child: const Text('Save Result'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: AppTheme.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grading_outlined, size: 56, color: AppTheme.lightGray),
            const SizedBox(height: 14),
            Text(msg,
                textAlign: TextAlign.center,
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray)),
          ],
        ),
      ),
    );
  }
}
