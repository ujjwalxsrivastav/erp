import 'package:supabase_flutter/supabase_flutter.dart';

/// Admission Flow Service
///
/// End-to-end student admission pipeline:
///   enquiry (lead) -> admission application -> review
///   -> approved -> enrolled student (users + student_details)
///
/// Works alongside the existing [LeadService]: leads keep living in the
/// `leads` table, filled forms live in `admission_applications`
/// (see run karwade/07_student_admission.sql), and conversion mirrors
/// AdminService.addStudent exactly (secure_add_user_v2 RPC +
/// student_details insert).
class AdmissionFlowService {
  final _supabase = Supabase.instance.client;

  // ============================================================
  // 1. LEAD CAPTURE (enquiry — mirrors leaddemo.html)
  // ============================================================

  /// Create a lead from an enquiry (front-desk / counsellor entry).
  ///
  /// Inserts into `leads` with status 'new' and records a
  /// lead_status_history entry (best-effort: history failure never
  /// blocks the lead itself). Returns the created lead row, or null.
  Future<Map<String, dynamic>?> createLeadFromEnquiry({
    required String studentName,
    required String phone,
    String? email,
    String? city,
    String? state,
    String? qualification,
    double? percentage,
    int? passingYear,
    String? preferredCourse,
    String? preferredBatch,
    String? preferredSession,
    String source = 'walk-in',
    String? sourceDetail,
    String priority = 'normal',
    String? notes,
    String enteredBy = 'front_desk',
  }) async {
    try {
      final row = await _supabase
          .from('leads')
          .insert({
            'student_name': studentName,
            'phone': phone,
            'email': email,
            'city': city,
            'state': state,
            'qualification': qualification,
            'percentage': percentage,
            'passing_year': passingYear,
            'preferred_course': preferredCourse ?? 'Not Specified',
            'preferred_batch': preferredBatch,
            'preferred_session': preferredSession,
            'source': source,
            'source_detail': sourceDetail,
            'priority': priority,
            'notes': notes,
            'status': 'new',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final lead = Map<String, dynamic>.from(row);

      // Audit trail (lead_status_history.changed_by is NOT NULL,
      // so a value is always supplied). Skip gracefully on failure.
      try {
        await _supabase.from('lead_status_history').insert({
          'lead_id': lead['id'],
          'old_status': null,
          'new_status': 'new',
          'changed_by': enteredBy,
          'change_type': 'status_update',
          'notes': 'Lead created from enquiry form',
        });
      } catch (e) {
        print('AdmissionFlow: lead history entry skipped: $e');
      }

      return lead;
    } catch (e) {
      print('AdmissionFlow createLeadFromEnquiry error: $e');
      return null;
    }
  }

  /// Fetch a single lead row (used to prefill the admission form).
  Future<Map<String, dynamic>?> getLead(String leadId) async {
    try {
      final row =
          await _supabase.from('leads').select().eq('id', leadId).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      print('AdmissionFlow getLead error: $e');
      return null;
    }
  }

  // ============================================================
  // 2. ADMISSION APPLICATIONS
  // ============================================================

  /// Generate the next application number: ADM-<year>-<4-digit seq>.
  Future<String> _nextApplicationNo() async {
    final rows = await _supabase.from('admission_applications').select('id');
    final seq = (rows as List).length + 1;
    final year = DateTime.now().year;
    return 'ADM-$year-${seq.toString().padLeft(4, '0')}';
  }

  /// Submit a filled admission form.
  ///
  /// [data] carries the admission_applications columns (personal,
  /// family, academic, course, documents, extra_details). When
  /// [leadId] is given, the lead is linked (admission_form_id) and
  /// moved to 'form_filled', following LeadService conventions.
  ///
  /// Returns {success, applicationId, applicationNo, leadUpdated}
  /// or {success: false, error}.
  Future<Map<String, dynamic>> submitAdmissionApplication(
    Map<String, dynamic> data, {
    String? leadId,
  }) async {
    try {
      final applicationNo = await _nextApplicationNo();

      final inserted = await _supabase
          .from('admission_applications')
          .insert({
            ...data,
            'lead_id': leadId,
            'application_no': applicationNo,
            'status': 'submitted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final application = Map<String, dynamic>.from(inserted);
      var leadUpdated = false;

      if (leadId != null) {
        try {
          await _supabase.from('leads').update({
            'admission_form_id': application['id'],
            'status': 'form_filled',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', leadId);
          leadUpdated = true;

          try {
            await _supabase.from('lead_status_history').insert({
              'lead_id': leadId,
              'old_status': null,
              'new_status': 'form_filled',
              'changed_by': 'admission',
              'change_type': 'status_update',
              'notes': 'Admission application $applicationNo submitted',
            });
          } catch (e) {
            print('AdmissionFlow: lead history entry skipped: $e');
          }
        } catch (e) {
          print('AdmissionFlow: lead link update failed: $e');
        }
      }

      return {
        'success': true,
        'applicationId': application['id'],
        'applicationNo': applicationNo,
        'leadUpdated': leadUpdated,
      };
    } catch (e) {
      print('AdmissionFlow submitAdmissionApplication error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// List applications, newest first. Optional status filter and
  /// free-text search over name / phone / application number.
  Future<List<Map<String, dynamic>>> getApplications({
    String? status,
    String? search,
  }) async {
    try {
      var query = _supabase.from('admission_applications').select();
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (search != null && search.isNotEmpty) {
        query = query.or(
            'student_name.ilike.%$search%,phone.ilike.%$search%,application_no.ilike.%$search%');
      }
      final rows = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('AdmissionFlow getApplications error: $e');
      return [];
    }
  }

  /// Fetch one application by id.
  Future<Map<String, dynamic>?> getApplicationById(String id) async {
    try {
      final row = await _supabase
          .from('admission_applications')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      print('AdmissionFlow getApplicationById error: $e');
      return null;
    }
  }

  /// Move an application through the review workflow
  /// (under_review / documents_pending / approved / rejected ...).
  Future<bool> updateApplicationStatus(
    String id,
    String status, {
    String? reviewedBy,
    String? remarks,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (reviewedBy != null) updates['reviewed_by'] = reviewedBy;
      if (remarks != null) updates['review_remarks'] = remarks;
      await _supabase
          .from('admission_applications')
          .update(updates)
          .eq('id', id);
      return true;
    } catch (e) {
      print('AdmissionFlow updateApplicationStatus error: $e');
      return false;
    }
  }

  /// Replace the documents checklist of an application.
  Future<bool> updateDocuments(
    String id,
    Map<String, dynamic> documents,
  ) async {
    try {
      await _supabase.from('admission_applications').update({
        'documents': documents,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      print('AdmissionFlow updateDocuments error: $e');
      return false;
    }
  }

  // ============================================================
  // 3. CONVERSION — approved application -> enrolled student
  // ============================================================

  /// Convert an approved application into a real student account.
  ///
  /// Mirrors AdminService.addStudent exactly:
  ///  (a) users row via the `secure_add_user_v2` RPC (password is
  ///      hashed by the function), then a student_details row with
  ///      year/semester as strings. Year is derived from the
  ///      semester: year = ((semester + 1) / 2).ceil().
  ///  (b) the application is marked 'enrolled' with
  ///      enrolled_student_id = [username].
  ///  (c) the linked lead (if any) is marked converted.
  ///  (d) fee allocation is intentionally NOT created here:
  ///      FinanceService.allocateFeesToStudent needs a real fee
  ///      structure id, and there is no safe placeholder pattern —
  ///      the Finance module assigns the structure for the
  ///      department/semester after enrolment.
  ///
  /// Runs sequentially and reports the exact step that failed:
  /// {success, username, step, error?, feeAllocation, leadUpdated}.
  Future<Map<String, dynamic>> convertToStudent(
    String applicationId, {
    required String username,
    required String password,
    String? createdBy,
  }) async {
    final by = createdBy ?? 'admin';

    // ---- Load the application --------------------------------
    Map<String, dynamic>? app;
    try {
      app = await getApplicationById(applicationId);
    } catch (e) {
      return {
        'success': false,
        'step': 'load_application',
        'error': e.toString(),
      };
    }
    if (app == null) {
      return {
        'success': false,
        'step': 'load_application',
        'error': 'Application not found',
      };
    }

    final semester = (app['semester'] as num?)?.toInt() ?? 1;
    final year = ((semester + 1) / 2).ceil();

    // ---- (a1) Create the login (users row) --------------------
    try {
      final authResult = await _supabase.rpc('secure_add_user_v2', params: {
        'p_username': username,
        'p_password': password,
        'p_role': 'student',
        'p_created_by': by,
      });
      final result = Map<String, dynamic>.from(authResult as Map);
      if (result['success'] != true) {
        return {
          'success': false,
          'username': username,
          'step': 'create_user',
          'error': result['message']?.toString() ??
              'Failed to create user account',
        };
      }
    } catch (e) {
      print('AdmissionFlow convert create_user error: $e');
      return {
        'success': false,
        'username': username,
        'step': 'create_user',
        'error': e.toString(),
      };
    }

    // ---- (a2) student_details row -----------------------------
    try {
      await _supabase.from('student_details').insert({
        'student_id': username,
        'name': (app['student_name'] ?? '').toString(),
        'father_name': (app['father_name'] ?? '').toString(),
        'year': year.toString(),
        'semester': semester.toString(),
        'department': (app['department'] ?? '').toString(),
        'section': (app['section'] as String?)?.isNotEmpty == true
            ? app['section']
            : 'A',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('AdmissionFlow convert create_student_details error: $e');
      return {
        'success': false,
        'username': username,
        'step': 'create_student_details',
        'error':
            'Login account "$username" was created, but the student_details '
            'row failed: $e',
      };
    }

    // ---- (b) Mark the application enrolled --------------------
    try {
      await _supabase.from('admission_applications').update({
        'status': 'enrolled',
        'enrolled_student_id': username,
        'reviewed_by': by,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', applicationId);
    } catch (e) {
      print('AdmissionFlow convert mark_enrolled error: $e');
      return {
        'success': false,
        'username': username,
        'studentCreated': true,
        'step': 'mark_enrolled',
        'error':
            'Student "$username" was created, but marking the application '
            'as enrolled failed: $e',
      };
    }

    // ---- (c) Mark the linked lead converted -------------------
    var leadUpdated = false;
    final leadId = app['lead_id'] as String?;
    if (leadId != null) {
      try {
        await _supabase.from('leads').update({
          'is_converted': true,
          'converted_at': DateTime.now().toIso8601String(),
          'status': 'converted',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', leadId);
        leadUpdated = true;

        try {
          await _supabase.from('lead_status_history').insert({
            'lead_id': leadId,
            'old_status': null,
            'new_status': 'converted',
            'changed_by': by,
            'change_type': 'status_update',
            'notes': 'Converted to enrolled student $username',
          });
        } catch (e) {
          print('AdmissionFlow: lead history entry skipped: $e');
        }
      } catch (e) {
        print('AdmissionFlow convert update_lead error: $e');
      }
    }

    // ---- (d) Fee allocation: skipped by design (see doc) ------
    return {
      'success': true,
      'username': username,
      'step': 'completed',
      'feeAllocation': 'skipped',
      'leadUpdated': leadUpdated,
    };
  }

  // ============================================================
  // 4. STATS
  // ============================================================

  /// Admission dashboard numbers: lead volume, applications by
  /// status, pending reviews and total conversions.
  Future<Map<String, dynamic>> getAdmissionStats() async {
    var totalLeads = 0;
    var newLeadsToday = 0;
    var convertedCount = 0;
    try {
      final rows = await _supabase
          .from('leads')
          .select('created_at, is_converted');
      final list = rows as List;
      totalLeads = list.length;
      final now = DateTime.now();
      for (final r in list) {
        if (r['is_converted'] == true) convertedCount++;
        final created = DateTime.tryParse((r['created_at'] ?? '').toString());
        if (created != null &&
            created.year == now.year &&
            created.month == now.month &&
            created.day == now.day) {
          newLeadsToday++;
        }
      }
    } catch (e) {
      print('AdmissionFlow stats leads error: $e');
    }

    final byStatus = <String, int>{};
    var totalApplications = 0;
    try {
      final rows = await _supabase.from('admission_applications').select('status');
      final list = rows as List;
      totalApplications = list.length;
      for (final r in list) {
        final s = (r['status'] ?? 'draft').toString();
        byStatus[s] = (byStatus[s] ?? 0) + 1;
      }
    } catch (e) {
      print('AdmissionFlow stats applications error: $e');
    }

    final pendingReviews = (byStatus['submitted'] ?? 0) +
        (byStatus['under_review'] ?? 0) +
        (byStatus['documents_pending'] ?? 0);

    return {
      'totalLeads': totalLeads,
      'newLeadsToday': newLeadsToday,
      'convertedCount': convertedCount,
      'totalApplications': totalApplications,
      'applicationsByStatus': byStatus,
      'pendingReviews': pendingReviews,
      'approved': byStatus['approved'] ?? 0,
      'enrolled': byStatus['enrolled'] ?? 0,
    };
  }
}
