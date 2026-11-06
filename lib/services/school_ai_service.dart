import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'school_payroll_service.dart';

class SchoolAiService {
  static final SchoolAiService _instance = SchoolAiService._internal();
  factory SchoolAiService() => _instance;
  SchoolAiService._internal();

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolPayrollService _payroll = SchoolPayrollService();

  static String get groqApiKey {
    const fromEnv = String.fromEnvironment('GROQ_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      return dotenv.get('GROQ_API_KEY');
    } catch (_) {}
    return '';
  }

  static String get geminiApiKey {
    const fromEnv = String.fromEnvironment('GEMINI_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      return dotenv.get('GEMINI_API_KEY');
    } catch (_) {}
    return '';
  }

  static const int maxDailyCallsPerUser = 25;
  static final Map<String, int> _dailyUsageCount = {};

  // ==========================================
  // 1. LLM CALLER WITH GROQ -> GEMINI FALLBACK
  // ==========================================

  Future<String> _callLlm({
    required String systemPrompt,
    required String userPrompt,
    required String feature,
    required String username,
    required String role,
  }) async {
    // 1. Check daily quota (in-memory + database)
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final quotaKey = '${username}_$today';
    int currentUsage = _dailyUsageCount[quotaKey] ?? 0;

    try {
      final res = await _supabase
          .from('school_ai_usage_log')
          .select('id')
          .eq('user_username', username)
          .gte('created_at', '${today}T00:00:00');
      final dbCount = List.from(res).length;
      if (dbCount > currentUsage) currentUsage = dbCount;
    } catch (_) {}

    if (currentUsage >= maxDailyCallsPerUser) {
      throw SchoolAiException(
        'Daily AI quota ($maxDailyCallsPerUser queries/day) reached for $username. Quota resets at midnight.',
      );
    }

    String result = '';
    String modelUsed = 'groq/openai/gpt-oss-120b';

    // 2. Try Groq first
    if (groqApiKey.isNotEmpty) {
      try {
        final client = HttpClient();
        final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
        final req = await client.postUrl(uri);
        req.headers.set('Authorization', 'Bearer $groqApiKey');
        req.headers.set('Content-Type', 'application/json');

        final body = jsonEncode({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.6,
          'max_tokens': 1200,
        });

        req.add(utf8.encode(body));
        final res = await req.close();
        final respBody = await res.transform(utf8.decoder).join();
        client.close();

        if (res.statusCode == 200) {
          final parsed = jsonDecode(respBody) as Map<String, dynamic>;
          final choices = parsed['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            result = choices[0]['message']['content']?.toString() ?? '';
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to Gemini if Groq failed or returned empty
    if (result.trim().isEmpty && geminiApiKey.isNotEmpty) {
      try {
        modelUsed = 'gemini-3.8-flash';
        final client = HttpClient();
        final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$geminiApiKey');
        final req = await client.postUrl(uri);
        req.headers.set('Content-Type', 'application/json');

        final body = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$systemPrompt\n\nUser Request: $userPrompt'}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.6,
            'maxOutputTokens': 1200,
          }
        });

        req.add(utf8.encode(body));
        final res = await req.close();
        final respBody = await res.transform(utf8.decoder).join();
        client.close();

        if (res.statusCode == 200) {
          final parsed = jsonDecode(respBody) as Map<String, dynamic>;
          final candidates = parsed['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              result = parts[0]['text']?.toString() ?? '';
            }
          }
        }
      } catch (_) {}
    }

    // 4. Strict error if providers fail or API keys unconfigured (R3: Zero fabrication)
    if (result.trim().isEmpty) {
      throw SchoolAiException(
        'AI services are currently unavailable. Please configure API keys (GROQ_API_KEY / GEMINI_API_KEY) or contact administrator.',
      );
    }

    // 5. Update quota count
    _dailyUsageCount[quotaKey] = currentUsage + 1;

    // 6. Log AI usage
    _logAiUsage(
      username: username,
      role: role,
      feature: feature,
      promptSnippet: userPrompt.length > 100 ? userPrompt.substring(0, 100) : userPrompt,
      modelUsed: modelUsed,
    );

    return result.trim();
  }

  // ==========================================
  // 2. FEATURE 1: AI REPORT CARD REMARKS
  // ==========================================

