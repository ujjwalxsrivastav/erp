import 'package:supabase_flutter/supabase_flutter.dart';

/// Examination (COE) module service.
///
/// Plain service class in the same style as FinanceService:
/// `Supabase.instance.client`, try/catch + print, safe defaults,
/// and `Map<String, dynamic>` payloads throughout.
class ExaminationService {
  final _supabase = Supabase.instance.client;

  // ============================================================
  // GRADE HELPER (single source of truth for the whole module)
  // 10-point scale on percentage of max marks:
  //   >=90 O(10) | 80-89 A+(9) | 70-79 A(8) | 60-69 B+(7)
  //   50-59 B(6) | 40-49 C(5)  | <40 F(0)
  // A student passes only when total >= passingMarks (ordinance).
  // ============================================================
  static Map<String, dynamic> computeGrade({
    required double total,
    double maxMarks = 100,
    double passingMarks = 40,
  }) {
    final pct = maxMarks > 0 ? (total / maxMarks) * 100 : 0.0;
    String grade;
    double point;
    if (pct >= 90) {
      grade = 'O';
      point = 10;
    } else if (pct >= 80) {
      grade = 'A+';
      point = 9;
    } else if (pct >= 70) {
      grade = 'A';
      point = 8;
    } else if (pct >= 60) {
      grade = 'B+';
      point = 7;
    } else if (pct >= 50) {
      grade = 'B';
      point = 6;
    } else if (pct >= 40) {
      grade = 'C';
      point = 5;
    } else {
      grade = 'F';
      point = 0;
    }
    final passed = total >= passingMarks && grade != 'F';
    return {
      'grade': grade,
      'grade_point': point,
      'percentage': pct,
      'status': passed ? 'pass' : 'fail',
    };
  }

  /// SGPA = sum(credits x gradePoint) / sum(credits).
  /// Failed subjects earn 0 points but their credits still count,
  /// which is the standard tabulation rule.
  static double computeSgpa(List<Map<String, dynamic>> results) {
    double weighted = 0;
    double creditsTotal = 0;
    for (final r in results) {
      final credits = (r['credits'] as num?)?.toDouble() ?? 3;
      final gp = (r['grade_point'] as num?)?.toDouble() ?? 0;
      weighted += credits * gp;
      creditsTotal += credits;
    }
    if (creditsTotal == 0) return 0;
    return weighted / creditsTotal;
  }

