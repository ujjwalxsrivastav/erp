import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/auth_service.dart';
import '../services/school_recruitment_service.dart'
    show SchoolRecruitmentService;
import '../widgets/recruitment_widgets.dart';

/// Admin interview board for a single application.
///
/// Lets the admin schedule interview rounds, record marks/feedback/recommendation,
/// and move the candidate to selected/rejected.
class SchoolInterviewBoardScreen extends StatefulWidget {
  final String applicationId;

  const SchoolInterviewBoardScreen({super.key, required this.applicationId});

  @override
  State<SchoolInterviewBoardScreen> createState() => _SchoolInterviewBoardScreenState();
}

class _SchoolInterviewBoardScreenState extends State<SchoolInterviewBoardScreen> {
  final _service = SchoolRecruitmentService();
  final _authService = AuthService();

  Map<String, dynamic>? _application;
  List<Map<String, dynamic>> _interviews = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _applicantName = '';
  String _appStatus = '';

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
      setState(() {
        _isAdmin = SchoolRecruitmentService.isAdminRole(role);
        _application = app;
        _applicantName = app['applicant_name']?.toString() ?? 'Unknown';
        _appStatus = app['status']?.toString() ?? 'applied';
        final interviews = app['school_vacancy_interviews'];
        _interviews = interviews is List
            ? interviews.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    showRecruitmentMessage(context, message, isError: isError);
  }

  Future<void> _scheduleInterview() async {
    if (!_isAdmin) {
      _showMessage('Only administrators can schedule interviews.', isError: true);
      return;
    }
    final app = _application;
    if (app == null) return;
    if (app['document_status'] != 'verified') {
      _showMessage('Verify all documents before scheduling an interview.', isError: true);
      return;
    }

    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final panelCtrl = TextEditingController();
    String mode = 'in_person';

    final scheduled = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule interview'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: recruitmentFieldDecoration('Mode'),
                  items: const [
                    DropdownMenuItem(value: 'in_person', child: Text('In person')),
                    DropdownMenuItem(value: 'video', child: Text('Video call')),
                    DropdownMenuItem(value: 'phone', child: Text('Phone')),
                  ],
                  onChanged: (v) => mode = v ?? 'in_person',
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 2)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null && ctx.mounted) {
                      dateCtrl.text = DateFormat('dd MMM yyyy').format(picked);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: dateCtrl,
                      decoration: recruitmentFieldDecoration('Date *', icon: Icons.event_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (picked != null && ctx.mounted) {
                      timeCtrl.text = picked.format(ctx);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: timeCtrl,
                      decoration: recruitmentFieldDecoration('Time *', icon: Icons.access_time_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (mode == 'in_person')
                  TextField(
                    controller: venueCtrl,
                    decoration: recruitmentFieldDecoration('Venue', icon: Icons.location_on_outlined),
                  ),
                if (mode == 'video')
                  TextField(
                    controller: linkCtrl,
                    decoration: recruitmentFieldDecoration('Meeting link', icon: Icons.video_call_outlined),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: panelCtrl,
                  decoration: recruitmentFieldDecoration(
                    'Panel members (comma separated)',
                    icon: Icons.people_alt_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.blue),
            onPressed: () {
              if (dateCtrl.text.isEmpty || timeCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Date and time are required.')),
                );
                return;
              }
              final dateStr = dateCtrl.text;
              final timeStr = timeCtrl.text;
              DateTime? dt;
              try {
                final dateParts = dateStr.split(' ');
                final day = int.parse(dateParts[0]);
                final month = _monthNumber(dateParts[1]);
                final year = int.parse(dateParts[2]);
                final timeParts = timeStr.split(':');
                final hour = int.parse(timeParts[0]);
                final minute = int.parse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), ''));
                dt = DateTime(year, month, day, hour, minute);
              } catch (_) {
                dt = DateTime.now().add(const Duration(days: 1));
              }
              Navigator.pop(ctx, dt);
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );

    if (scheduled == null) return;

    final panel = panelCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final result = await _service.scheduleInterview(
      applicationId: widget.applicationId,
      scheduledAt: scheduled,
      mode: mode,
      venue: venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
      meetingLink: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
      panelMembers: panel,
    );

    if (!mounted) return;
    if (result['success'] != true) {
      _showMessage(result['message']?.toString() ?? 'Could not schedule interview.', isError: true);
      return;
    }
    _showMessage('Interview scheduled.');
    _load();
  }