  Future<Map<String, dynamic>> draftReportCardRemark({
    required String studentUsername,
    required String studentName,
    required String examId,
    required String classId,
    required double marksPercentage,
    required double attendancePercentage,
    String? behaviouralNotes,
    required String teacherUsername,
  }) async {
    const systemPrompt = '''
You are an expert pedagogical CBSE/ICSE educator drafting personalized, constructive, and uplifting report card remarks for a student.
Requirements:
1. Praise specific scholastic and co-scholastic strengths.
2. Provide gentle, actionable advice for improvement areas.
3. Keep the tone inspiring, professional, and empathetic (2 to 4 sentences).
4. Strictly append "[AI draft — teacher approval pending]" at the very beginning of the remark.
''';

    final userPrompt = '''
Student Name: $studentName ($studentUsername)
Class: $classId | Exam: $examId
Academic Performance: ${marksPercentage.toStringAsFixed(1)}%
Attendance Rate: ${attendancePercentage.toStringAsFixed(1)}%
Teacher Behavioural Observations: ${behaviouralNotes ?? "Consistently disciplined, active contributor in class discussions."}
''';

    final rawOutput = await _callLlm(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      feature: 'remarks',
      username: teacherUsername,
      role: 'teacher',
    );

    final remarkId = 'REM-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': remarkId,
      'institute_id': 'SHIV-SCH',
      'student_username': studentUsername,
      'student_name': studentName,
      'exam_id': examId,
      'class_id': classId,
      'draft_remark': rawOutput.startsWith('[AI draft') ? rawOutput : '[AI draft — teacher approval pending] $rawOutput',
      'status': 'draft_pending_approval',
      'teacher_notes': behaviouralNotes,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_ai_remarks').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'AI Remark Drafted: $studentName ($examId)',
        'content': jsonEncode(payload),
        'category': 'AiRemarkDraft',
        'target_audience': 'Teacher',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    return payload;
  }

  Future<void> approveRemark({
    required String remarkId,
    required String teacherUsername,
    String? editedRemark,
    required bool approve,
  }) async {
    final status = approve ? (editedRemark != null ? 'edited' : 'approved') : 'rejected';
    final updates = {
      'status': status,
      if (editedRemark != null) 'draft_remark': editedRemark,
      'approved_by': teacherUsername,
      'approved_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_ai_remarks').update(updates).eq('id', remarkId);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'AI Remark Decision: $remarkId -> $status',
        'content': jsonEncode(updates),
        'category': 'AiRemarkApproved',
        'target_audience': 'Teacher',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    await _payroll.logAudit(
      actorUsername: teacherUsername,
      action: approve ? 'approve_ai_remark' : 'reject_ai_remark',
      entity: 'school_ai_remarks',
      entityId: remarkId,
      newValue: updates,
    );
  }

  // ==========================================
  // 3. FEATURE 2: AUTO QUESTION-PAPER BLUEPRINT
  // ==========================================

  Future<Map<String, dynamic>> generateQuestionPaper({
    required String classId,
    required String subject,
    required String chapters,
    required int totalMarks,
    required String teacherUsername,
    String difficultyMix = '40% Easy, 40% Medium, 20% Hard',
  }) async {
    const systemPrompt = '''
You are a senior CBSE/ICSE curriculum question paper developer.
You generate standardized, balanced question papers adhering strictly to institutional blueprinting rules.
Requirements:
1. Section A: Objective / Multiple Choice Questions (1 Mark each).
2. Section B: Short Answer Questions (2-3 Marks each).
3. Section C: Analytical / Long Answer Questions (4-5 Marks each).
4. Strictly balance difficulty: 40% Easy, 40% Medium, 20% Hard.
5. Include marking rubric in brackets next to each question.
6. Strictly prepend the header "[AI draft — teacher approval pending]" at the top.
''';

    final userPrompt = '''
Generate an official examination paper:
Class: $classId | Subject: $subject
Chapters/Syllabus: $chapters
Total Marks: $totalMarks
Difficulty Distribution: $difficultyMix
''';

    final rawPaper = await _callLlm(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      feature: 'question_paper',
      username: teacherUsername,
      role: 'teacher',
    );

    final paperId = 'QP-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': paperId,
      'institute_id': 'SHIV-SCH',
      'title': '$subject Examination Paper ($classId)',
      'class_id': classId,
      'subject': subject,
      'total_marks': totalMarks,
      'difficulty_mix': {'easy': 40, 'medium': 40, 'hard': 20},
      'content': rawPaper.startsWith('[AI draft') ? rawPaper : '[AI draft — teacher approval pending]\n\n$rawPaper',
      'status': 'draft_pending_approval',
      'created_by': teacherUsername,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_ai_question_papers').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'AI Question Paper Generated: $subject ($paperId)',
        'content': jsonEncode(payload),
        'category': 'AiQuestionPaper',
        'target_audience': 'Teacher',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    return payload;
  }

  // ==========================================
  // 4. FEATURE 3: ASSIGNMENT FEEDBACK DRAFTER
  // ==========================================

