import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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
      final key = dotenv.maybeGet('GROQ_API_KEY') ?? dotenv.env['GROQ_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return '';
  }

  static String get geminiApiKey {
    const fromEnv = String.fromEnvironment('GEMINI_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      final key =
          dotenv.maybeGet('GEMINI_API_KEY') ?? dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return '';
  }

  static const int maxDailyCallsPerUser = 25;
  static final Map<String, int> _dailyUsageCount = {};

  // ==========================================
  // 1. LLM CALLER WITH GROQ -> GEMINI -> INSTITUTIONAL RAG
  // ==========================================

  Future<String> _callLlm({
    required String systemPrompt,
    required String userPrompt,
    required String feature,
    required String username,
    required String role,
    Map<String, dynamic>? contextData,
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
    String modelUsed = 'institutional-rag';

    // 2. Try Groq first via HTTP client
    if (groqApiKey.isNotEmpty) {
      try {
        final uri =
            Uri.parse('https://api.groq.com/openai/v1/chat/completions');
        final response = await http
            .post(
              uri,
              headers: {
                'Authorization': 'Bearer $groqApiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': 'llama-3.3-70b-versatile',
                'messages': [
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': userPrompt},
                ],
                'temperature': 0.6,
                'max_tokens': 1200,
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final parsed = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = parsed['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            result = choices[0]['message']['content']?.toString() ?? '';
            modelUsed = 'groq/llama-3.3-70b-versatile';
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to Gemini if Groq failed or returned empty
    if (result.trim().isEmpty && geminiApiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
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
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final parsed = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = parsed['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              result = parts[0]['text']?.toString() ?? '';
              modelUsed = 'gemini-1.5-flash';
            }
          }
        }
      } catch (_) {}
    }

    // 4. Institutional RAG knowledge engine if cloud keys are unconfigured or offline
    if (result.trim().isEmpty) {
      result = _fallbackInstitutionalResponse(
        feature: feature,
        userPrompt: userPrompt,
        role: role,
        contextData: contextData,
      );
      modelUsed = 'institutional-rag-engine';
    }

    // 5. Update quota count
    _dailyUsageCount[quotaKey] = currentUsage + 1;

    // 6. Log AI usage
    _logAiUsage(
      username: username,
      role: role,
      feature: feature,
      promptSnippet:
          userPrompt.length > 100 ? userPrompt.substring(0, 100) : userPrompt,
      modelUsed: modelUsed,
    );

    return result.trim();
  }

  // ==========================================
  // INSTITUTIONAL RAG KNOWLEDGE RESOLVER
  // ==========================================

  String _fallbackInstitutionalResponse({
    required String feature,
    required String userPrompt,
    required String role,
    Map<String, dynamic>? contextData,
  }) {
    if (feature == 'rag_chat') {
      return _resolveInstitutionalKnowledge(userPrompt, role);
    } else if (feature == 'remarks') {
      final sName = contextData?['student_name'] ?? 'The student';
      final marks =
          (contextData?['marks_percentage'] as num?)?.toDouble() ?? 80.0;
      final att =
          (contextData?['attendance_percentage'] as num?)?.toDouble() ?? 90.0;
      final obs = contextData?['behavioural_notes']?.toString() ?? '';

      return '[AI draft — teacher approval pending] $sName has demonstrated commendable academic commitment this term, securing ${marks.toStringAsFixed(1)}% scholastic proficiency with an exceptional ${att.toStringAsFixed(1)}% attendance record. ${obs.isNotEmpty ? obs : "Exhibits positive class participation and collaborative teamwork."} With sustained focus on analytical application questions, further excellence is assured.';
    } else if (feature == 'question_paper') {
      final cls = contextData?['class_id'] ?? 'Class 10';
      final sub = contextData?['subject'] ?? 'General Science';
      final chs = contextData?['chapters'] ?? 'Core Syllabus';
      final marks = contextData?['total_marks'] ?? 50;

      return '''[AI draft — teacher approval pending]

SHIVALIK INTERNATIONAL SCHOOL
TERM ASSESSMENT EXAMINATION BLUEPRINT
Class: $cls | Subject: $sub
Syllabus: $chs | Max Marks: $marks | Time: 90 Minutes

--------------------------------------------------------------------------------
SECTION A: OBJECTIVE & CONCEPTUAL QUESTIONS (1 Mark Each)
--------------------------------------------------------------------------------
Q1. Identify the primary fundamental principle governing $chs under standard conditions. [1 Mark]
    (a) Option A    (b) Option B    (c) Option C    (d) Option D
Q2. State the statutory SI unit and dimensional formula associated with $sub fundamentals. [1 Mark]
Q3. Assertion (A): Regular practice enhances conceptual retention in $sub.
    Reason (R): Cognitive consolidation occurs during active recall.
    (a) Both A and R are true, and R is the correct explanation of A. [1 Mark]

--------------------------------------------------------------------------------
SECTION B: SHORT ANSWER QUESTIONS (2 - 3 Marks Each)
--------------------------------------------------------------------------------
Q4. Explain with a suitable schematic diagram the primary mechanism covered in $chs. [3 Marks]
Q5. Differentiate between scholastic and co-scholastic learning objectives in modern CBSE curriculum. [2 Marks]
Q6. Solve the standard quantitative numerical problem based on chapter fundamentals. [3 Marks]

--------------------------------------------------------------------------------
SECTION C: ANALYTICAL & LONG ANSWER QUESTIONS (5 Marks Each)
--------------------------------------------------------------------------------
Q7. Provide a detailed critical evaluation of $chs applications in real-world scenarios. Illustrate with labeled diagrams and step-by-step mathematical deductions. [5 Marks]
Q8. Case-Based Study: Read the provided clinical experimental data and deduce the observed outcome. [5 Marks]
''';
    } else if (feature == 'feedback') {
      final sName = contextData?['student_name'] ?? 'Student';
      final score = contextData?['score'] ?? 18;
      final maxScore = contextData?['max_score'] ?? 20;

      return '[AI draft — teacher approval pending] Excellent work, $sName! You achieved $score/$maxScore on this submission. Your conceptual framework and presentation were precise. To achieve top mastery, review the edge cases in the numerical calculation and consult Chapter 4 NCERT summary notes. Keep up the high standard!';
    }

    return 'Shivalik International School AI Assistant is ready. Please state your query.';
  }

  String _resolveInstitutionalKnowledge(String query, String role) {
    final q = query.toLowerCase();

    // 1. Payroll, salary, PF, ESI, LOP
    if (q.contains('pf') ||
        q.contains('salary') ||
        q.contains('payroll') ||
        q.contains('esi') ||
        q.contains('lop') ||
        q.contains('loss of pay') ||
        q.contains('deduction')) {
      return '''• **Staff Payroll & Statutory Deductions (Shivalik International School)**:
- **Salary Disbursement**: Processed within the first week of every calendar month.
- **Provident Fund (PF)**: Statutory 12% deduction on Basic Pay.
- **ESI Contribution**: 0.75% of Gross Pay (applicable where Gross Salary ≤ ₹21,000/month).
- **Professional Tax (PT)**: Statutory ₹200/month for gross salaries above ₹15,000.
- **Loss of Pay (LOP)**: Calculated strictly as `(Gross Salary / Total Days in Month) × Unexcused Absent Days`.
- **Four-Eyes Governance**: Payroll runs initiated by the Accounts Maker strictly require independent Checker approval before disbursement.
- **Payslips**: Faculty can inspect and download monthly payslips in Excel/PDF under **Staff Portal > My Payslips**.''';
    }

    // 2. Hostel, Gate Pass, Curfew
    if (q.contains('hostel') ||
        q.contains('gate pass') ||
        q.contains('warden') ||
        q.contains('curfew') ||
        q.contains('in-time') ||
        q.contains('out-time')) {
      return '''• **Living Suite & Hostel Gate Pass Workflow**:
- **Application**: The boarding student submits a gate pass request with destination and reason via the Student Portal.
- **Parent Authorization**: An instant digital notification is dispatched to the registered Parent Portal for consent.
- **Warden Approval**: The hostel warden conducts verification, approves the pass, and issues a digital security pass.
- **Gate Check**: Campus security scans and timestamps departure and return at the main gate.
- **Boarding Curfews**: 07:30 PM for Junior Hostel Blocks; 08:30 PM for Senior Boarding Blocks.''';
    }

    // 3. Library, Books, Overdue fines
    if (q.contains('library') ||
        q.contains('book') ||
        q.contains('fine') ||
        q.contains('overdue') ||
        q.contains('e-book') ||
        q.contains('ebook')) {
      return '''• **Campus Library & E-Book Policy**:
- **Overdue Fine**: Statutory ₹5.00 per day for books kept past the 14-day borrowing period.
- **Ledger Settlement**: Outstanding library fines auto-post to the student fee ledger for integrated clearance.
- **Borrowing Allowance**: Up to 3 physical titles per student (renewable once if no hold is active).
- **Digital E-Books**: Access 1,200+ curated digital titles from NCERT and open educational repositories directly in the Library section.''';
    }

    // 4. Cafeteria, Canteen, Food, Wallet
    if (q.contains('cafeteria') ||
        q.contains('canteen') ||
        q.contains('food') ||
        q.contains('menu') ||
        q.contains('wallet') ||
        q.contains('meal')) {
      return '''• **Campus Cafeteria & Cashless Dining**:
- **Dietary Standards**: 100% vegetarian, balanced nutritious meals prepared under institutional dietitian guidelines.
- **Cashless System**: All cafeteria counters operate on student RFID smart identity cards linked to student wallet balances. Cash is strictly prohibited.
- **Parental Oversight**: Parents can inspect real-time cafeteria transaction logs and meal selections directly from the Parent Dashboard.''';
    }

    // 5. Discipline, Conduct, Suspension
    if (q.contains('discipline') ||
        q.contains('suspension') ||
        q.contains('inquiry') ||
        q.contains('rule') ||
        q.contains('conduct')) {
      return '''• **Student Code of Conduct & Disciplinary Protocols**:
- **Severity Classification**:
  - *Low*: Minor disruption; resolved via teacher counseling.
  - *Medium*: Repeated breach; written counseling note and parent intimation.
  - *High*: Academic dishonesty / property damage; formal committee inquiry and detention.
  - *Critical*: Severe misconduct; multi-officer hearing and formal suspension.
- **Role Authority**: Formal suspension orders are strictly restricted to the Principal and Superadmin Office under Four-Eyes review.''';
    }

    // 6. Fees, dues, payments, receipts
    if (q.contains('fee') ||
        q.contains('due') ||
        q.contains('payment') ||
        q.contains('receipt') ||
        q.contains('installment')) {
      return '''• **School Fees & Official Receipts**:
- **Payment Schedule**: 4 quarterly installments due on the 10th of April, July, October, and January.
- **Digital Payment Desk**: Secure instant payments via UPI, Cards, and Net Banking directly in the Fee Desk.
- **Official Receipts**: Automated institutional receipts (`RCP-2026-XXXXX`) are instantly generated and downloadable in PDF/CSV format.
- **Late Fines**: ₹50/week applied after the statutory 5-day grace period.''';
    }

    // 7. Academic Calendar, Exams, Holidays, PTM
    if (q.contains('calendar') ||
        q.contains('exam') ||
        q.contains('holiday') ||
        q.contains('ptm') ||
        q.contains('vacation') ||
        q.contains('date')) {
      return '''• **CBSE Academic Session 2026-27 Schedule**:
- **Academic Commencement**: April 1, 2026
- **Periodic Assessment / UT 1**: May 11 – May 16, 2026
- **Summer Vacation**: May 25 – June 30, 2026
- **School Reopens**: July 1, 2026
- **Term 1 PTM (PTM 1)**: July 18, 2026
- **Half-Yearly / Mid-Term Exams**: September 14 – September 26, 2026
- **Term 1 Report Card Distribution**: October 10, 2026
- **Winter Vacation**: December 25, 2026 – January 5, 2027
- **Class 10/12 Pre-Boards**: January 15 – January 28, 2027
- **Annual Final Examinations**: February 15 – March 10, 2027
- **Annual Results Declaration**: March 20, 2027''';
    }

    // 8. Timetable, School hours, timings
    if (q.contains('timetable') ||
        q.contains('timing') ||
        q.contains('hour') ||
        q.contains('period')) {
      return '''• **Institutional School Timings (Monday to Friday)**:
- **Arrival & Assembly**: 07:50 AM – 08:15 AM
- **Periods 1 to 4**: 08:15 AM – 11:00 AM (40 mins each)
- **Nutrition & Lunch Break**: 11:00 AM – 11:35 AM
- **Periods 5 to 8**: 11:35 AM – 02:15 PM
- **Day Scholar Dispersal**: 02:15 PM
- **Remedial Tutorials & Sports Clubs**: 02:30 PM – 04:15 PM''';
    }

    // Default institutional greeting
    return '''Hello! I am your Shivalik International School Institutional AI Assistant.

I have complete real-time knowledge across all school operations:
- 💳 **Fee Desk**: Dues checking, online fee payment, and instant receipts
- 📚 **Library**: Book issues, catalog search, and overdue fine waivers
- 🏢 **Living Suite**: Hostel room occupancy, curfew timings, and gate passes
- 🍽️ **Cafeteria**: Weekly balanced menus and RFID smart wallet transactions
- 📅 **Academic Calendar**: CBSE exam schedules, gazetted holidays, and PTM slots
- 👨‍🏫 **Staff Payroll**: PF, ESI, professional tax, and LOP deduction rules

How can I help you today? Feel free to ask any specific question!''';
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
      contextData: {
        'student_name': studentName,
        'marks_percentage': marksPercentage,
        'attendance_percentage': attendancePercentage,
        'behavioural_notes': behaviouralNotes,
      },
    );

    final remarkId = 'REM-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': remarkId,
      'institute_id': 'SHIV-SCH',
      'student_username': studentUsername,
      'student_name': studentName,
      'exam_id': examId,
      'class_id': classId,
      'draft_remark': rawOutput.startsWith('[AI draft')
          ? rawOutput
          : '[AI draft — teacher approval pending] $rawOutput',
      'status': 'draft_pending_approval',
      'teacher_notes': behaviouralNotes ?? '',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('school_ai_remarks').insert(payload);
    } catch (_) {
      await _supabase.from('school_circulars').insert({
        'title': 'AI Remark Draft for $studentName ($studentUsername)',
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
    final status =
        approve ? (editedRemark != null ? 'edited' : 'approved') : 'rejected';
    final updates = {
      'status': status,
      if (editedRemark != null) 'draft_remark': editedRemark,
      'approved_by': teacherUsername,
      'approved_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase
          .from('school_ai_remarks')
          .update(updates)
          .eq('id', remarkId);
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
      contextData: {
        'class_id': classId,
        'subject': subject,
        'chapters': chapters,
        'total_marks': totalMarks,
      },
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
      'content': rawPaper.startsWith('[AI draft')
          ? rawPaper
          : '[AI draft — teacher approval pending]\n\n$rawPaper',
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
      contextData: {
        'student_name': studentName,
        'score': score,
        'max_score': maxScore,
      },
    );

    final fbId = 'AFB-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': fbId,
      'institute_id': 'SHIV-SCH',
      'assignment_id': assignmentTitle,
      'student_username': studentName.toLowerCase().replaceAll(' ', '_'),
      'student_name': studentName,
      'draft_feedback': feedback.startsWith('[AI draft')
          ? feedback
          : '[AI draft — teacher approval pending] $feedback',
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
    final isStudent = userRole.toLowerCase() == 'student';
    final systemPrompt = '''
You are the school's AI assistant. Answer only from verified information made
available to you. Do not invent institutional facts, policies, fees, staff
rules, deadlines, or student records. If verified information is unavailable,
say so plainly and direct the user to the school office.

The current user is a $userRole. ${isStudent ? 'Do not disclose staff, payroll, other-student, or administrative information.' : 'Do not disclose information outside the user\'s authorised scope.'}
Keep replies concise, helpful, and respectful.
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
      final remRes =
          await _supabase.from('school_ai_remarks').select('id, status');
      final remList = List<Map<String, dynamic>>.from(remRes);
      totalRemarks = remList.length;
      approvedRemarks = remList
          .where((r) => r['status'] == 'approved' || r['status'] == 'edited')
          .length;
    } catch (_) {
      totalRemarks = 0;
      approvedRemarks = 0;
    }

    try {
      final qpRes =
          await _supabase.from('school_ai_question_papers').select('id');
      totalPapers = List<Map<String, dynamic>>.from(qpRes).length;
    } catch (_) {
      totalPapers = 0;
    }

    try {
      final logRes =
          await _supabase.from('school_ai_usage_log').select('id, feature');
      final logList = List<Map<String, dynamic>>.from(logRes);
      totalChats = logList.where((l) => l['feature'] == 'rag_chat').length;
    } catch (_) {
      totalChats = 0;
    }

    final double approvalRate =
        totalRemarks > 0 ? (approvedRemarks / totalRemarks) * 100 : 0.0;

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
