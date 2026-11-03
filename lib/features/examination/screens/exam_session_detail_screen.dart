import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/examination_service.dart';

/// Detail view for one exam session with three sections:
/// Subjects (date-sheet), Registrations (verify / hall ticket)
/// and an Eligibility summary for the session semester.
class ExamSessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const ExamSessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<ExamSessionDetailScreen> createState() =>
      _ExamSessionDetailScreenState();
}

class _ExamSessionDetailScreenState extends State<ExamSessionDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = ExaminationService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _eligibility = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final subjects = await _service.getSessionSubjects(widget.sessionId);
    final registrations = await _service.getRegistrations(widget.sessionId);
    final eligibility = await _service.getEligibleStudents(widget.sessionId);
    if (mounted) {
      setState(() {
        _subjects = subjects;
        _registrations = registrations;
        _eligibility = eligibility;
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
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.adminPrimary,
                unselectedLabelColor: AppTheme.mediumGray,
                indicatorColor: AppTheme.adminPrimary,
                tabs: const [
                  Tab(icon: Icon(Icons.menu_book_outlined), text: 'Subjects'),
                  Tab(
                      icon: Icon(Icons.app_registration),
                      text: 'Registrations'),
                  Tab(icon: Icon(Icons.verified_user), text: 'Eligibility'),
                ],
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.adminPrimary))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSubjectsTab(),
                          _buildRegistrationsTab(),
                          _buildEligibilityTab(),
                        ],
                      ),
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
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.sessionName,
                    style: AppTheme.h4.copyWith(color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${_subjects.length} subjects • ${_registrations.length} registrations',
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

  // ------------------------------------------------------------
  // SUBJECTS TAB
  // ------------------------------------------------------------
  Widget _buildSubjectsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: GradientButton(
            text: 'Add Subject Paper',
            gradient: AppTheme.adminGradient,
            icon: Icons.add,
            height: 48,
            onPressed: _showAddSubjectDialog,
          ),
        ),
        Expanded(
          child: _subjects.isEmpty
              ? _emptyState(Icons.menu_book_outlined,
                  'No papers scheduled yet. Add subject papers with exam date, room and passing marks.')
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _subjects.length,
                  itemBuilder: (context, i) => _buildSubjectCard(_subjects[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.adminPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book,
                  color: AppTheme.adminPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['subject_name']?.toString() ?? 'Subject',
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.dark, fontWeight: FontWeight.w600)),
                  Text(
                    '${s['subject_id'] ?? '-'} • ${s['exam_date'] ?? 'Date TBA'} • ${s['start_time'] ?? ''} - ${s['end_time'] ?? ''}',
                    style:
                        AppTheme.caption.copyWith(color: AppTheme.mediumGray),
                  ),
                  Text(
                    'Max ${s['max_marks'] ?? 100} • Pass ${s['passing_marks'] ?? 40}${s['room'] != null ? ' • Room ${s['room']}' : ''}',
                    style:
                        AppTheme.caption.copyWith(color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: () async {
                final ok =
                    await _service.deleteSessionSubject(s['id'].toString());
                if (ok) {
                  _snack('Subject removed');
                  _load();
                } else {
                  _snack('Could not remove subject', error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSubjectDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '100');
    final passCtrl = TextEditingController(text: '40');
    final roomCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '10:00 AM');
    final endCtrl = TextEditingController(text: '01:00 PM');
    final master = await _service.getSubjectsMaster();
    if (!mounted) return;
    Map<String, dynamic>? selected;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Subject Paper'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (master.isNotEmpty) ...[
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Pick from Subjects Master'),
                        items: master
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                      '${m['subject_name']} (${m['subject_id']})',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            selected = v;
                            if (v != null) {
                              nameCtrl.text =
                                  v['subject_name']?.toString() ?? '';
                              idCtrl.text = v['subject_id']?.toString() ?? '';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Subject Name *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Subject name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: idCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Subject Code / ID',
                          hintText: 'e.g. CS501'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: dateCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Exam Date',
                        suffixIcon:
                            Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          dateCtrl.text =
                              picked.toIso8601String().split('T')[0];
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Start Time'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endCtrl,
                            decoration:
                                const InputDecoration(labelText: 'End Time'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Max Marks *'),
                            validator: (v) =>
                                double.tryParse(v ?? '') == null
                                    ? 'Enter a number'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: passCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Passing Marks *'),
                            validator: (v) =>
                                double.tryParse(v ?? '') == null
                                    ? 'Enter a number'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: roomCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Room', hintText: 'e.g. Room 301'),
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
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final ok = await _service.addSessionSubject(
                    sessionId: widget.sessionId,
                    subjectName: nameCtrl.text.trim(),
                    subjectId:
                        idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
                    examDate: dateCtrl.text.isEmpty ? null : dateCtrl.text,
                    startTime: startCtrl.text.trim().isEmpty
                        ? null
                        : startCtrl.text.trim(),
                    endTime: endCtrl.text.trim().isEmpty
                        ? null
                        : endCtrl.text.trim(),
                    maxMarks: double.tryParse(maxCtrl.text) ?? 100,
                    passingMarks: double.tryParse(passCtrl.text) ?? 40,
                    room: roomCtrl.text.trim().isEmpty
                        ? null
                        : roomCtrl.text.trim(),
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (ok) {
                    _snack('Subject paper added');
                    _load();
                  } else {
                    _snack('Could not add subject', error: true);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  // ------------------------------------------------------------
  // REGISTRATIONS TAB
  // ------------------------------------------------------------
  Widget _buildRegistrationsTab() {
    if (_registrations.isEmpty) {
      return _emptyState(Icons.app_registration,
          'No registrations yet. Students appear here once their exam forms are registered for this session.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _registrations.length,
      itemBuilder: (context, i) => _buildRegistrationCard(_registrations[i]),
    );
  }

  Widget _buildRegistrationCard(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'applied';
    final eligibility = r['eligibility_status']?.toString() ?? 'eligible';
    final subjects = (r['subjects'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.adminPrimary.withOpacity(0.12),
                  child: const Icon(Icons.person,
                      color: AppTheme.adminPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['student_id']?.toString() ?? '-',
                          style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.dark,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${subjects.length} paper(s) • Fee ${r['fee_paid'] == true ? 'Paid' : 'Pending'}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                _chip(status.replaceAll('_', ' ').toUpperCase(),
                    status == 'hall_ticket_issued'
                        ? AppTheme.success
                        : status == 'verified'
                            ? AppTheme.info
                            : AppTheme.warning),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  eligibility == 'eligible'
                      ? Icons.check_circle
                      : eligibility == 'detained'
                          ? Icons.block
                          : Icons.warning_amber,
                  size: 16,
                  color: eligibility == 'eligible'
                      ? AppTheme.success
                      : eligibility == 'detained'
                          ? AppTheme.error
                          : AppTheme.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    eligibility == 'eligible'
                        ? 'Eligible'
                        : '${eligibility[0].toUpperCase()}${eligibility.substring(1)}${r['detention_reason'] != null ? ' — ${r['detention_reason']}' : ''}',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.mediumGray),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'applied')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Verify'),
                    onPressed: () async {
                      final ok = await _service
                          .verifyRegistration(r['id'].toString());
                      if (ok) {
                        _snack('Registration verified');
                        _load();
                      } else {
                        _snack('Could not verify', error: true);
                      }
                    },
                  ),
                if (status == 'verified')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.badge, size: 16),
                    label: const Text('Issue Hall Ticket'),
                    onPressed: () async {
                      final ticket =
                          await _service.issueHallTicket(r['id'].toString());
                      if (ticket != null) {
                        _snack('Hall ticket ${ticket['ticket_no']} issued');
                        _load();
                      } else {
                        _snack('Could not issue hall ticket', error: true);
                      }
                    },
                  ),
                if (status == 'hall_ticket_issued')
                  const Chip(
                    avatar: Icon(Icons.check, size: 16),
                    label: Text('Hall Ticket Issued'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ELIGIBILITY TAB
  // ------------------------------------------------------------
  Widget _buildEligibilityTab() {
    if (_eligibility.isEmpty) {
      return _emptyState(Icons.verified_user_outlined,
          'No students found for this session semester in student_details.');
    }
    final eligible =
        _eligibility.where((e) => e['eligibility_status'] == 'eligible').length;
    final conditional = _eligibility
        .where((e) => e['eligibility_status'] == 'conditional')
        .length;
    final detained =
        _eligibility.where((e) => e['eligibility_status'] == 'detained').length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Row(
            children: [
              Expanded(
                  child: _summaryBox(
                      'Eligible', eligible, AppTheme.success)),
              const SizedBox(width: 12),
              Expanded(
                  child: _summaryBox(
                      'Conditional', conditional, AppTheme.warning)),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _summaryBox('Detained', detained, AppTheme.error)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _eligibility.length,
            itemBuilder: (context, i) {
              final e = _eligibility[i];
              final status = e['eligibility_status']?.toString() ?? 'eligible';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        status == 'eligible'
                            ? Icons.check_circle
                            : status == 'detained'
                                ? Icons.block
                                : Icons.warning_amber,
                        color: status == 'eligible'
                            ? AppTheme.success
                            : status == 'detained'
                                ? AppTheme.error
                                : AppTheme.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e['name'] ?? e['student_id']} (${e['student_id']})',
                              style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.dark,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${e['department'] ?? ''} • Sec ${e['section'] ?? '-'} • Reg: ${e['registration_status'] ?? 'not registered'}',
                              style: AppTheme.caption
                                  .copyWith(color: AppTheme.mediumGray),
                            ),
                            if (e['detention_reason'] != null)
                              Text(
                                e['detention_reason'].toString(),
                                style: AppTheme.caption
                                    .copyWith(color: AppTheme.error),
                              ),
                          ],
                        ),
                      ),
                      if ((e['dues_balance'] as num? ?? 0) > 0)
                        _chip(
                            'Dues ₹${(e['dues_balance'] as num).toStringAsFixed(0)}',
                            AppTheme.error),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryBox(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: AppTheme.h4.copyWith(color: color)),
          Text(label,
              style: AppTheme.caption.copyWith(color: AppTheme.mediumGray)),
        ],
      ),
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

  Widget _emptyState(IconData icon, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppTheme.lightGray),
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