  int _monthNumber(String m) {
    const map = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return map[m] ?? 1;
  }

  Future<void> _completeInterview(Map<String, dynamic> interview) async {
    if (!_isAdmin) {
      _showMessage('Only administrators can complete interviews.', isError: true);
      return;
    }

    final marksCtrl = TextEditingController();
    final feedbackCtrl = TextEditingController();
    String? recommendation;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Complete round ${interview['round_no'] ?? 1}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: marksCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: recruitmentFieldDecoration('Marks (0-100)', icon: Icons.grade_rounded),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: recommendation,
                    decoration: recruitmentFieldDecoration('Recommendation'),
                    items: const [
                      DropdownMenuItem(value: 'strong_yes', child: Text('Strong yes')),
                      DropdownMenuItem(value: 'yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'no', child: Text('No')),
                      DropdownMenuItem(value: 'strong_no', child: Text('Strong no')),
                    ],
                    onChanged: (v) => setDialogState(() => recommendation = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 4,
                    decoration: recruitmentFieldDecoration('Feedback'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete round'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final ok = await _service.completeInterview(
      interview['id'].toString(),
      marks: double.tryParse(marksCtrl.text),
      feedback: feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim(),
      recommendation: recommendation,
    );
    if (!mounted) return;
    if (ok) {
      _showMessage('Interview round completed.');
      _load();
    } else {
      _showMessage('Could not complete interview.', isError: true);
    }
  }

  Future<void> _cancelInterview(Map<String, dynamic> interview) async {
    if (!_isAdmin) {
      _showMessage('Only administrators can cancel interviews.', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel interview?'),
        content: const Text('This will cancel the scheduled interview and move the candidate back to document-verified status.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel interview'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _service.cancelInterview(interview['id'].toString());
    if (!mounted) return;
    if (ok) {
      _showMessage('Interview cancelled.');
      _load();
    } else {
      _showMessage('Could not cancel interview.', isError: true);
    }
  }

  Future<void> _selectCandidate() async {
    if (!_isAdmin) return;
    final ok = await _service.selectApplication(widget.applicationId);
    if (ok) {
      _showMessage('Candidate selected!');
      _load();
    } else {
      _showMessage('Could not select candidate.', isError: true);
    }
  }

  Future<void> _rejectCandidate() async {
    if (!_isAdmin) return;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject candidate'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: recruitmentFieldDecoration('Reason (required)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.red),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reason is required.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _service.rejectApplication(widget.applicationId, reasonCtrl.text);
    if (ok) {
      _showMessage('Candidate rejected.');
      _load();
    } else {
      _showMessage('Could not reject candidate.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: RecruitmentColors.surface,
        appBar: recruitmentAppBar('Interview'),
        body: const Center(child: CircularProgressIndicator(color: RecruitmentColors.blue)),
      );
    }

    if (_application == null) {
      return Scaffold(
        backgroundColor: RecruitmentColors.surface,
        appBar: recruitmentAppBar('Interview'),
        body: const Center(child: Text('Application not found.')),
      );
    }

    return Scaffold(
      backgroundColor: RecruitmentColors.surface,
      appBar: recruitmentAppBar(
        'Interview: $_applicantName',
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
          : _buildBoard(),
    );
  }

  Widget _buildAccessDenied() {
    return const Center(child: Text('Administrator access required.'));
  }

  Widget _buildBoard() {
    final allCompleted = _interviews.isNotEmpty && _interviews.every((i) => i['status'] == 'completed');

    return RecruitmentBody(children: [
      RecruitmentHero(
        eyebrow: 'Applicant: $_applicantName',
        title: 'Interview board',
        subtitle: 'Schedule rounds, record marks/feedback, and decide the outcome.',
        icon: Icons.event_available_rounded,
        stats: [
          RecruitmentStat(
            value: _interviews.where((i) => i['status'] == 'scheduled').length.toString(),
            label: 'Scheduled',
            color: Colors.white,
          ),
          RecruitmentStat(
            value: _interviews.where((i) => i['status'] == 'completed').length.toString(),
            label: 'Completed',
            color: Colors.white,
          ),
          RecruitmentStat(
            value: _interviews.where((i) => i['status'] == 'cancelled').length.toString(),
            label: 'Cancelled',
            color: Colors.white,
          ),
        ],
        trailing: RecruitmentStatusChip(status: _appStatus),
      ),
      const SizedBox(height: 14),
      if (!_interviews.any((i) => i['status'] == 'scheduled') && !allCompleted)
        Card(
          color: RecruitmentColors.amberSoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: RecruitmentColors.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No interview scheduled yet. Documents are ${_application!['document_status'] == 'verified' ? 'verified' : 'not verified'}.',
                    style: TextStyle(fontSize: 12.5, color: RecruitmentColors.navy, fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: RecruitmentColors.blue),
                  onPressed: _application!['document_status'] == 'verified' ? _scheduleInterview : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Schedule'),
                ),
              ],
            ),
          ),
        ),
      if (_interviews.isNotEmpty) ...[
        const SizedBox(height: 14),
        ..._interviews.map(_buildRoundCard),
      ],
      if (allCompleted) ...[
        const SizedBox(height: 14),
        Card(
          color: RecruitmentColors.greenSoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: RecruitmentColors.green, size: 22),
                    SizedBox(width: 10),
                    Text('All rounds completed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RecruitmentColors.navy)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectCandidate,
                        icon: const Icon(Icons.verified_outlined, size: 18, color: RecruitmentColors.green),
                        label: const Text('Select candidate', style: TextStyle(color: RecruitmentColors.green)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _rejectCandidate,
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: RecruitmentColors.red),
                        label: const Text('Reject', style: TextStyle(color: RecruitmentColors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildRoundCard(Map<String, dynamic> i) {
    final status = i['status']?.toString() ?? 'scheduled';
    final roundNo = i['round_no'] ?? 1;
    final roundType = i['round_type']?.toString() ?? 'panel';
    final scheduledAt = i['scheduled_at']?.toString();
    final mode = i['mode']?.toString() ?? 'in_person';
    final venue = i['venue']?.toString();
    final link = i['meeting_link']?.toString();
    final panel = i['panel_members'];
    final panelText = panel is List ? panel.map((e) => e.toString()).join(', ') : '';
    final marks = i['marks'];
    final feedback = i['feedback']?.toString();
    final recommendation = i['recommendation']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'completed'
              ? RecruitmentColors.green
              : status == 'scheduled'
                  ? RecruitmentColors.blue
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RecruitmentColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Round $roundNo',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RecruitmentColors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  roundType.replaceAll('_', ' ').toUpperCase(),
                  style: kRecruitmentTitle,
                ),
                const Spacer(),
                RecruitmentStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Scheduled: ${recruitmentDateTime(scheduledAt)}', style: kRecruitmentCaption),
            if (mode == 'in_person' && venue != null)
              Text('Venue: $venue', style: kRecruitmentCaption),
            if (mode == 'video' && link != null)
              Text('Meeting: $link', style: kRecruitmentCaption),
            if (panelText.isNotEmpty)
              Text('Panel: $panelText', style: kRecruitmentCaption),
            if (status == 'completed') ...[
              const Divider(height: 16),
              if (marks != null)
                Text('Marks: $marks / 100', style: kRecruitmentTitle),
              if (recommendation != null)
                Text('Recommendation: ${recommendation.replaceAll('_', ' ').toUpperCase()}',
                    style: kRecruitmentBody),
              if (feedback != null && feedback.isNotEmpty)
                Text('Feedback: $feedback', style: kRecruitmentBody),
            ],
            const SizedBox(height: 10),
            if (status == 'scheduled') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _completeInterview(i),
                      icon: const Icon(Icons.check_circle_rounded, size: 16, color: RecruitmentColors.green),
                      label: const Text('Complete', style: TextStyle(color: RecruitmentColors.green)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelInterview(i),
                      icon: const Icon(Icons.cancel_outlined, size: 16, color: RecruitmentColors.red),
                      label: const Text('Cancel', style: TextStyle(color: RecruitmentColors.red)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}