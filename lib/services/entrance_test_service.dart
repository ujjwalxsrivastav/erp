import 'package:supabase_flutter/supabase_flutter.dart';

import 'school_service.dart';
import 'supabase_service.dart';

/// Entrance test authoring, candidate credentials and the public test attempt.
///
/// Admin flow:
///   1. Build a test for a class — one page per subject, questions out of 10.
///   2. Issue an enrollment number + ddmmyy password to an applicant.
///   3. Candidate signs in at `/entrance-test` and answers the test for their
///      class. The result is scored and written back to the admission row.
///
/// Every read/write degrades to an in-memory fallback when the
/// `database/school_entrance_test_setup.sql` migration has not been applied.
class EntranceTestService {
  EntranceTestService._internal();
  static final EntranceTestService _instance = EntranceTestService._internal();
  factory EntranceTestService() => _instance;

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolService _school = SchoolService();

  // In-memory fallbacks.
  final List<Map<String, dynamic>> _localTests = [];
  final List<Map<String, dynamic>> _localQuestions = [];
  final List<Map<String, dynamic>> _localCandidates = [];

  // ==========================================
  // TESTS
  // ==========================================

  Future<List<Map<String, dynamic>>> getTests({String? className}) async {
    final cls = (className ?? '').trim();
    try {
      var query = _supabase.from('school_entrance_tests').select();
      if (cls.isNotEmpty) query = query.eq('class_name', cls);
      final rows = await query.order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rows)
          .map(_normaliseTest)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    final local = _localTests
        .where((t) => cls.isEmpty || t['class_name'] == cls)
        .map((t) => Map<String, dynamic>.from(t))
        .toList()
      ..sort((a, b) => (b['updated_at']?.toString() ?? '')
          .compareTo(a['updated_at']?.toString() ?? ''));
    return local;
  }

