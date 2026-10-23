import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/examination_service.dart';
import 'exam_session_detail_screen.dart';

/// Lists all exam sessions and lets the COE create new ones and
/// move them through draft -> published -> conducted -> result_declared.
class ExamSessionsScreen extends StatefulWidget {
  const ExamSessionsScreen({super.key});

  @override
  State<ExamSessionsScreen> createState() => _ExamSessionsScreenState();
}

class _ExamSessionsScreenState extends State<ExamSessionsScreen> {
  final _service = ExaminationService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final sessions = await _service.getSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
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

  Future<void> _changeStatus(Map<String, dynamic> session, String status) async {
    final ok = await _service.updateSessionStatus(session['id'].toString(), status);
    if (ok) {
      _snack('Session marked as ${status.replaceAll('_', ' ')}');
      _load();
    } else {
      _snack('Could not update session status', error: true);
    }
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
                    : _sessions.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppTheme.adminPrimary,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: _sessions.length,
                              itemBuilder: (context, i) =>
                                  _buildSessionCard(_sessions[i]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.adminPrimary,
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Session',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exam Sessions',
                    style: AppTheme.h3.copyWith(color: Colors.white)),
                Text(
                  '${_sessions.length} session(s) • tap a session to manage it',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined,
                size: 64, color: AppTheme.lightGray),
            const SizedBox(height: 16),
            Text('No exam sessions yet',
                style: AppTheme.h5.copyWith(color: AppTheme.dark)),
            const SizedBox(height: 8),
            Text(
              'Create the first session (e.g. End Semester 2026) to open exam forms, schedule papers and declare results.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> s) {
    final status = s['status']?.toString() ?? 'draft';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExamSessionDetailScreen(
              sessionId: s['id'].toString(),
              sessionName: s['name']?.toString() ?? 'Session',
            ),
          ));
          _load();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_note,
                      color: AppTheme.adminPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name']?.toString() ?? 'Session',
                          style: AppTheme.h5.copyWith(color: AppTheme.dark)),
                      Text(
                        '${s['academic_year'] ?? ''} • Semester ${s['semester'] ?? '-'}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.mediumGray),
                  onSelected: (v) => _changeStatus(s, v),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: 'published', child: Text('Mark Published')),
                    PopupMenuItem(
                        value: 'conducted', child: Text('Mark Conducted')),
                    PopupMenuItem(
                        value: 'draft', child: Text('Move to Draft')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _meta(Icons.category_outlined,
                    (s['exam_type'] ?? 'regular').toString().toUpperCase()),
                if (s['start_date'] != null)
                  _meta(Icons.calendar_today_outlined,
                      '${s['start_date']} to ${s['end_date'] ?? ''}'),
                if (s['form_close_date'] != null)
                  _meta(Icons.assignment_outlined,
                      'Form closes ${s['form_close_date']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.adminSecondary),
        const SizedBox(width: 6),
        Text(text,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray)),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'published':
        color = AppTheme.info;
        break;
      case 'conducted':
        color = AppTheme.warning;
        break;
      case 'result_declared':
        color = AppTheme.success;
        break;
      default:
        color = AppTheme.lightGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.replaceAll('_', ' ').toUpperCase(),
          style: AppTheme.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ------------------------------------------------------------
  // CREATE SESSION FORM
  // ------------------------------------------------------------
  Future<void> _showCreateDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final yearCtrl =
        TextEditingController(text: '${DateTime.now().year}-${(DateTime.now().year + 1).toString().substring(2)}');
    final semesterCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final formOpenCtrl = TextEditingController();
    final formCloseCtrl = TextEditingController();
    String examType = 'regular';
    bool saving = false;

    Future<void> pickDate(TextEditingController ctrl) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked != null) {
        ctrl.text = picked.toIso8601String().split('T')[0];
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create Exam Session'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Session Name *',
                          hintText: 'e.g. End Semester Dec 2026'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Session name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: yearCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Academic Year *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Academic year is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: examType,
                      decoration:
                          const InputDecoration(labelText: 'Exam Type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'regular', child: Text('Regular')),
                        DropdownMenuItem(
                            value: 'backlog', child: Text('Backlog')),
                        DropdownMenuItem(
                            value: 'supplementary',
                            child: Text('Supplementary')),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => examType = v ?? 'regular'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: semesterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Semester', hintText: 'e.g. 5'),
                    ),
                    const SizedBox(height: 12),
                    _dateField(startCtrl, 'Exam Start Date', pickDate),
                    const SizedBox(height: 12),
                    _dateField(endCtrl, 'Exam End Date', pickDate),
                    const SizedBox(height: 12),
                    _dateField(formOpenCtrl, 'Form Open Date', pickDate),
                    const SizedBox(height: 12),
                    _dateField(formCloseCtrl, 'Form Close Date', pickDate),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              SizedBox(
                width: 140,
                child: GradientButton(
                  text: 'Create',
                  gradient: AppTheme.adminGradient,
                  height: 44,
                  isLoading: saving,
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setDialogState(() => saving = true);
                    final ok = await _service.createSession({
                      'name': nameCtrl.text.trim(),
                      'academic_year': yearCtrl.text.trim(),
                      'exam_type': examType,
                      'semester': int.tryParse(semesterCtrl.text.trim()),
                      'start_date':
                          startCtrl.text.isEmpty ? null : startCtrl.text,
                      'end_date': endCtrl.text.isEmpty ? null : endCtrl.text,
                      'form_open_date':
                          formOpenCtrl.text.isEmpty ? null : formOpenCtrl.text,
                      'form_close_date': formCloseCtrl.text.isEmpty
                          ? null
                          : formCloseCtrl.text,
                      'status': 'draft',
                    });
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (ok) {
                      _snack('Exam session created');
                      _load();
                    } else {
                      _snack('Could not create session', error: true);
                    }
                  },
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _dateField(TextEditingController ctrl, String label,
      Future<void> Function(TextEditingController) pick) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      onTap: () => pick(ctrl),
    );
  }
}