  Future<Map<String, dynamic>> draftAssignmentFeedback({
    required String assignmentTitle,
    required String studentName,
    required String studentSubmissionSummary,
    required double score,
    required double maxScore,
    required String teacherUsername,
  }) async {
    const systemPrompt = '''
You are a warm, supportive educator writing feedback on a student's homework submission.
Requirements:
1. Highlight what the student did well.
2. Pinpoint exactly where they made an error or missed an analytical concept.
3. Suggest a 1-line resource or study tip to master the concept.
4. Keep within 3-4 sentences.
5. Strictly prepend "[AI draft — teacher approval pending]".
''';

    final userPrompt = '''
Student: $studentName
Assignment: $assignmentTitle
Score: $score / $maxScore
Student's Work Summary: $studentSubmissionSummary
''';

    final feedback = await _callLlm(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      feature: 'feedback',
      username: teacherUsername,
      role: 'teacher',
    );

    final fbId = 'AFB-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': fbId,
      'institute_id': 'SHIV-SCH',
      'assignment_id': assignmentTitle,
      'student_username': studentName.toLowerCase().replaceAll(' ', '_'),
      'student_name': studentName,
      'draft_feedback': feedback.startsWith('[AI draft') ? feedback : '[AI draft — teacher approval pending] $feedback',
      'status': 'draft_pending_approval',
      'created_by': teacherUsername,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_ai_feedback').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'AI Assignment Feedback Draft: $studentName ($fbId)',
        'content': jsonEncode(payload),
        'category': 'AiAssignmentFeedback',
        'target_audience': 'Teacher',
        'published_at': DateTime.now().toIso8601String(),
      });
    }

    return payload;
  }

  // ==========================================
  // 5. FEATURE 4: CROSS-MODULE RAG CHATBOT
  // ==========================================

  Future<String> askRagAssistant({
    required String question,
    required String userRole,
    required String username,
  }) async {
    final systemPrompt = '''
You are the Shivalik International School Institutional AI Assistant. You possess authoritative real-time knowledge across all school modules:
- Payroll: Disbursed by the 1st week of the month; PF rate is 12%, ESI is 0.75%, PT is ₹200. Loss of Pay (LOP) is deducted strictly as (Gross / Days in Month * Unexcused Absent Days).
- Living Suite: Hostels have 24/7 security. Gate passes require warden biometric authorization and dispatch instant alerts to parents. Infirmary clinic tracks vital signs, allergies, and visits. Cafeteria serves strictly vegetarian balanced menus with cashless RFID student wallets.
- Alumni: Mentorship directory, reunion meets, and infrastructure giving interest forms (strictly no financial transactions).
- Library: Standard overdue fine is ₹5 per day. Fines auto-post directly to the student fee ledger. Book reservations have a 3-day pickup claim window. Free digital e-books are sourced from NCERT and Project Gutenberg.
- Discipline: Multi-tier inquiry protocol with severity classification (Low, Medium, High, Critical). Suspensions strictly role-gated to Principal/Sadmin.
- Multi-School: Tenant isolation ensures strict cryptographic shielding between campuses.
- Governance: Four-Eyes Principle ensures Makers cannot approve their own actions.

Instructions:
1. Provide accurate, concise, helpful, and courteous responses.
2. Tailor answers based on the user's role ($userRole).
3. If an action requires physical authorization, mention the responsible official (e.g., Warden, Principal, Librarian).
''';

    return await _callLlm(
      systemPrompt: systemPrompt,
      userPrompt: question,
      feature: 'rag_chat',
      username: username,
      role: userRole,
    );
  }

  // ==========================================
  // 6. STATS & USAGE METRICS (SP-R13 & SP-R15)
  // ==========================================

  Future<Map<String, dynamic>> getAiStats() async {
    int totalRemarks = 0;
    int approvedRemarks = 0;
    int totalPapers = 0;
    int totalChats = 0;

    try {
      final remRes = await _supabase.from('school_ai_remarks').select('id, status');
      final remList = List<Map<String, dynamic>>.from(remRes);
      totalRemarks = remList.length;
      approvedRemarks = remList.where((r) => r['status'] == 'approved' || r['status'] == 'edited').length;
    } catch (_) {
      totalRemarks = 0;
      approvedRemarks = 0;
    }

    try {
      final qpRes = await _supabase.from('school_ai_question_papers').select('id');
      totalPapers = List<Map<String, dynamic>>.from(qpRes).length;
    } catch (_) {
      totalPapers = 0;
    }

    try {
      final logRes = await _supabase.from('school_ai_usage_log').select('id, feature');
      final logList = List<Map<String, dynamic>>.from(logRes);
      totalChats = logList.where((l) => l['feature'] == 'rag_chat').length;
    } catch (_) {
      totalChats = 0;
    }

    final double approvalRate = totalRemarks > 0 ? (approvedRemarks / totalRemarks) * 100 : 0.0;

    return {
      'total_remarks_drafted': totalRemarks,
      'approved_remarks': approvedRemarks,
      'approval_rate_percent': approvalRate,
      'question_papers_generated': totalPapers,
      'rag_chats_answered': totalChats,
      'daily_quota_limit': maxDailyCallsPerUser,
    };
  }

  Future<void> _logAiUsage({
    required String username,
    required String role,
    required String feature,
    required String promptSnippet,
    required String modelUsed,
  }) async {
    final logId = 'AI-LOG-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': logId,
      'institute_id': 'SHIV-SCH',
      'user_username': username,
      'user_role': role,
      'feature': feature,
      'prompt_snippet': promptSnippet,
      'tokens_used': 150,
      'model_used': modelUsed,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_ai_usage_log').insert(payload);
    } catch (_) {
      // Non-blocking fallback
    }
  }
}

class SchoolAiException implements Exception {
  final String message;
  const SchoolAiException(this.message);

  @override
  String toString() => message;
}