  Future<Map<String, dynamic>?> getTest(String testId) async {
    if (testId.trim().isEmpty) return null;
    try {
      final row = await _supabase
          .from('school_entrance_tests')
          .select()
          .eq('id', testId)
          .maybeSingle();
      if (row != null) return _normaliseTest(row);
    } catch (_) {}

    for (final t in _localTests) {
      if (t['id']?.toString() == testId) return Map<String, dynamic>.from(t);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPublishedTestForClass(
      String className) async {
    final cls = className.trim();
    if (cls.isEmpty) return null;
    try {
      final rows = await _supabase
          .from('school_entrance_tests')
          .select()
          .eq('class_name', cls)
          .eq('status', 'published')
          .order('updated_at', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) {
        return _normaliseTest(Map<String, dynamic>.from(rows.first));
      }
    } catch (_) {}

    final published = _localTests
        .where((t) => t['class_name'] == cls && t['status'] == 'published')
        .toList()
      ..sort((a, b) => (b['updated_at']?.toString() ?? '')
          .compareTo(a['updated_at']?.toString() ?? ''));
    return published.isEmpty ? null : Map<String, dynamic>.from(published.first);
  }

  Future<List<Map<String, dynamic>>> getTestQuestions(String testId) async {
    if (testId.trim().isEmpty) return const [];
    try {
      final rows = await _supabase
          .from('school_entrance_test_questions')
          .select()
          .eq('test_id', testId)
          .order('order_index', ascending: true);
      final list = List<Map<String, dynamic>>.from(rows)
          .map(_normaliseQuestion)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    final local = _localQuestions
        .where((q) => q['test_id']?.toString() == testId)
        .map((q) => Map<String, dynamic>.from(q))
        .toList()
      ..sort((a, b) => ((a['order_index'] as num?)?.toInt() ?? 0)
          .compareTo((b['order_index'] as num?)?.toInt() ?? 0));
    return local;
  }

  /// Creates or replaces a test and its complete question set.
  Future<Map<String, dynamic>> saveTest({
    String? testId,
    required String className,
    required String title,
    required int durationMinutes,
    required List<Map<String, dynamic>> questions,
    required String createdBy,
    String status = 'published',
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final testPayload = <String, dynamic>{
      'class_name': className.trim(),
      'title': title.trim(),
      'duration_minutes': durationMinutes,
      'status': status,
      'instructions':
          'Answer all questions. Each subject carries 50 marks. The test opens one subject at a time.',
      'created_by': createdBy,
      'updated_at': nowIso,
    };

    Map<String, dynamic>? savedTest;
    var usingDb = false;
    final cleanId = (testId ?? '').trim();

    if (cleanId.isNotEmpty && _looksLikeUuid(cleanId)) {
      try {
        final updated = await _supabase
            .from('school_entrance_tests')
            .update(testPayload)
            .eq('id', cleanId)
            .select()
            .maybeSingle();
        if (updated != null) {
          savedTest = _normaliseTest(updated);
          usingDb = true;
          await _supabase
              .from('school_entrance_test_questions')
              .delete()
              .eq('test_id', cleanId);
        }
      } catch (_) {}
    }

    if (savedTest == null) {
      try {
        final inserted = await _supabase
            .from('school_entrance_tests')
            .insert(testPayload)
            .select()
            .maybeSingle();
        if (inserted != null) {
          savedTest = _normaliseTest(inserted);
          usingDb = true;
        }
      } catch (_) {}
    }

    if (savedTest == null) {
      final localId = cleanId.isNotEmpty
          ? cleanId
          : 'local-test-${DateTime.now().millisecondsSinceEpoch}';
      final existingIdx =
          _localTests.indexWhere((t) => t['id']?.toString() == localId);
      final localTest = <String, dynamic>{
        'id': localId,
        ...testPayload,
        'created_at': nowIso,
      };
      if (existingIdx >= 0) {
        _localTests[existingIdx] = localTest;
      } else {
        _localTests.insert(0, localTest);
      }
      _localQuestions.removeWhere((q) => q['test_id']?.toString() == localId);
      savedTest = localTest;
    }

    final resolvedId = savedTest['id']?.toString() ?? '';
    if (usingDb) {
      final payload = <Map<String, dynamic>>[];
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final questionText = (q['question'] ?? '').toString().trim();
        if (questionText.isEmpty) continue;
        payload.add({
          'test_id': resolvedId,
          'subject': (q['subject'] ?? 'General').toString(),
          'question_text': questionText,
          'options': (q['options'] as List?) ?? const <String>[],
          'correct_answer': q['answer']?.toString() ?? '',
          'marks': (q['marks'] as num?)?.toInt() ?? 10,
          'order_index': i,
        });
      }
      if (payload.isNotEmpty) {
        try {
          final rows = await _supabase
              .from('school_entrance_test_questions')
              .insert(payload)
              .select();
          final savedQuestions = List<Map<String, dynamic>>.from(rows)
              .map(_normaliseQuestion)
              .toList();
          return {...savedTest, 'questions': savedQuestions};
        } catch (_) {
          // Fall through to the in-memory store so the admin is not blocked.
        }
      }
    }

    final localQuestions = <Map<String, dynamic>>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final questionText = (q['question'] ?? '').toString().trim();
      if (questionText.isEmpty) continue;
      localQuestions.add(_normaliseQuestion({
        'id': 'local-q-$resolvedId-$i',
        'test_id': resolvedId,
        'subject': (q['subject'] ?? 'General').toString(),
        'question_text': questionText,
        'options': (q['options'] as List?) ?? const <String>[],
        'correct_answer': q['answer']?.toString() ?? '',
        'marks': (q['marks'] as num?)?.toInt() ?? 10,
        'order_index': i,
      }));
    }
    _localQuestions
      ..removeWhere((q) => q['test_id']?.toString() == resolvedId)
      ..addAll(localQuestions);
    return {...savedTest, 'questions': localQuestions};
  }

  Future<bool> deleteTest(String testId) async {
    if (testId.trim().isEmpty) return false;
    if (_looksLikeUuid(testId)) {
      try {
        await _supabase.from('school_entrance_tests').delete().eq('id', testId);
        _localQuestions.removeWhere((q) => q['test_id']?.toString() == testId);
        return true;
      } catch (_) {}
    }
    _localTests.removeWhere((t) => t['id']?.toString() == testId);
    _localQuestions.removeWhere((q) => q['test_id']?.toString() == testId);
    return true;
  }

  // ==========================================
  // CANDIDATE CREDENTIALS
  // ==========================================

  Future<Map<String, dynamic>?> getCandidateForAdmission(
      String admissionId) async {
    if (admissionId.trim().isEmpty) return null;
    try {
      final rows = await _supabase
          .from('school_entrance_candidates')
          .select()
          .eq('admission_id', admissionId)
          .order('issued_at', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) {
        return _normaliseCandidate(Map<String, dynamic>.from(rows.first));
      }
    } catch (_) {}

    for (final c in _localCandidates) {
      if (c['admission_id']?.toString() == admissionId) {
        return Map<String, dynamic>.from(c);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCandidateByEnrollment(
      String enrollmentNo) async {
    final no = enrollmentNo.trim().toUpperCase();
    if (no.isEmpty) return null;
    try {
      final rows = await _supabase
          .from('school_entrance_candidates')
          .select()
          .eq('enrollment_no', no)
          .limit(1);
      if (rows.isNotEmpty) {
        return _normaliseCandidate(Map<String, dynamic>.from(rows.first));
      }
    } catch (_) {}

    for (final c in _localCandidates) {
      if (c['enrollment_no']?.toString().toUpperCase() == no) {
        return Map<String, dynamic>.from(c);
      }
    }
    return null;
  }

  /// Creates (or returns) the candidate's exam login.
  ///
  /// The password is the applicant's date of birth as `ddmmyy`; when the DOB is
  /// missing or unparseable the issuance date is used so the desk always has a
  /// shareable password.
  Future<Map<String, dynamic>> issueCredentials({
    required Map<String, dynamic> admission,
    required String className,
    required String issuedBy,
    String? testId,
  }) async {
    final admissionId = admission['id']?.toString() ?? '';
    final existing = await getCandidateForAdmission(admissionId);
    if (existing != null) {
      return {'ok': true, 'candidate': existing, 'reused': true};
    }

    Map<String, dynamic>? test;
    if (testId != null && testId.isNotEmpty) {
      test = await getTest(testId);
    }
    test ??= await getPublishedTestForClass(className);
    if (test == null) {
      return {
        'ok': false,
        'message':
            'No published entrance test exists for $className. Create and publish a test first.',
      };
    }

    final enrollmentNo = await _nextEnrollmentNo();
    final password = candidatePasswordFor(admission['dob']);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      if (admissionId.isNotEmpty) 'admission_id': admissionId,
      'enrollment_no': enrollmentNo,
      'password': password,
      'class_name': className.trim(),
      if (test['id'] != null) 'test_id': test['id'],
      'candidate_name': (admission['applicant_name'] ??
              admission['student_name'] ??
              'Candidate')
          .toString(),
      'parent_name': (admission['parent_name'] ?? '').toString(),
      'status': 'issued',
      'issued_by': issuedBy,
      'issued_at': nowIso,
    };

    Map<String, dynamic> candidate;
    try {
      final inserted = await _supabase
          .from('school_entrance_candidates')
          .insert(payload)
          .select()
          .maybeSingle();
      candidate = inserted != null
          ? _normaliseCandidate(inserted)
          : _normaliseCandidate({
              'id': 'local-candidate-${DateTime.now().millisecondsSinceEpoch}',
              ...payload,
            });
      if (inserted == null) _localCandidates.insert(0, candidate);
    } catch (_) {
      candidate = _normaliseCandidate({
        'id': 'local-candidate-${DateTime.now().millisecondsSinceEpoch}',
        ...payload,
      });
      _localCandidates.insert(0, candidate);
    }

    // Stamp the admission row so the admin desk can display/share the login.
    if (_looksLikeUuid(admissionId)) {
      try {
        await _supabase.from('school_admissions').update({
          'entrance_enrollment_no': enrollmentNo,
          'updated_at': nowIso,
        }).eq('id', admissionId);
      } catch (_) {}
    }

    return {
      'ok': true,
      'candidate': candidate,
      'test': test,
      'reused': false,
    };
  }

  /// ddmmyy password from a stored ISO date; falls back to today.
  static String candidatePasswordFor(Object? dob) {
    final parsed = DateTime.tryParse((dob ?? '').toString().trim());
    return _ddmmyy(parsed ?? DateTime.now());
  }

  static String _ddmmyy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${(d.year % 100).toString().padLeft(2, '0')}';

  Future<String> _nextEnrollmentNo() async {
    final yy =
        (DateTime.now().year % 100).toString().padLeft(2, '0');
    var base = _localCandidates.length;
    try {
      final rows =
          await _supabase.from('school_entrance_candidates').select('id');
      base = rows.length;
    } catch (_) {}

    for (var attempt = 0; attempt < 100; attempt++) {
      final seq = base + attempt + 1;
      final no = 'ENT$yy${seq.toString().padLeft(4, '0')}';
      var taken = false;
      try {
        final rows = await _supabase
            .from('school_entrance_candidates')
            .select('id')
            .eq('enrollment_no', no)
            .limit(1);
        taken = rows.isNotEmpty;
      } catch (_) {
        taken = _localCandidates.any((c) => c['enrollment_no'] == no);
      }
      if (!taken) return no;
    }
    return 'ENT$yy${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  // ==========================================
  // CANDIDATE PORTAL
  // ==========================================

  Future<Map<String, dynamic>?> login({
    required String enrollmentNo,
    required String password,
  }) async {
    final no = enrollmentNo.trim().toUpperCase();
    final pw = password.trim();
    if (no.isEmpty || pw.isEmpty) return null;

    try {
      final rows = await _supabase
          .from('school_entrance_candidates')
          .select()
          .eq('enrollment_no', no)
          .limit(1);
      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first);
        if ((row['password'] ?? '').toString().trim() == pw) {
          return _normaliseCandidate(row);
        }
        return null;
      }
    } catch (_) {}

    for (final c in _localCandidates) {
      if ((c['enrollment_no']?.toString().toUpperCase() ?? '') == no &&
          (c['password']?.toString() ?? '') == pw) {
        return Map<String, dynamic>.from(c);
      }
    }
    return null;
  }

  Future<void> markStarted(Map<String, dynamic> candidate) async {
    final id = candidate['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (_looksLikeUuid(id)) {
      try {
        await _supabase.from('school_entrance_candidates').update({
          'status': 'in_progress',
          'started_at': nowIso,
        }).eq('id', id);
      } catch (_) {}
    }
    for (final c in _localCandidates) {
      if (c['id']?.toString() == id) {
        c['status'] = 'in_progress';
        c['started_at'] = nowIso;
      }
    }
  }

  /// Scores the submitted answers, archives the attempt and writes the result
  /// back to the admission row.
  Future<Map<String, dynamic>> submit({
    required Map<String, dynamic> candidate,
    required List<Map<String, dynamic>> questions,
    required Map<String, dynamic> answers,
  }) async {
    final subjectTotals = <String, Map<String, double>>{};
    for (final q in questions) {
      final questionId = (q['id'] ?? '').toString();
      final subject = (q['subject'] ?? 'General').toString();
      final marks = (q['marks'] as num?)?.toDouble() ?? 10;
      final options = (q['options'] as List?) ?? const [];
      final raw = answers[questionId];
      double awarded = 0;

      if (options.isNotEmpty) {
        final correct = int.tryParse((q['answer'] ?? '').toString());
        final selected = raw is int
            ? raw
            : int.tryParse(raw?.toString() ?? '');
        if (correct != null && selected == correct) awarded = marks;
      } else {
        final key = _normalise((q['answer'] ?? '').toString());
        final given = _normalise(raw?.toString() ?? '');
        if (key.isNotEmpty && key == given) awarded = marks;
      }

      final agg = subjectTotals.putIfAbsent(
          subject, () => <String, double>{'marks': 0, 'max': 0});
      agg['marks'] = (agg['marks'] ?? 0) + awarded;
      agg['max'] = (agg['max'] ?? 0) + marks;
    }

    final subjectScores = subjectTotals.entries
        .map((e) => <String, dynamic>{
              'subject': e.key,
              'marks': double.parse((e.value['marks'] ?? 0).toStringAsFixed(2)),
              'max': double.parse((e.value['max'] ?? 0).toStringAsFixed(2)),
            })
        .toList();

    final result = await _school.recordAdmissionEntranceResult(
      admissionId: candidate['admission_id']?.toString() ?? '',
      subjectScores: subjectScores,
      mode: 'online',
      recordedBy: 'candidate:${candidate['enrollment_no'] ?? ''}',
      className: candidate['class_name']?.toString(),
    );

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final candidateId = candidate['id']?.toString() ?? '';
    final updatePayload = <String, dynamic>{
      'status': 'submitted',
      'total_score': result['total_score'],
      'max_score': result['max_score'],
      'percentage': result['percentage'],
      'grade': result['grade'],
      'subject_scores': subjectScores,
      'answers': answers,
      'submitted_at': nowIso,
    };

    if (_looksLikeUuid(candidateId)) {
      try {
        await _supabase
            .from('school_entrance_candidates')
            .update(updatePayload)
            .eq('id', candidateId);
      } catch (_) {}
    }
    for (final c in _localCandidates) {
      if (c['id']?.toString() == candidateId) c.addAll(updatePayload);
    }

    return {
      ...result,
      'subject_scores': subjectScores,
      'enrollment_no': candidate['enrollment_no'],
      'candidate_name': candidate['candidate_name'],
      'class_name': candidate['class_name'],
    };
  }

  // ==========================================
  // NORMALISERS
  // ==========================================

  Map<String, dynamic> _normaliseTest(Map<String, dynamic> row) => {
        'id': row['id']?.toString() ?? '',
        'class_name': row['class_name']?.toString() ?? '',
        'title': row['title']?.toString() ?? '',
        'duration_minutes':
            (row['duration_minutes'] as num?)?.toInt() ?? 90,
        'status': row['status']?.toString() ?? 'published',
        'instructions': row['instructions']?.toString() ?? '',
        'created_by': row['created_by']?.toString() ?? '',
        'created_at': row['created_at']?.toString() ?? '',
        'updated_at': row['updated_at']?.toString() ?? '',
      };

  Map<String, dynamic> _normaliseQuestion(Map<String, dynamic> row) => {
        'id': row['id']?.toString() ?? '',
        'test_id': row['test_id']?.toString() ?? '',
        'subject': row['subject']?.toString() ?? '',
        'question': (row['question_text'] ?? row['question'] ?? '').toString(),
        'options': ((row['options'] as List?) ?? const [])
            .map((o) => o?.toString() ?? '')
            .where((o) => o.isNotEmpty)
            .toList(),
        'answer': (row['correct_answer'] ?? row['answer'] ?? '').toString(),
        'marks': (row['marks'] as num?)?.toInt() ?? 10,
        'order_index': (row['order_index'] as num?)?.toInt() ?? 0,
      };

  Map<String, dynamic> _normaliseCandidate(Map<String, dynamic> row) => {
        'id': row['id']?.toString() ?? '',
        'admission_id': row['admission_id']?.toString() ?? '',
        'enrollment_no': row['enrollment_no']?.toString() ?? '',
        'password': row['password']?.toString() ?? '',
        'class_name': row['class_name']?.toString() ?? '',
        'test_id': row['test_id']?.toString() ?? '',
        'candidate_name': row['candidate_name']?.toString() ?? '',
        'parent_name': row['parent_name']?.toString() ?? '',
        'status': row['status']?.toString() ?? 'issued',
        'total_score': (row['total_score'] as num?)?.toDouble() ?? 0,
        'max_score': (row['max_score'] as num?)?.toDouble() ?? 0,
        'percentage': (row['percentage'] as num?)?.toDouble() ?? 0,
        'grade': row['grade']?.toString() ?? '',
        'subject_scores': row['subject_scores'],
        'answers': row['answers'],
        'issued_at': row['issued_at']?.toString() ?? '',
        'started_at': row['started_at']?.toString() ?? '',
        'submitted_at': row['submitted_at']?.toString() ?? '',
      };

  static String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _looksLikeUuid(String value) => RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      .hasMatch(value.trim());
}