  // ============================================================
  // SESSIONS
  // ============================================================
  Future<List<Map<String, dynamic>>> getSessions({String? status}) async {
    try {
      var query = _supabase.from('exam_sessions').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get exam sessions error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    try {
      final r = await _supabase
          .from('exam_sessions')
          .select()
          .eq('id', sessionId)
          .single();
      return Map<String, dynamic>.from(r);
    } catch (e) {
      print('Get exam session error: $e');
      return null;
    }
  }

  Future<bool> createSession(Map<String, dynamic> data) async {
    try {
      await _supabase.from('exam_sessions').insert(data);
      return true;
    } catch (e) {
      print('Create exam session error: $e');
      return false;
    }
  }

  Future<bool> updateSessionStatus(String sessionId, String status) async {
    try {
      await _supabase.from('exam_sessions').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
      return true;
    } catch (e) {
      print('Update session status error: $e');
      return false;
    }
  }

  // ============================================================
  // SESSION SUBJECTS (date-sheet)
  // ============================================================
  Future<List<Map<String, dynamic>>> getSessionSubjects(
      String sessionId) async {
    try {
      final r = await _supabase
          .from('exam_subjects')
          .select()
          .eq('session_id', sessionId)
          .order('exam_date', ascending: true);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get session subjects error: $e');
      return [];
    }
  }

  Future<bool> addSessionSubject({
    required String sessionId,
    required String subjectName,
    String? subjectId,
    String? examDate,
    String? startTime,
    String? endTime,
    double maxMarks = 100,
    double passingMarks = 40,
    String? room,
  }) async {
    try {
      await _supabase.from('exam_subjects').insert({
        'session_id': sessionId,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'exam_date': examDate,
        'start_time': startTime,
        'end_time': endTime,
        'max_marks': maxMarks,
        'passing_marks': passingMarks,
        'room': room,
      });
      return true;
    } catch (e) {
      print('Add session subject error: $e');
      return false;
    }
  }

  Future<bool> deleteSessionSubject(String id) async {
    try {
      await _supabase.from('exam_subjects').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Delete session subject error: $e');
      return false;
    }
  }

  /// Master subjects list (subjects table) for dropdowns in the COE UI.
  Future<List<Map<String, dynamic>>> getSubjectsMaster() async {
    try {
      final r = await _supabase
          .from('subjects')
          .select('subject_id, subject_name, department')
          .order('subject_name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get subjects master error: $e');
      return [];
    }
  }

  // ============================================================
  // ELIGIBILITY + REGISTRATIONS
  // Eligibility is joined in Dart: students of the session semester
  // (student_details) + outstanding dues (student_fee_allocations)
  // + any detention already recorded on their registration.
  // ============================================================
  Future<List<Map<String, dynamic>>> getEligibleStudents(
      String sessionId) async {
    try {
      final session = await getSessionById(sessionId);
      if (session == null) return [];
      final semester = session['semester'];

      var studentQuery = _supabase.from('student_details').select();
      if (semester != null) {
        studentQuery = studentQuery.eq('semester', semester);
      }
      final students = await studentQuery.order('name');
      final registrations = await getRegistrations(sessionId);
      final regByStudent = <String, Map<String, dynamic>>{
        for (final r in registrations) r['student_id'].toString(): r,
      };

      final result = <Map<String, dynamic>>[];
      for (final s in students) {
        final studentId = s['student_id'].toString();
        // Outstanding dues from Finance allocations.
        double dues = 0;
        try {
          final allocs = await _supabase
              .from('student_fee_allocations')
              .select('balance_amount, status')
              .eq('student_id', studentId)
              .neq('status', 'paid')
              .neq('status', 'waived')
              .neq('status', 'cancelled');
          for (final a in allocs) {
            dues += (a['balance_amount'] as num?)?.toDouble() ?? 0;
          }
        } catch (e) {
          print('Dues check error for $studentId: $e');
        }

        final reg = regByStudent[studentId];
        String eligibility;
        String? reason;
        if (reg != null && reg['eligibility_status'] != null) {
          eligibility = reg['eligibility_status'].toString();
          reason = reg['detention_reason']?.toString();
        } else if (dues > 0) {
          eligibility = 'conditional';
          reason = 'Fee dues pending: Rs ${dues.toStringAsFixed(0)}';
        } else {
          eligibility = 'eligible';
        }

        result.add({
          ...Map<String, dynamic>.from(s),
          'dues_balance': dues,
          'has_dues': dues > 0,
          'eligibility_status': eligibility,
          'detention_reason': reason,
          'registration_id': reg?['id'],
          'registration_status': reg?['status'],
          'fee_paid': reg?['fee_paid'] ?? false,
        });
      }
      return result;
    } catch (e) {
      print('Get eligible students error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRegistrations(
      String sessionId) async {
    try {
      final r = await _supabase
          .from('exam_registrations')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get registrations error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStudentRegistration(
      String sessionId, String studentId) async {
    try {
      final r = await _supabase
          .from('exam_registrations')
          .select()
          .eq('session_id', sessionId)
          .eq('student_id', studentId)
          .limit(1);
      if (r.isEmpty) return null;
      return Map<String, dynamic>.from(r.first);
    } catch (e) {
      print('Get student registration error: $e');
      return null;
    }
  }

  Future<bool> registerStudent({
    required String sessionId,
    required String studentId,
    required List<Map<String, dynamic>> subjects,
    bool feePaid = false,
    String? feeReceiptId,
    String eligibilityStatus = 'eligible',
    String? detentionReason,
  }) async {
    try {
      await _supabase.from('exam_registrations').upsert({
        'session_id': sessionId,
        'student_id': studentId,
        'subjects': subjects,
        'fee_paid': feePaid,
        'fee_receipt_id': feeReceiptId,
        'eligibility_status': eligibilityStatus,
        'detention_reason': detentionReason,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id,student_id');
      return true;
    } catch (e) {
      print('Register student error: $e');
      return false;
    }
  }

  Future<bool> verifyRegistration(String registrationId) async {
    try {
      await _supabase.from('exam_registrations').update({
        'status': 'verified',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', registrationId);
      return true;
    } catch (e) {
      print('Verify registration error: $e');
      return false;
    }
  }

  Future<bool> setRegistrationEligibility(
      String registrationId, String eligibilityStatus,
      {String? detentionReason}) async {
    try {
      await _supabase.from('exam_registrations').update({
        'eligibility_status': eligibilityStatus,
        'detention_reason': detentionReason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', registrationId);
      return true;
    } catch (e) {
      print('Set eligibility error: $e');
      return false;
    }
  }

  // ============================================================
  // HALL TICKETS
  // ============================================================
  Future<Map<String, dynamic>?> issueHallTicket(
      String registrationId) async {
    try {
      // Already issued? Return the existing ticket (idempotent).
      final existing = await _supabase
          .from('hall_tickets')
          .select()
          .eq('registration_id', registrationId)
          .limit(1);
      if (existing.isNotEmpty) {
        return Map<String, dynamic>.from(existing.first);
      }

      final reg = await _supabase
          .from('exam_registrations')
          .select()
          .eq('id', registrationId)
          .single();
      final year = DateTime.now().year;
      final countRows = await _supabase.from('hall_tickets').select('id');
      final seq = (countRows.length + 1).toString().padLeft(4, '0');
      final ticketNo = 'HT-$year-$seq';
      final qrData =
          'TICKET:$ticketNo|STUDENT:${reg['student_id']}|SESSION:${reg['session_id']}';

      final inserted = await _supabase.from('hall_tickets').insert({
        'registration_id': registrationId,
        'ticket_no': ticketNo,
        'qr_data': qrData,
      }).select().single();

      await _supabase.from('exam_registrations').update({
        'status': 'hall_ticket_issued',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', registrationId);

      return Map<String, dynamic>.from(inserted);
    } catch (e) {
      print('Issue hall ticket error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getHallTicket(
      String studentId, String sessionId) async {
    try {
      final reg = await getStudentRegistration(sessionId, studentId);
      if (reg == null) return null;
      final tickets = await _supabase
          .from('hall_tickets')
          .select()
          .eq('registration_id', reg['id'])
          .limit(1);
      if (tickets.isEmpty) return null;
      final ticket = Map<String, dynamic>.from(tickets.first);
      ticket['student_id'] = reg['student_id'];
      ticket['session_id'] = reg['session_id'];
      ticket['subjects'] = reg['subjects'];
      ticket['registration_status'] = reg['status'];
      return ticket;
    } catch (e) {
      print('Get hall ticket error: $e');
      return null;
    }
  }

  // ============================================================
  // RESULTS
  // ============================================================
  Future<bool> enterResult({
    required String sessionId,
    required String studentId,
    String? subjectId,
    String? subjectName,
    required double internalMarks,
    required double externalMarks,
    double maxMarks = 100,
    double passingMarks = 40,
    double credits = 3,
  }) async {
    try {
      final total = internalMarks + externalMarks;
      final g = computeGrade(
          total: total, maxMarks: maxMarks, passingMarks: passingMarks);
      final sid = subjectId ?? subjectName;
      await _supabase.from('exam_results').upsert({
        'session_id': sessionId,
        'student_id': studentId,
        'subject_id': sid,
        'subject_name': subjectName,
        'internal_marks': internalMarks,
        'external_marks': externalMarks,
        'total': total,
        'grade': g['grade'],
        'grade_point': g['grade_point'],
        'credits': credits,
        'status': g['status'],
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id,student_id,subject_id');
      return true;
    } catch (e) {
      print('Enter result error: $e');
      return false;
    }
  }

  /// Bulk-build results for a session from the unified student_marks
  /// table: endsem = external, midterm+quiz+assignment = internal.
  Future<int> importResultsFromMarks(String sessionId) async {
    try {
      final subjects = await getSessionSubjects(sessionId);
      if (subjects.isEmpty) return 0;
      int created = 0;
      for (final sub in subjects) {
        final subjectId = sub['subject_id']?.toString();
        if (subjectId == null || subjectId.isEmpty) continue;
        final marks = await _supabase
            .from('student_marks')
            .select()
            .eq('subject_id', subjectId);
        // Group marks per student.
        final byStudent = <String, Map<String, double>>{};
        for (final m in marks) {
          final sid = m['student_id'].toString();
          byStudent.putIfAbsent(sid, () => {'internal': 0, 'external': 0});
          final obtained = (m['marks_obtained'] as num?)?.toDouble() ?? 0;
          if (m['exam_type'] == 'endsem') {
            byStudent[sid]!['external'] =
                (byStudent[sid]!['external'] ?? 0) + obtained;
          } else {
            byStudent[sid]!['internal'] =
                (byStudent[sid]!['internal'] ?? 0) + obtained;
          }
        }
        for (final entry in byStudent.entries) {
          final ok = await enterResult(
            sessionId: sessionId,
            studentId: entry.key,
            subjectId: subjectId,
            subjectName: sub['subject_name']?.toString(),
            internalMarks: entry.value['internal'] ?? 0,
            externalMarks: entry.value['external'] ?? 0,
            maxMarks: (sub['max_marks'] as num?)?.toDouble() ?? 100,
            passingMarks: (sub['passing_marks'] as num?)?.toDouble() ?? 40,
          );
          if (ok) created++;
        }
      }
      return created;
    } catch (e) {
      print('Import results from marks error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getSessionResults(
      String sessionId) async {
    try {
      final r = await _supabase
          .from('exam_results')
          .select()
          .eq('session_id', sessionId)
          .order('student_id')
          .order('subject_id');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get session results error: $e');
      return [];
    }
  }

  Future<bool> publishResults(String sessionId) async {
    try {
      await _supabase
          .from('exam_results')
          .update({'is_published': true}).eq('session_id', sessionId);
      await updateSessionStatus(sessionId, 'result_declared');
      return true;
    } catch (e) {
      print('Publish results error: $e');
      return false;
    }
  }

  /// Published results for one student, enriched with session names.
  Future<List<Map<String, dynamic>>> getStudentResults(
      String studentId) async {
    try {
      final r = await _supabase
          .from('exam_results')
          .select()
          .eq('student_id', studentId)
          .eq('is_published', true)
          .order('created_at', ascending: false);
      final results = List<Map<String, dynamic>>.from(r);
      if (results.isEmpty) return results;
      final sessions = await getSessions();
      final nameById = <String, String>{
        for (final s in sessions) s['id'].toString(): s['name'].toString(),
      };
      for (final row in results) {
        row['session_name'] = nameById[row['session_id'].toString()] ?? '';
      }
      return results;
    } catch (e) {
      print('Get student results error: $e');
      return [];
    }
  }

  // ============================================================
  // TABULATION (student-wise SGPA sheet for a session)
  // ============================================================
  Future<List<Map<String, dynamic>>> getTabulation(
      String sessionId) async {
    try {
      final results = await getSessionResults(sessionId);
      final byStudent = <String, List<Map<String, dynamic>>>{};
      for (final r in results) {
        byStudent
            .putIfAbsent(r['student_id'].toString(), () => [])
            .add(r);
      }
      // Student names/departments for display.
      final details = await _supabase.from('student_details').select(
          'student_id, name, department, section, semester');
      final infoById = <String, Map<String, dynamic>>{
        for (final d in details) d['student_id'].toString(): d,
      };
      final sheet = <Map<String, dynamic>>[];
      byStudent.forEach((studentId, rows) {
        final info = infoById[studentId];
        final backlogs =
            rows.where((r) => r['status'] != 'pass').length;
        sheet.add({
          'student_id': studentId,
          'name': info?['name'] ?? studentId,
          'department': info?['department'] ?? '',
          'section': info?['section'] ?? '',
          'results': rows,
          'sgpa': computeSgpa(rows),
          'total_credits': rows.fold<double>(
              0, (sum, r) => sum + ((r['credits'] as num?)?.toDouble() ?? 3)),
          'backlogs': backlogs,
          'overall_status': backlogs == 0 ? 'pass' : 'backlog',
        });
      });
      sheet.sort((a, b) =>
          (a['name'] as String).compareTo(b['name'] as String));
      return sheet;
    } catch (e) {
      print('Get tabulation error: $e');
      return [];
    }
  }

  // ============================================================
  // REVALUATION
  // ============================================================
  Future<bool> applyRevaluation({
    required String resultId,
    required String studentId,
    String? subjectId,
    String? subjectName,
    double? originalMarks,
    double feeAmount = 500,
  }) async {
    try {
      await _supabase.from('revaluation_requests').insert({
        'result_id': resultId,
        'student_id': studentId,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'original_marks': originalMarks,
        'fee_amount': feeAmount,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      print('Apply revaluation error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getRevaluationRequests(
      {String? status}) async {
    try {
      var query = _supabase.from('revaluation_requests').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('applied_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get revaluation requests error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStudentRevaluationRequests(
      String studentId) async {
    try {
      final r = await _supabase
          .from('revaluation_requests')
          .select()
          .eq('student_id', studentId)
          .order('applied_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get student revaluation requests error: $e');
      return [];
    }
  }

  /// Process a request. On approve, [revisedMarks] is the new TOTAL
  /// for the paper: the linked result row is updated and its grade
  /// is recomputed with the same grade helper.
  Future<bool> processRevaluation(
    String requestId, {
    required bool approve,
    double? revisedMarks,
    String? processedBy,
  }) async {
    try {
      if (!approve) {
        await _supabase.from('revaluation_requests').update({
          'status': 'rejected',
          'processed_by': processedBy,
          'processed_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);
        return true;
      }
      if (revisedMarks == null) return false;

      final req = await _supabase
          .from('revaluation_requests')
          .select()
          .eq('id', requestId)
          .single();
      final resultId = req['result_id']?.toString();

      if (resultId != null) {
        final result = await _supabase
            .from('exam_results')
            .select()
            .eq('id', resultId)
            .single();
        // Ordinance limits for this paper, if the subject is scheduled.
        double maxMarks = 100;
        double passingMarks = 40;
        final subs = await getSessionSubjects(
            result['session_id'].toString());
        for (final s in subs) {
          if (s['subject_id']?.toString() ==
              result['subject_id']?.toString()) {
            maxMarks = (s['max_marks'] as num?)?.toDouble() ?? 100;
            passingMarks =
                (s['passing_marks'] as num?)?.toDouble() ?? 40;
            break;
          }
        }
        final internal =
            (result['internal_marks'] as num?)?.toDouble() ?? 0;
        final newExternal = (revisedMarks - internal).clamp(0, maxMarks);
        final g = computeGrade(
            total: revisedMarks,
            maxMarks: maxMarks,
            passingMarks: passingMarks);
        await _supabase.from('exam_results').update({
          'external_marks': newExternal,
          'total': revisedMarks,
          'grade': g['grade'],
          'grade_point': g['grade_point'],
          'status': g['status'],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', resultId);
      }

      await _supabase.from('revaluation_requests').update({
        'status': 'completed',
        'revised_marks': revisedMarks,
        'processed_by': processedBy,
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      return true;
    } catch (e) {
      print('Process revaluation error: $e');
      return false;
    }
  }

  // ============================================================
  // DASHBOARD STATS (COE)
  // ============================================================
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final sessions = await _supabase.from('exam_sessions').select('id, status');
      final registrations =
          await _supabase.from('exam_registrations').select('id');
      final tickets = await _supabase.from('hall_tickets').select('id');
      final pendingRevals = await _supabase
          .from('revaluation_requests')
          .select('id')
          .eq('status', 'pending');
      final results = await _supabase
          .from('exam_results')
          .select('id, is_published');

      int declared = 0;
      for (final s in sessions) {
        if (s['status'] == 'result_declared') declared++;
      }
      int publishedResults = 0;
      for (final r in results) {
        if (r['is_published'] == true) publishedResults++;
      }

      return {
        'totalSessions': sessions.length,
        'resultsDeclared': declared,
        'totalRegistrations': registrations.length,
        'hallTicketsIssued': tickets.length,
        'pendingRevaluations': pendingRevals.length,
        'totalResults': results.length,
        'publishedResults': publishedResults,
      };
    } catch (e) {
      print('Exam dashboard stats error: $e');
      return {
        'totalSessions': 0,
        'resultsDeclared': 0,
        'totalRegistrations': 0,
        'hallTicketsIssued': 0,
        'pendingRevaluations': 0,
        'totalResults': 0,
        'publishedResults': 0,
      };
    }
  }
}
