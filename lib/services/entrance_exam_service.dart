import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'school_ai_service.dart';
import 'supabase_service.dart';

/// Entrance examination blueprint, AI paper generation and result plumbing.
///
/// The entrance exam runs *before* document verification:
///
///   Applied → Entrance Exam → Documents Verified → Offer Letter → Enrolled
///
/// Every subject carries a fixed weightage of 50 marks. Teachers/admins can
/// maintain subjects and topics per class. Two delivery modes are supported:
///   * offline — marks are entered by the admin desk.
///   * online  — an AI paper is generated from previous-class + target-class
///               topics and can be printed for the applicant.
class EntranceExamService {
  EntranceExamService._internal();
  static final EntranceExamService _instance = EntranceExamService._internal();
  factory EntranceExamService() => _instance;

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolAiService _ai = SchoolAiService();

  /// Fixed marks per subject, per the admission policy.
  static const double subjectWeightage = 50.0;

  // In-memory fallbacks for installations that have not run
  // database/school_entrance_exam_setup.sql yet.
  final Map<String, Map<String, Map<String, dynamic>>> _localCatalog = {};
  final List<Map<String, dynamic>> _localPapers = [];

  // ==========================================
  // SUBJECT + TOPIC CATALOG
  // ==========================================

  /// Returns the subject blueprint for [className].
  ///
  /// DB rows win; the built-in CBSE blueprint is used until the admin adds
  /// their own subjects. Every entry is normalised to:
  /// `{id, class_name, subject, weightage, topics}`.
  Future<List<Map<String, dynamic>>> getSubjects(String className) async {
    final cls = className.trim();
    if (cls.isEmpty) return const [];

    try {
      final rows = await _supabase
          .from('school_entrance_exam_subjects')
          .select()
          .eq('class_name', cls)
          .eq('is_active', true)
          .order('subject', ascending: true);
      final list = List<Map<String, dynamic>>.from(rows)
          .map(_normaliseSubject)
          .where((s) => (s['subject']?.toString() ?? '').isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    final local = _localCatalog[cls];
    if (local != null && local.isNotEmpty) {
      return local.values.toList()
        ..sort((a, b) => (a['subject']?.toString() ?? '')
            .compareTo(b['subject']?.toString() ?? ''));
    }

    return defaultSubjectsForClass(cls);
  }

  Map<String, dynamic> _normaliseSubject(Map<String, dynamic> row) {
    final topics = (row['topics'] as List?)
            ?.map((t) => t?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .toList() ??
        const <String>[];
    return {
      'id': row['id']?.toString() ?? '',
      'class_name': row['class_name']?.toString() ?? '',
      'subject': row['subject']?.toString() ?? '',
      'weightage':
          (row['weightage'] as num?)?.toInt() ?? subjectWeightage.toInt(),
      'topics': topics,
      'is_active': row['is_active'] != false,
    };
  }

  /// Creates or updates a subject blueprint. Weightage is always 50.
  Future<Map<String, dynamic>> saveSubject({
    required String className,
    required String subject,
    required List<String> topics,
  }) async {
    final cls = className.trim();
    final name = subject.trim();
    final cleanTopics = topics
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'class_name': cls,
      'subject': name,
      'weightage': subjectWeightage.toInt(),
      'topics': cleanTopics,
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final saved = await _supabase
          .from('school_entrance_exam_subjects')
          .upsert(payload, onConflict: 'class_name,subject')
          .select()
          .maybeSingle();
      if (saved != null) return _normaliseSubject(saved);
    } catch (_) {}

    final entry = <String, dynamic>{
      'id': 'local-$cls-$name',
      ...payload,
      'topics': cleanTopics,
    };
    _localCatalog.putIfAbsent(cls, () => {})[name] = entry;
    return _normaliseSubject(entry);
  }

  Future<bool> deleteSubject(String id) async {
    if (id.trim().isEmpty) return false;
    try {
      await _supabase
          .from('school_entrance_exam_subjects')
          .delete()
          .eq('id', id);
      return true;
    } catch (_) {}

    for (final subjects in _localCatalog.values) {
      subjects.removeWhere((_, value) => value['id']?.toString() == id);
    }
    return true;
  }

  /// Built-in CBSE blueprint used before the admin customises the catalog.
  List<Map<String, dynamic>> defaultSubjectsForClass(String className) {
    final band = _bandFor(className);
    final subjects = switch (band) {
      'primary' => const ['English', 'Mathematics', 'EVS'],
      'middle' => const [
          'English',
          'Mathematics',
          'Science',
          'Social Studies'
        ],
      'secondary' => const [
          'English',
          'Mathematics',
          'Science',
          'Social Studies'
        ],
      _ => const [
          'English',
          'Mathematics',
          'Physics',
          'Chemistry',
          'Biology'
        ],
    };

    return subjects.map((subject) {
      return <String, dynamic>{
        'id': 'default-$className-$subject',
        'class_name': className,
        'subject': subject,
        'weightage': subjectWeightage.toInt(),
        'topics': _defaultTopics(className, subject, band),
        'is_active': true,
      };
    }).toList();
  }

  String _bandFor(String className) {
    final match = RegExp(r'(\d+)').firstMatch(className);
    final grade = int.tryParse(match?.group(1) ?? '') ?? 1;
    if (grade <= 5) return 'primary';
    if (grade <= 8) return 'middle';
    if (grade <= 10) return 'secondary';
    return 'senior';
  }

  List<String> _defaultTopics(String className, String subject, String band) {
    final previous = _previousClass(className);
    return switch (subject) {
      'Mathematics' => [
          'Previous class ($previous): number operations, shapes and measurement',
          'Target class ($className): core number system and problem solving',
          'Mental maths, patterns and application questions',
        ],
      'English' => [
          'Previous class ($previous): reading fluency and basic grammar',
          'Target class ($className): comprehension and composition',
          'Vocabulary, spelling and sentence construction',
        ],
      'EVS' || 'Science' => [
          'Previous class ($previous): living things and surroundings',
          'Target class ($className): core scientific concepts and observation',
          'Everyday science, health and environment',
        ],
      'Social Studies' => [
          'Previous class ($previous): community, maps and early history',
          'Target class ($className): geography, history and civics',
          'Map reading and current affairs awareness',
        ],
      'Physics' => [
          'Previous class ($previous): motion, force and energy',
          'Target class ($className): mechanics, electricity and waves',
          'Numerical problems and practical applications',
        ],
      'Chemistry' => [
          'Previous class ($previous): matter, atoms and reactions',
          'Target class ($className): bonding, organic and physical chemistry',
          'Equations, formulae and laboratory reasoning',
        ],
      'Biology' => [
          'Previous class ($previous): life processes and diversity',
          'Target class ($className): physiology, genetics and ecology',
          'Diagram-based and application questions',
        ],
      _ => [
          'Previous class ($previous) fundamentals',
          'Target class ($className) core topics',
          'Application and reasoning',
        ],
    };
  }

  String _previousClass(String className) {
    final match = RegExp(r'(\d+)').firstMatch(className);
    final grade = int.tryParse(match?.group(1) ?? '');
    if (grade == null || grade <= 1) return 'pre-primary';
    return 'Class ${grade - 1}';
  }

  /// Expands the blueprint so each subject also references the previous
  /// class's topics. This is what makes the AI paper bridge both syllabi.
  List<Map<String, dynamic>> expandWithPreviousClass(
      List<Map<String, dynamic>> subjects, String className) {
    final previous = _previousClass(className);
    final previousDefaults = defaultSubjectsForClass(previous);
    return subjects.map((s) {
      final topics = (s['topics'] as List?)
              ?.map((t) => t?.toString() ?? '')
              .where((t) => t.isNotEmpty)
              .toList() ??
          <String>[];
      final prior = previousDefaults.firstWhere(
        (p) => (p['subject']?.toString() ?? '').toLowerCase() ==
            (s['subject']?.toString() ?? '').toLowerCase(),
        orElse: () => const <String, dynamic>{},
      );
      final priorTopics = (prior['topics'] as List?)
              ?.map((t) => t?.toString() ?? '')
              .where((t) => t.isNotEmpty)
              .toList() ??
          const <String>[];
      return {
        ...s,
        'topics': {...topics, ...priorTopics}.toList(),
      };
    }).toList();
  }

  // ==========================================
  // PAPER GENERATION
  // ==========================================

  /// Generates (and persists) an entrance paper for [className].
  ///
  /// Tries the LLM pipeline first; if no key is configured, the reply is
  /// unparsable, or the provider is offline, a deterministic template paper is
  /// produced so the desk is never blocked.
  Future<Map<String, dynamic>> generatePaper({
    required String className,
    required String username,
    String mode = 'online',
    String? admissionId,
  }) async {
    final blueprint = expandWithPreviousClass(
      await getSubjects(className),
      className,
    );

    List<Map<String, dynamic>>? generated;
    var model = 'template-fallback';

    try {
      final aiResult = await _ai.generateEntranceExamPaper(
        className: className,
        subjects: blueprint,
        username: username,
        admissionId: admissionId,
      );
      if (aiResult['ok'] == true) {
        final raw = aiResult['subjects'];
        if (raw is List && raw.isNotEmpty) {
          generated = List<Map<String, dynamic>>.from(
            raw.map((e) => Map<String, dynamic>.from(e as Map)),
          );
          model = aiResult['model']?.toString() ?? 'llm';
        }
      }
    } catch (_) {}

    generated ??= _fallbackPaper(blueprint);
    if (model == 'template-fallback') {
      // Numbers are easier to reason about when generated locally.
      model = 'template-fallback';
    }

    final totalMarks = generated.fold<int>(
      0,
      (sum, s) => sum + ((s['weightage'] as num?)?.toInt() ?? 50),
    );

    final paper = <String, dynamic>{
      'id': '',
      'admission_id': admissionId ?? '',
      'class_name': className,
      'mode': mode,
      'subjects': generated,
      'total_marks': totalMarks,
      'generated_by': username,
      'ai_model': model,
      'status': 'generated',
      'instructions':
          'Answer all questions. Each subject carries 50 marks. Duration: 90 minutes.',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final inserted = await _supabase
          .from('school_entrance_exam_papers')
          .insert({
            if (admissionId != null && admissionId.isNotEmpty)
              'admission_id': admissionId,
            'class_name': className,
            'mode': mode,
            'subjects': generated,
            'total_marks': totalMarks,
            'generated_by': username,
            'ai_model': model,
            'status': 'generated',
          })
          .select()
          .maybeSingle();
      if (inserted != null) {
        paper['id'] = inserted['id']?.toString() ?? '';
        paper['created_at'] = inserted['created_at']?.toString() ??
            paper['created_at'];
      }
    } catch (_) {
      paper['id'] = 'local-${DateTime.now().millisecondsSinceEpoch}';
      _localPapers.insert(0, paper);
    }

    return paper;
  }

  /// Deterministic fallback used when the LLM is unavailable.
  ///
  /// The user explicitly asked for a basic pipeline to be refined later, so
  /// these are curriculum-anchored template questions rather than a full item
  /// bank. Every subject totals exactly 50 marks (5 × 10).
  List<Map<String, dynamic>> _fallbackPaper(
      List<Map<String, dynamic>> blueprint) {
    final stems = [
      'Explain the key idea of "{topic}" and support it with one example. (10 marks)',
      'Solve / answer a question based on "{topic}", showing your working. (10 marks)',
      'Choose the correct option about "{topic}".',
      'Write two important points about "{topic}". (10 marks)',
      'Application: use "{topic}" to solve a real-life situation. (10 marks)',
    ];

    return blueprint.map((subject) {
      final subjectName = subject['subject']?.toString() ?? 'General';
      final topics = (subject['topics'] as List?)
              ?.map((t) => t?.toString() ?? '')
              .where((t) => t.isNotEmpty)
              .toList() ??
          ['core concepts'];
      final questions = <Map<String, dynamic>>[];
      for (var i = 0; i < 5; i++) {
        final topic = topics[i % topics.length];
        final stem = stems[i];
        final isObjective = i == 2;
        questions.add({
          'question': stem.replaceAll('{topic}', topic),
          'options': isObjective
              ? const ['Option A', 'Option B', 'Option C', 'Option D']
              : const <String>[],
          'answer': isObjective ? 'Option A' : 'Model answer reviewed by examiner',
          'marks': 10,
          'topic': topic,
        });
      }
      return <String, dynamic>{
        'subject': subjectName,
        'weightage': 50,
        'topics': topics,
        'questions': questions,
      };
    }).toList();
  }

  /// Latest generated paper for an applicant, if any.
  Future<Map<String, dynamic>?> getPaperForAdmission(
      String admissionId) async {
    if (admissionId.trim().isEmpty) return null;
    try {
      final row = await _supabase
          .from('school_entrance_exam_papers')
          .select()
          .eq('admission_id', admissionId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        return {
          ...Map<String, dynamic>.from(row),
          'subjects': List<Map<String, dynamic>>.from(
            (row['subjects'] as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map)),
          ),
          'instructions':
              'Answer all questions. Each subject carries 50 marks. Duration: 90 minutes.',
        };
      }
    } catch (_) {}

    for (final paper in _localPapers) {
      if (paper['admission_id']?.toString() == admissionId) return paper;
    }
    return null;
  }

  /// General helper: convert a subject blueprint plus marks into a result row.
  Map<String, dynamic> buildResult({
    required List<Map<String, dynamic>> subjectScores,
    required String mode,
  }) {
    double total = 0;
    double max = 0;
    for (final s in subjectScores) {
      total += (s['marks'] as num?)?.toDouble() ?? 0;
      max += (s['max'] as num?)?.toDouble() ?? subjectWeightage;
    }
    final pct = max > 0 ? (total / max) * 100 : 0.0;
    return {
      'subject_scores': subjectScores,
      'total_score': double.parse(total.toStringAsFixed(2)),
      'max_score': double.parse(max.toStringAsFixed(2)),
      'percentage': double.parse(pct.toStringAsFixed(2)),
      'grade': _gradeFor(pct),
      'mode': mode,
    };
  }

  String _gradeFor(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'E';
  }

  /// Suggested marks distribution for the offline entry dialog.
  List<Map<String, dynamic>> marksTemplate(
      List<Map<String, dynamic>> subjects) {
    return subjects
        .map((s) => <String, dynamic>{
              'subject': s['subject']?.toString() ?? 'General',
              'marks': 0,
              'max': (s['weightage'] as num?)?.toDouble() ?? subjectWeightage,
            })
        .toList();
  }

  double clampMark(double value, double max) => math.max(0, math.min(value, max));
}
