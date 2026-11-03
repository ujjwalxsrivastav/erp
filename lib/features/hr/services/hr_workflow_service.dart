import 'package:supabase_flutter/supabase_flutter.dart';

/// HR Workflow Service — Recruitment, Appraisal (PBAS/API) and
/// Exit & Full-and-Final workflows.
/// Tables: job_postings, job_applications, appraisal_forms,
///         employee_exits, exit_nodues
/// (see `run karwade/03_hr_recruitment_appraisal_exit.sql`)
class HrWorkflowService {
  final _supabase = Supabase.instance.client;

  /// Departments that must clear no-dues before an exit is completed.
  static const List<String> noDuesDepartments = [
    'library',
    'laboratory',
    'it',
    'hostel',
    'finance',
    'examination',
    'store',
  ];

  // ============================================================
  // RECRUITMENT — JOB POSTINGS
  // ============================================================
  Future<bool> createPosting(Map<String, dynamic> data) async {
    try {
      final status = data['status'] as String? ?? 'draft';
      if (status == 'published' && data['published_at'] == null) {
        data['published_at'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('job_postings').insert(data);
      return true;
    } catch (e) {
      print('Create posting error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPostings({String? status}) async {
    try {
      var query = _supabase.from('job_postings').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get postings error: $e');
      return [];
    }
  }

  Future<bool> updatePostingStatus(String postingId, String status) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'published') {
        update['published_at'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('job_postings').update(update).eq('id', postingId);
      return true;
    } catch (e) {
      print('Update posting status error: $e');
      return false;
    }
  }

  // ============================================================
  // RECRUITMENT — APPLICATIONS
  // ============================================================
  Future<bool> applyToPosting(Map<String, dynamic> data) async {
    try {
      await _supabase.from('job_applications').insert(data);
      return true;
    } catch (e) {
      print('Apply to posting error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getApplications({
    String? postingId,
    String? status,
  }) async {
    try {
      var query = _supabase.from('job_applications').select();
      if (postingId != null) query = query.eq('posting_id', postingId);
      if (status != null) query = query.eq('status', status);
      final r = await query.order('applied_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get applications error: $e');
      return [];
    }
  }

  Future<bool> updateApplicationStatus(
    String applicationId,
    String status, {
    DateTime? interviewDate,
    double? interviewMarks,
    String? remarks,
  }) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (interviewDate != null) {
        update['interview_date'] = interviewDate.toIso8601String();
      }
      if (interviewMarks != null) update['interview_marks'] = interviewMarks;
      if (remarks != null) update['remarks'] = remarks;
      await _supabase
          .from('job_applications')
          .update(update)
          .eq('id', applicationId);
      return true;
    } catch (e) {
      print('Update application status error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getRecruitmentStats() async {
    try {
      final postings = await _supabase.from('job_postings').select('status');
      final applications =
          await _supabase.from('job_applications').select('status');

      int openPostings = 0, totalVacancies = 0;
      final postingsFull = await _supabase
          .from('job_postings')
          .select('vacancies')
          .eq('status', 'published');
      for (var p in postingsFull) {
        totalVacancies += (p['vacancies'] as num?)?.toInt() ?? 0;
      }
      for (var p in postings) {
        if (p['status'] == 'published') openPostings++;
      }

      int shortlisted = 0, selected = 0, joined = 0;
      for (var a in applications) {
        if (a['status'] == 'shortlisted' ||
            a['status'] == 'interview_scheduled') {
          shortlisted++;
        }
        if (a['status'] == 'selected' || a['status'] == 'offered') selected++;
        if (a['status'] == 'joined') joined++;
      }

      return {
        'totalPostings': postings.length,
        'openPostings': openPostings,
        'totalVacancies': totalVacancies,
        'totalApplications': applications.length,
        'shortlisted': shortlisted,
        'selected': selected,
        'joined': joined,
      };
    } catch (e) {
      print('Recruitment stats error: $e');
      return {
        'totalPostings': 0,
        'openPostings': 0,
        'totalVacancies': 0,
        'totalApplications': 0,
        'shortlisted': 0,
        'selected': 0,
        'joined': 0,
      };
    }
  }

  // ============================================================
  // APPRAISAL (PBAS / API)
  // ============================================================
  Future<bool> submitAppraisal(Map<String, dynamic> data) async {
    try {
      data['status'] = data['status'] ?? 'submitted';
      data['submitted_at'] = DateTime.now().toIso8601String();
      await _supabase.from('appraisal_forms').insert(data);
      return true;
    } catch (e) {
      print('Submit appraisal error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAppraisals({
    String? year,
    String? status,
  }) async {
    try {
      var query = _supabase.from('appraisal_forms').select();
      if (year != null) query = query.eq('appraisal_year', year);
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get appraisals error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAppraisalsForEmployee(
      String employeeId) async {
    try {
      final r = await _supabase
          .from('appraisal_forms')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get employee appraisals error: $e');
      return [];
    }
  }

  /// Status flow: submitted -> hod_verified (with hodScore)
  /// -> committee_reviewed -> approved (with finalScore) / returned.
  Future<bool> updateAppraisalStatus(
    String appraisalId,
    String status, {
    double? hodScore,
    double? finalScore,
    String? remarks,
  }) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (hodScore != null) update['hod_score'] = hodScore;
      if (finalScore != null) update['final_api_score'] = finalScore;
      if (remarks != null) update['remarks'] = remarks;
      await _supabase
          .from('appraisal_forms')
          .update(update)
          .eq('id', appraisalId);
      return true;
    } catch (e) {
      print('Update appraisal status error: $e');
      return false;
    }
  }

  // ============================================================
  // EXIT & FULL-AND-FINAL
  // ============================================================
  /// Creates the exit case and seeds one pending no-dues row
  /// per clearance department.
  Future<String?> initiateExit(Map<String, dynamic> data) async {
    try {
      data['status'] = 'no_dues_pending';
      final res =
          await _supabase.from('employee_exits').insert(data).select().single();
      final exitId = res['id'] as String;
      final rows = noDuesDepartments
          .map((dept) => {'exit_id': exitId, 'department': dept})
          .toList();
      await _supabase.from('exit_nodues').insert(rows);
      return exitId;
    } catch (e) {
      print('Initiate exit error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getExits({String? status}) async {
    try {
      var query = _supabase.from('employee_exits').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get exits error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExitNoDues(String exitId) async {
    try {
      final r = await _supabase
          .from('exit_nodues')
          .select()
          .eq('exit_id', exitId)
          .order('department');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get exit no-dues error: $e');
      return [];
    }
  }

  Future<bool> updateExitClearance(
    String exitId,
    String department,
    String status, {
    double? dueAmount,
    String? remarks,
    String? updatedBy,
  }) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (dueAmount != null) update['due_amount'] = dueAmount;
      if (remarks != null) update['remarks'] = remarks;
      if (updatedBy != null) update['updated_by'] = updatedBy;
      await _supabase
          .from('exit_nodues')
          .update(update)
          .eq('exit_id', exitId)
          .eq('department', department);

      // If every department is clear, move the exit to FnF stage.
      final rows = await getExitNoDues(exitId);
      if (rows.isNotEmpty && rows.every((r) => r['status'] == 'clear')) {
        await _supabase.from('employee_exits').update({
          'status': 'fnf_pending',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', exitId);
      }
      return true;
    } catch (e) {
      print('Update exit clearance error: $e');
      return false;
    }
  }

  /// Records the Full & Final amount and marks the employee relieved.
  Future<bool> completeFnF(String exitId, double amount) async {
    try {
      await _supabase.from('employee_exits').update({
        'fnf_amount': amount,
        'status': 'relieved',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', exitId);
      return true;
    } catch (e) {
      print('Complete FnF error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getExitStats() async {
    try {
      final exits = await _supabase.from('employee_exits').select('status');
      int inProgress = 0, noDuesPending = 0, relieved = 0;
      for (var e in exits) {
        if (e['status'] == 'relieved' || e['status'] == 'completed') {
          relieved++;
        } else {
          inProgress++;
          if (e['status'] == 'no_dues_pending') noDuesPending++;
        }
      }
      return {
        'totalExits': exits.length,
        'inProgress': inProgress,
        'noDuesPending': noDuesPending,
        'relieved': relieved,
      };
    } catch (e) {
      print('Exit stats error: $e');
      return {
        'totalExits': 0,
        'inProgress': 0,
        'noDuesPending': 0,
        'relieved': 0,
      };
    }
  }

  // ============================================================
  // COMBINED DASHBOARD STATS
  // ============================================================
  Future<Map<String, dynamic>> getDashboardStats() async {
    final recruitment = await getRecruitmentStats();
    final exits = await getExitStats();

    int appraisalsPending = 0, appraisalsApproved = 0;
    try {
      final appraisals =
          await _supabase.from('appraisal_forms').select('status');
      for (var a in appraisals) {
        if (a['status'] == 'approved') {
          appraisalsApproved++;
        } else if (a['status'] != 'draft') {
          appraisalsPending++;
        }
      }
    } catch (e) {
      print('Appraisal stats error: $e');
    }

    return {
      ...recruitment,
      ...exits,
      'appraisalsPending': appraisalsPending,
      'appraisalsApproved': appraisalsApproved,
    };
  }
}
