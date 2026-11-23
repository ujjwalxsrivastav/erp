import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/entrance_test_service.dart';

/// Public entrance test portal for shortlisted candidates.
///
/// Reachable without signing in via `/entrance-test`. Candidates sign in with
/// the enrollment number and `ddmmyy` password issued by the admissions desk;
/// the portal then opens the published test for their class, one subject page
/// at a time.
class EntranceTestPortalScreen extends StatefulWidget {
  const EntranceTestPortalScreen({super.key});

  @override
  State<EntranceTestPortalScreen> createState() =>
      _EntranceTestPortalScreenState();
}

enum _PortalStage { login, instructions, exam, result }

class _EntranceTestPortalScreenState extends State<EntranceTestPortalScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _bg = Color(0xFFF8FAFC);

  final _testService = EntranceTestService();
  final _enrollmentCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  _PortalStage _stage = _PortalStage.login;
  bool _isLoading = false;
  bool _submitting = false;
  String? _error;

  Map<String, dynamic>? _candidate;
  Map<String, dynamic>? _test;
  List<Map<String, dynamic>> _questions = const [];
  List<String> _subjects = const [];
  int _subjectIndex = 0;
  final Map<String, dynamic> _answers = {};

  Timer? _timer;
  int _secondsLeft = 0;

  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _timer?.cancel();
    _enrollmentCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIN
  // ==========================================

  Future<void> _login() async {
    final enrollment = _enrollmentCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (enrollment.isEmpty || password.isEmpty) {
      setState(() => _error =
          'Enter both the enrollment number and the password shared by the school.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final candidate = await _testService.login(
      enrollmentNo: enrollment,
      password: password,
    );
    if (!mounted) return;

    if (candidate == null) {
      setState(() {
        _isLoading = false;
        _error =
            'Enrollment number or password is incorrect. Contact the admissions office if you need it re-shared.';
      });
      return;
    }

    final className = (candidate['class_name'] ?? '').toString();
    Map<String, dynamic>? test;
    final testId = (candidate['test_id'] ?? '').toString();
    if (testId.isNotEmpty) {
      test = await _testService.getTest(testId);
    }
    test ??= await _testService.getPublishedTestForClass(className);

    if (test == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            'No entrance test is currently configured for $className. Please contact the admissions office.';
      });
      return;
    }

    final questions = await _testService.getTestQuestions(
        test['id']?.toString() ?? '');
    if (!mounted) return;

    if (questions.isEmpty) {
      setState(() {
        _isLoading = false;
        _error =
            'The entrance test for $className has no questions yet. Please contact the admissions office.';
      });
      return;
    }

    final subjects = <String>[];
    for (final q in questions) {
      final subject = (q['subject'] ?? 'General').toString();
      if (!subjects.contains(subject)) subjects.add(subject);
    }

    if ((candidate['status'] ?? '').toString().toLowerCase() == 'submitted') {
      setState(() {
        _isLoading = false;
        _candidate = candidate;
        _test = test;
        _questions = questions;
        _subjects = subjects;
        _result = {
          'total_score': candidate['total_score'],
          'max_score': candidate['max_score'],
          'percentage': candidate['percentage'],
          'grade': candidate['grade'],
          'subject_scores': candidate['subject_scores'],
          'candidate_name': candidate['candidate_name'],
          'enrollment_no': candidate['enrollment_no'],
          'class_name': candidate['class_name'],
          'already_submitted': true,
        };
        _stage = _PortalStage.result;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _candidate = candidate;
      _test = test;
      _questions = questions;
      _subjects = subjects;
      _subjectIndex = 0;
      _answers.clear();
      _stage = _PortalStage.instructions;
    });
  }

  // ==========================================
  // EXAM
  // ==========================================

  Future<void> _startExam() async {
    final candidate = _candidate;
    final test = _test;
    if (candidate == null || test == null) return;
    await _testService.markStarted(candidate);
    if (!mounted) return;

    final duration = (test['duration_minutes'] as num?)?.toInt() ?? 90;
    setState(() {
      _secondsLeft = duration * 60;
      _subjectIndex = 0;
      _stage = _PortalStage.exam;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        _submit(auto: true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  List<Map<String, dynamic>> _questionsForSubject(String subject) =>
      _questions
          .where((q) => (q['subject'] ?? 'General').toString() == subject)
          .toList();

  int _unansweredCount() {
    var count = 0;
    for (final q in _questions) {
      final id = (q['id'] ?? '').toString();
      final value = _answers[id];
      if (value == null ||
          (value is String && value.trim().isEmpty)) {
        count++;
      }
    }
    return count;
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _unansweredCount();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit entrance test?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          unanswered > 0
              ? '$unanswered question(s) are unanswered. You cannot change your answers after submitting.'
              : 'You have answered all questions. You cannot change your answers after submitting.',
          style: const TextStyle(fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Reviewing')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white),
            child: const Text('Submit Test'),
          ),
        ],
      ),
    );
    if (confirmed == true) _submit();
  }

  Future<void> _submit({bool auto = false}) async {
    final candidate = _candidate;
    if (candidate == null || _submitting) return;
    _timer?.cancel();
    setState(() => _submitting = true);

    try {
      final result = await _testService.submit(
        candidate: candidate,
        questions: _questions,
        answers: Map<String, dynamic>.from(_answers),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
        _stage = _PortalStage.result;
      });
      if (auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time is up — your test was submitted automatically.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'The test could not be submitted. Please inform the invigilator.';
      });
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _PortalStage.login:
        return _buildLogin();
      case _PortalStage.instructions:
        return _buildInstructions();
      case _PortalStage.exam:
        return _buildExam();
      case _PortalStage.result:
        return _buildResult();
    }
  }

  Widget _buildShell({required Widget child}) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader({String? subtitle}) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Icon(Icons.school_rounded, color: _blue, size: 28),
        ),
        const SizedBox(height: 12),
        const Text('Shivalik International School',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 2),
        Text(subtitle ?? 'Entrance Examination Portal',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLogin() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _buildBrandHeader(),
                  const SizedBox(height: 20),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Candidate Sign In',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _ink)),
                        const SizedBox(height: 4),
                        const Text(
                          'Use the enrollment number and password shared by the admissions office.',
                          style: TextStyle(fontSize: 11.5, color: _muted),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _enrollmentCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Enrollment number',
                            hintText: 'ENT260001',
                            prefixIcon: Icon(Icons.badge_outlined, size: 18),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password (ddmmyy)',
                            prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _isLoading ? null : _login(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFFECACA)),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFB91C1C),
                                    height: 1.35)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _login,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.login_rounded, size: 18),
                          label: Text(_isLoading ? 'Signing in…' : 'Sign In'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to school login',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Keep this window open during the test. The paper is timed and submits automatically when time runs out.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: _muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final candidate = _candidate!;
    final test = _test!;
    final duration = (test['duration_minutes'] as num?)?.toInt() ?? 90;
    final totalMarks =
        _questions.fold<int>(0, (sum, q) => sum + ((q['marks'] as num?)?.toInt() ?? 0));

    return _buildShell(
      child: Column(
        children: [
          _buildBrandHeader(subtitle: 'Entrance Examination'),
          const SizedBox(height: 20),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (candidate['candidate_name'] ?? 'Candidate')
                                .toString(),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${candidate['class_name']} • Enrollment ${candidate['enrollment_no']}',
                            style: const TextStyle(
                                fontSize: 11.5, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$duration min',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _blue)),
                    ),
                  ],
                ),
                const Divider(height: 26, color: _border),
                Text(
                  (test['title'] ?? 'Entrance Test').toString(),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_subjects subjects • ${_questions.length} questions • $totalMarks marks',
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
                const SizedBox(height: 14),
                ..._subjects.map((subject) {
                  final subjectQuestions = _questionsForSubject(subject);
                  final marks = subjectQuestions.fold<int>(
                      0,
                      (sum, q) =>
                          sum + ((q['marks'] as num?)?.toInt() ?? 0));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _bg,
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
                        Text(
                          '${subjectQuestions.length} Q • $marks marks',
                          style: const TextStyle(
                              fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  'Instructions',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _ink),
                ),
                const SizedBox(height: 6),
                ...const [
                  'Each subject opens on a separate page. Use Next Subject to move forward.',
                  'Objective questions have four options — select the best answer.',
                  'You may move back to a subject before submitting.',
                  'The test submits automatically when the timer reaches zero.',
                ].map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ',
                              style: TextStyle(
                                  fontSize: 12, color: _blue)),
                          Expanded(
                            child: Text(line,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _muted,
                                    height: 1.35)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startExam,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Start Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExam() {
    final subject = _subjects.isEmpty ? 'General' : _subjects[_subjectIndex];
    final questions = _questionsForSubject(subject);
    final isLast = _subjectIndex >= _subjects.length - 1;
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final urgent = _secondsLeft <= 300;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_test?['title'] ?? 'Entrance Test').toString(),
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _ink),
            ),
            Text(
              '${_candidate?['candidate_name'] ?? ''} • ${_candidate?['class_name'] ?? ''}',
              style: const TextStyle(fontSize: 10.5, color: _muted),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: urgent
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: urgent
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 15,
                    color: urgent ? const Color(0xFFDC2626) : _blue),
                const SizedBox(width: 5),
                Text(
                  '$minutes:$seconds',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: urgent ? const Color(0xFFDC2626) : _blue),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _subjects.asMap().entries.map((entry) {
                  final active = entry.key == _subjectIndex;
                  final done = entry.key < _subjectIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _subjectIndex = entry.key),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? _blue
                              : done
                                  ? const Color(0xFFECFDF5)
                                  : _bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active
                                  ? _blue
                                  : done
                                      ? const Color(0xFFA7F3D0)
                                      : _border),
                        ),
                        child: Row(
                          children: [
                            if (done) ...[
                              const Icon(Icons.check_circle_rounded,
                                  size: 12, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.white
                                    : done
                                        ? const Color(0xFF047857)
                                        : _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                Row(
                  children: [
                    Text('Subject ${_subjectIndex + 1} of ${_subjects.length}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _muted)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${questions.length} questions',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0369A1))),
                    ),
                    const Spacer(),
                    Text('$subject',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                  ],
                ),
                const SizedBox(height: 12),
                ...questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final q = entry.value;
                  final id = (q['id'] ?? '').toString();
                  final options = ((q['options'] as List?) ?? const [])
                      .map((o) => o?.toString() ?? '')
                      .toList();
                  final selected = _answers[id];
                  final marks = (q['marks'] as num?)?.toInt() ?? 10;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _ink,
                                    height: 1.4),
                              ),
                            ),
                            Text('$marks',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _muted)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (options.isNotEmpty)
                          ...options.asMap().entries.map((opt) {
                            final optIndex = opt.key;
                            final isSelected = selected == optIndex;
                            return InkWell(
                              onTap: () =>
                                  setState(() => _answers[id] = optIndex),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : _bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isSelected
                                          ? _blue
                                          : _border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? _blue
                                            : Colors.white,
                                        border: Border.all(
                                            color: isSelected
                                                ? _blue
                                                : const Color(0xFFCBD5E1)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          String.fromCharCode(65 + optIndex),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected
                                                  ? Colors.white
                                                  : _muted),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(opt.value,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF334155),
                                              height: 1.3)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                        else
                          TextFormField(
                            key: ValueKey('answer-$id'),
                            initialValue: selected?.toString() ?? '',
                            maxLines: 3,
                            onChanged: (value) =>
                                _answers[id] = value,
                            decoration: const InputDecoration(
                              hintText: 'Type your answer…',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                if (_subjectIndex > 0)
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _subjectIndex--),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Previous'),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                if (!isLast)
                  ElevatedButton.icon(
                    onPressed: () =>
                        setState(() => _subjectIndex++),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Next Subject'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _confirmSubmit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_submitting ? 'Submitting…' : 'Submit Test'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final result = _result ?? const <String, dynamic>{};
    final pct = (result['percentage'] as num?)?.toDouble() ?? 0;
    final total = (result['total_score'] as num?)?.toDouble() ?? 0;
    final max = (result['max_score'] as num?)?.toDouble() ?? 0;
    final grade = (result['grade'] ?? '').toString();
    final scores = ((result['subject_scores'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final already = result['already_submitted'] == true;

    return _buildShell(
      child: Column(
        children: [
          _buildBrandHeader(subtitle: 'Entrance Examination'),
          const SizedBox(height: 20),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_rounded,
                          color: Color(0xFF059669), size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            already
                                ? 'Test already submitted'
                                : 'Test submitted successfully',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _ink),
                          ),
                          Text(
                            '${result['candidate_name'] ?? ''} • ${result['class_name'] ?? ''} • ${result['enrollment_no'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF047857))),
                          Text(
                              '${total.toStringAsFixed(0)} / ${max.toStringAsFixed(0)} marks',
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF047857))),
                        ],
                      ),
                      const Spacer(),
                      if (grade.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text('Grade $grade',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857))),
                        ),
                    ],
                  ),
                ),
                if (scores.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Subject-wise score',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  const SizedBox(height: 8),
                  ...scores.map((s) {
                    final marks = (s['marks'] as num?)?.toDouble() ?? 0;
                    final subjectMax = (s['max'] as num?)?.toDouble() ?? 0;
                    final ratio = subjectMax > 0
                        ? (marks / subjectMax).clamp(0.0, 1.0)
                        : 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    (s['subject'] ?? 'General').toString(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155))),
                              ),
                              Text(
                                  '${marks.toStringAsFixed(0)} / ${subjectMax.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _ink)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio.toDouble(),
                              minHeight: 5,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    'Your response has been recorded. The admissions office will review the result and contact you about the next steps.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF1E40AF),
                        height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                  child: const Text('Exit to School Login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
