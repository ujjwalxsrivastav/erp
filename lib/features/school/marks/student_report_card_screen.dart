import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

/// A student-only, read-only report card: no staff selectors or edit tools.
class StudentReportCardScreen extends StatefulWidget {
  const StudentReportCardScreen({super.key});

  @override
  State<StudentReportCardScreen> createState() =>
      _StudentReportCardScreenState();
}

class _StudentReportCardScreenState extends State<StudentReportCardScreen> {
  final _service = SchoolService();
  final _auth = AuthService();
  List<Map<String, dynamic>> _marks = [];
  List<String> _sessions = const ['Half Yearly', 'Final'];
  Map<String, dynamic> _student = {};
  Map<String, dynamic> _analytics = {};
  String _selectedSession = 'Half Yearly';
  String _username = '';
  double _attendance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refreshSessions = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _username = await _auth.getCurrentUsername() ?? '';
      if (_username.isEmpty)
        throw StateError('Your session could not be verified.');
      if (refreshSessions) {
        final sessions = await _service.getExamSessions();
        if (sessions.isNotEmpty) {
          _sessions = sessions;
          if (!_sessions.contains(_selectedSession))
            _selectedSession = _sessions.first;
        }
      }
      final profile = await _service.getSchoolStudentProfile(_username);
      final marks = await _service.getStudentMarks(_username,
          examType: _selectedSession,
          studentName: profile?['name']?.toString());
      final attendance = await _service.getStudentAttendancePercent(_username);
      if (!mounted) return;
      setState(() {
        _student = profile ?? {'username': _username, 'name': _username};
        _marks = marks;
        _analytics = _service.buildReportAnalytics(marks);
        _attendance = attendance;
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Could not load your report card. Please retry.';
        });
    }
  }

  double get _percentage => (_analytics['percentage'] as num?)?.toDouble() ?? 0;
  String get _grade => (_analytics['grade'] ?? '—').toString();
  int get _obtained => (_analytics['obtained'] as num?)?.toInt() ?? 0;
  int get _max => (_analytics['max'] as num?)?.toInt() ?? 0;
  String get _name => (_student['name'] ?? _username).toString();
  String get _className =>
      (_student['class_name'] ?? 'Class not assigned').toString();

  Color get _accent {
    if (_percentage >= 75) return const Color(0xFF0F766E);
    if (_percentage >= 50) return const Color(0xFF2563EB);
    if (_percentage >= 33) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(
          title: const Text('My Report Card',
              style: TextStyle(fontWeight: FontWeight.w800)),
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF0F766E)]),
            ),
          ),
          actions: [
            IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded))
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F766E)))
            : _error != null
                ? _errorView()
                : RefreshIndicator(
                    color: const Color(0xFF0F766E),
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      children: [
                        _hero(),
                        const SizedBox(height: 16),
                        _sessionSelector(),
                        const SizedBox(height: 16),
                        if (_marks.isEmpty)
                          _emptyCard()
                        else ...[
                          _metrics(),
                          const SizedBox(height: 20),
                          _heading('Subject performance',
                              '${_marks.length} subjects'),
                          const SizedBox(height: 10),
                          ..._marks.map(_subjectCard),
                        ],
                      ],
                    ),
                  ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [_accent, _accent.withValues(alpha: .78)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: _accent.withValues(alpha: .25),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Row(children: [
          CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: .2),
              child: Text(_name.isEmpty ? '?' : _name[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('ACADEMIC PERFORMANCE',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8)),
                const SizedBox(height: 4),
                Text(_name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800)),
                Text(_className,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                Text(
                    '$_obtained / $_max  ·  ${_percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ])),
          Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54, width: 2),
                  color: Colors.white.withValues(alpha: .12)),
              child: Center(
                  child: Text(_grade,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)))),
        ]),
      );

  Widget _sessionSelector() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: _sessions.map((session) {
            final active = session == _selectedSession;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(session),
                selected: active,
                selectedColor: const Color(0xFF0F766E),
                labelStyle: TextStyle(
                    color: active ? Colors.white : const Color(0xFF475569),
                    fontWeight: FontWeight.w700),
                onSelected: (_) async {
                  if (!active) {
                    setState(() => _selectedSession = session);
                    await _load(refreshSessions: false);
                  }
                },
              ),
            );
          }).toList()),
        ),
      );

  Widget _metrics() => Row(children: [
        _metric('Attendance', '${_attendance.toStringAsFixed(0)}%',
            Icons.calendar_today_rounded, const Color(0xFF0F766E)),
        const SizedBox(width: 10),
        _metric('Grade', _grade, Icons.workspace_premium_rounded, _accent),
        const SizedBox(width: 10),
        _metric('Subjects', '${_marks.length}', Icons.menu_book_rounded,
            const Color(0xFF2563EB)),
      ]);

  Widget _metric(String label, String value, IconData icon, Color color) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)))
        ]),
      ));

  Widget _subjectCard(Map<String, dynamic> mark) {
    final subject =
        (mark['subject_name'] ?? mark['subject'] ?? 'Subject').toString();
    final obtained =
        (mark['marks_obtained'] ?? mark['obtained_marks'] ?? 0) as num;
    final total = (mark['total_marks'] ?? mark['max_marks'] ?? 100) as num;
    final pct = total == 0 ? 0.0 : obtained.toDouble() / total.toDouble() * 100;
    final grade =
        (mark['grade'] ?? SchoolService.calculateCbseGrade(pct)['grade'])
            .toString();
    final color = pct >= 75
        ? const Color(0xFF0F766E)
        : pct >= 50
            ? const Color(0xFF2563EB)
            : pct >= 33
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.auto_stories_rounded, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(subject,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B))),
                Text(
                    '${obtained.toStringAsFixed(0)} / ${total.toStringAsFixed(0)}  ·  ${pct.toStringAsFixed(0)}%',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
              ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(grade,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 11),
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 7,
                color: color,
                backgroundColor: const Color(0xFFF1F5F9))),
      ]),
    );
  }

  Widget _heading(String title, String subtitle) => Row(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B))),
        const Spacer(),
        Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
      ]);
  Widget _emptyCard() => Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: const Column(children: [
        Icon(Icons.hourglass_empty_rounded, size: 36, color: Color(0xFF94A3B8)),
        SizedBox(height: 10),
        Text('Results are not published yet',
            style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text('Your school will make this report available after publication.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
      ]));
  Widget _errorView() => Center(
      child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error ?? 'Retry')));
}
