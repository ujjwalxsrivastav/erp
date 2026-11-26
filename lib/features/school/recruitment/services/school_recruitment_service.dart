import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/auth_service.dart';

/// A document selected by an applicant and uploaded with the application.
class ApplicantUpload {
  final String type;
  final String label;
  final String fileName;
  final List<int> bytes;

  const ApplicantUpload({
    required this.type,
    required this.label,
    required this.fileName,
    required this.bytes,
  });
}

/// School-only teacher recruitment.
///
/// Uses the dedicated `school_*` tables created by
/// `sql_migrations/29_school_teacher_recruitment.sql`. The college
/// `job_postings` / `job_applications` tables are not touched.
class SchoolRecruitmentService {
  final _supabase = Supabase.instance.client;

  /// Only administrators can build, publish or review vacancies.
  /// School-side role aliases normalise to `admin`.
  static const Set<String> adminRoles = {'admin'};

  static String normalizeRole(String? role) {
    final raw = (role ?? '').toLowerCase().trim();
    if (raw == 'sadmin' || raw == 'principal' || raw == 'superadmin') {
      return 'admin';
    }
    return raw;
  }

  static bool isAdminRole(String? role) =>
      adminRoles.contains(normalizeRole(role));

  static const List<Map<String, String>> questionTypes = [
    {'value': 'short_answer', 'label': 'Short answer'},
    {'value': 'paragraph', 'label': 'Paragraph'},
    {'value': 'number', 'label': 'Number'},
    {'value': 'date', 'label': 'Date'},
    {'value': 'multiple_choice', 'label': 'Multiple choice'},
    {'value': 'checkboxes', 'label': 'Checkboxes'},
    {'value': 'dropdown', 'label': 'Dropdown'},
    {'value': 'yes_no', 'label': 'Yes / No'},
    {'value': 'file_upload', 'label': 'File upload'},
  ];

  static const List<Map<String, dynamic>> defaultRequiredDocuments = [
    {'key': 'resume', 'label': 'Resume / CV', 'required': true},
    {'key': 'degree', 'label': 'Degree certificate', 'required': true},
    {'key': 'id_proof', 'label': 'Government ID proof', 'required': true},
    {
      'key': 'experience_letter',
      'label': 'Experience letter',
      'required': false,
    },
    {'key': 'photo', 'label': 'Passport-size photo', 'required': false},
    {'key': 'bank_passbook', 'label': 'Bank passbook', 'required': false},
  ];

  static String questionTypeLabel(String? type) {
    for (final t in questionTypes) {
      if (t['value'] == type) return t['label'] ?? type ?? '';
    }
    return (type ?? 'short_answer').replaceAll('_', ' ');
  }

  Future<String?> currentUsername() => AuthService().getCurrentUsername();

  // ============================================================
  // BASE QUESTION TEMPLATES
  // ============================================================
  Future<List<Map<String, dynamic>>> getQuestionTemplates({
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase.from('school_vacancy_question_templates').select();
      if (activeOnly) query = query.eq('is_active', true);
      final rows = await query
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Get vacancy question templates error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveQuestionTemplate({
    String? id,
    required String questionText,
    required String questionType,
    List<String> options = const [],
    bool isRequired = true,
    String? helpText,
    int sortOrder = 0,
    String? templateKey,
  }) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) {
      return {'success': false, 'message': 'Only administrators can edit the base questions.'};
    }
    if (questionText.trim().isEmpty) {
      return {'success': false, 'message': 'Question text is required.'};
    }

    final payload = <String, dynamic>{
      'question_text': questionText.trim(),
      'question_type': questionType,
      'options': options,
      'is_required': isRequired,
      'help_text': helpText?.trim().isEmpty == true ? null : helpText?.trim(),
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (templateKey != null && templateKey.trim().isNotEmpty) {
      payload['template_key'] = templateKey.trim();
    }

    try {
      if (id == null || id.isEmpty) {
        payload['created_by'] = await currentUsername();
        final row = await _supabase
            .from('school_vacancy_question_templates')
            .insert(payload)
            .select()
            .single();
        return {'success': true, 'data': row};
      }
      final row = await _supabase
          .from('school_vacancy_question_templates')
          .update(payload)
          .eq('id', id)
          .select()
          .maybeSingle();
      return {'success': true, 'data': row};
    } catch (e) {
      print('Save question template error: $e');
      return {'success': false, 'message': 'Could not save the question.'};
    }
  }

  Future<bool> setQuestionTemplateActive(String id, bool active) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      await _supabase
          .from('school_vacancy_question_templates')
          .update({
            'is_active': active,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      return true;
    } catch (e) {
      print('Toggle question template error: $e');
      return false;
    }
  }

  Future<bool> deleteQuestionTemplate(String id) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      await _supabase
          .from('school_vacancy_question_templates')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      print('Delete question template error: $e');
      return false;
    }
  }

  // ============================================================
  // VACANCIES
  // ============================================================
  Future<List<Map<String, dynamic>>> getVacancies({
    String? status,
    bool withApplicants = true,
  }) async {
    try {
      final select = withApplicants
          ? '*, school_vacancy_applications(id, status, document_status, interview_status)'
          : '*';
      var query = _supabase.from('school_vacancies').select(select);
      if (status != null) query = query.eq('status', status);
      final rows =
          await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows).map((row) {
        final apps = row['school_vacancy_applications'];
        final list = apps is List ? apps : const [];
        final map = Map<String, dynamic>.from(row);
        map['applicant_count'] = list.length;
        map['interview_count'] = list
            .where((a) =>
                a is Map &&
                (a['status'] == 'interview_scheduled' ||
                    a['status'] == 'interview_completed'))
            .length;
        map['verified_count'] = list
            .where((a) => a is Map && a['document_status'] == 'verified')
            .length;
        return map;
      }).toList();
    } catch (e) {
      print('Get school vacancies error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getVacancy(String id) async {
    try {
      final row = await _supabase
          .from('school_vacancies')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      print('Get school vacancy error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> saveVacancy({
    String? id,
    required String title,
    String? department,
    String postType = 'permanent',
    int vacancies = 1,
    String? eligibility,
    String? description,
    DateTime? closingDate,
    String status = 'draft',
    required List<Map<String, dynamic>> formSchema,
    required List<Map<String, dynamic>> requiredDocuments,
  }) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) {
      return {'success': false, 'message': 'Only administrators can create teacher vacancies.'};
    }
    if (title.trim().isEmpty) {
      return {'success': false, 'message': 'Vacancy title is required.'};
    }

    final payload = <String, dynamic>{
      'title': title.trim(),
      'department': department?.trim().isEmpty == true ? null : department?.trim(),
      'post_type': postType,
      'vacancies': vacancies,
      'eligibility': eligibility?.trim().isEmpty == true ? null : eligibility?.trim(),
      'description': description?.trim().isEmpty == true ? null : description?.trim(),
      'closing_date': closingDate?.toIso8601String().split('T').first,
      'status': status,
      'form_schema': formSchema,
      'required_documents': requiredDocuments,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == 'published') {
      payload['published_at'] = DateTime.now().toIso8601String();
    }

    try {
      if (id == null || id.isEmpty) {
        payload['created_by'] = await currentUsername();
        final row = await _supabase
            .from('school_vacancies')
            .insert(payload)
            .select()
            .single();
        return {'success': true, 'data': row};
      }
      final row = await _supabase
          .from('school_vacancies')
          .update(payload)
          .eq('id', id)
          .select()
          .maybeSingle();
      return {'success': true, 'data': row};
    } catch (e) {
      print('Save school vacancy error: $e');
      return {'success': false, 'message': 'Could not save the vacancy.'};
    }
  }

  Future<bool> setVacancyStatus(String id, String status) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'published') {
        update['published_at'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('school_vacancies').update(update).eq('id', id);
      return true;
    } catch (e) {
      print('Set vacancy status error: $e');
      return false;
    }
  }

  Future<bool> deleteVacancy(String id) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      await _supabase.from('school_vacancies').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Delete school vacancy error: $e');
      return false;
    }
  }

  /// Shareable Google-Forms-style link. Works with Flutter's hash routing and
  /// with the `/erp/` GitHub Pages base path.
  String shareLinkFor(String vacancyId) {
    final base = Uri.base;
    final path = base.path;
    final dir = path.endsWith('/')
        ? path
        : path.substring(0, max(path.lastIndexOf('/') + 1, 0));
    return '${base.origin}$dir#/apply/vacancy?id=$vacancyId';
  }

  // ============================================================
  // APPLICATIONS
  // ============================================================
  Future<Map<String, dynamic>> submitApplication({
    required String vacancyId,
    required String applicantName,
    String? applicantUsername,
    String? email,
    String? phone,
    String? qualification,
    double experienceYears = 0,
    required Map<String, dynamic> answers,
    List<ApplicantUpload> documents = const [],
  }) async {
    if (applicantName.trim().isEmpty) {
      return {'success': false, 'message': 'Your name is required.'};
    }

    final username =
        applicantUsername ?? (await currentUsername());
    final token = (username == null || username.isEmpty)
        ? '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}'
        : null;

    try {
      final row = await _supabase
          .from('school_vacancy_applications')
          .insert({
            'vacancy_id': vacancyId,
            'applicant_username': username,
            'applicant_token': token,
            'applicant_name': applicantName.trim(),
            'email': email?.trim().isEmpty == true ? null : email?.trim(),
            'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
            'qualification':
                qualification?.trim().isEmpty == true ? null : qualification?.trim(),
            'experience_years': experienceYears,
            'answers': answers,
            'status': documents.isEmpty ? 'applied' : 'documents_pending',
            'document_status': 'pending',
            'interview_status': 'not_scheduled',
          })
          .select()
          .single();

      final applicationId = row['id'].toString();

      for (final doc in documents) {
        final url = await uploadApplicantDocument(
          vacancyId: vacancyId,
          applicationId: applicationId,
          documentType: doc.type,
          fileName: doc.fileName,
          bytes: doc.bytes,
        );
        if (url == null) continue;
        await _supabase.from('school_vacancy_documents').insert({
          'application_id': applicationId,
          'document_type': doc.type,
          'document_label': doc.label,
          'file_name': doc.fileName,
          'file_url': url,
          'status': 'pending',
        });
      }

      return {
        'success': true,
        'message': 'Application submitted successfully.',
        'data': row,
        'reference': applicationId,
      };
    } catch (e) {
      print('Submit school vacancy application error: $e');
      return {
        'success': false,
        'message':
            'Could not submit the application. ${e.toString().contains('duplicate') ? 'You have already applied for this vacancy.' : 'Please try again.'}',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getApplications({
    String? vacancyId,
    String? status,
    String? applicantUsername,
  }) async {
    try {
      var query = _supabase.from('school_vacancy_applications').select(
            '*, school_vacancies(id, title, department), '
            'school_vacancy_documents(id, document_type, status), '
            'school_vacancy_interviews(id, scheduled_at, status)',
          );
      if (vacancyId != null) query = query.eq('vacancy_id', vacancyId);
      if (status != null) query = query.eq('status', status);
      if (applicantUsername != null) {
        query = query.eq('applicant_username', applicantUsername);
      }
      final rows =
          await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Get school vacancy applications error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getApplication(String id) async {
    try {
      final row = await _supabase
          .from('school_vacancy_applications')
          .select(
            '*, school_vacancies(*), '
            'school_vacancy_documents(*), '
            'school_vacancy_interviews(*)',
          )
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      print('Get school vacancy application error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMyApplications(String username) =>
      getApplications(applicantUsername: username);

  // ============================================================
  // DOCUMENTS
  // ============================================================
  Future<String?> uploadApplicantDocument({
    required String vacancyId,
    required String applicationId,
    required String documentType,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '$vacancyId/$applicationId/${documentType}_${stamp}_$safeName';
      final contentType = _contentTypeFor(fileName);
      await _supabase.storage.from('school-vacancy-documents').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType),
          );
      return _supabase.storage
          .from('school-vacancy-documents')
          .getPublicUrl(path);
    } catch (e) {
      print('Upload applicant document error: $e');
      return null;
    }
  }

  static String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<List<Map<String, dynamic>>> getDocuments(String applicationId) async {
    try {
      final rows = await _supabase
          .from('school_vacancy_documents')
          .select()
          .eq('application_id', applicationId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Get applicant documents error: $e');
      return [];
    }
  }

  Future<bool> reviewDocument({
    required String documentId,
    required bool approve,
    String? remarks,
  }) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      final by = await currentUsername();
      await _supabase.from('school_vacancy_documents').update({
        'status': approve ? 'verified' : 'rejected',
        'remarks': remarks?.trim().isEmpty == true ? null : remarks?.trim(),
        'verified_by': by,
        'verified_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', documentId);
      return true;
    } catch (e) {
      print('Review applicant document error: $e');
      return false;
    }
  }

  /// Recomputes whether all required documents are verified, and advances or
  /// holds the application at the document-verification stage.
  Future<Map<String, dynamic>> refreshDocumentStatus(
    String applicationId,
  ) async {
    try {
      final app = await getApplication(applicationId);
      if (app == null) {
        return {'success': false, 'message': 'Application not found.'};
      }
      final vacancy = app['school_vacancies'];
      final requiredRaw = vacancy is Map ? vacancy['required_documents'] : null;
      final requiredDocs = requiredRaw is List
          ? requiredRaw.whereType<Map>().toList()
          : <Map>[];
      final requiredKeys = requiredDocs
          .where((d) => d['required'] != false)
          .map((d) => d['key'].toString())
          .toSet();

      final docs = await getDocuments(applicationId);
      final verifiedKeys = docs
          .where((d) => d['status'] == 'verified')
          .map((d) => d['document_type'].toString())
          .toSet();
      final rejected = docs.any((d) => d['status'] == 'rejected');

      String documentStatus;
      String? nextStatus;
      if (rejected) {
        documentStatus = 'rejected';
        nextStatus = 'documents_pending';
      } else if (requiredKeys.isNotEmpty &&
          requiredKeys.every(verifiedKeys.contains)) {
        documentStatus = 'verified';
        nextStatus = 'documents_verified';
      } else if (requiredKeys.isEmpty && docs.isNotEmpty &&
          docs.every((d) => d['status'] == 'verified')) {
        documentStatus = 'verified';
        nextStatus = 'documents_verified';
      } else {
        documentStatus = 'pending';
        nextStatus = docs.isEmpty ? 'applied' : 'documents_pending';
      }

      final currentStatus = app['status']?.toString();
      const editable = {
        'applied',
        'documents_pending',
        'documents_verified',
      };
      if (editable.contains(currentStatus)) {
        await _supabase.from('school_vacancy_applications').update({
          'document_status': documentStatus,
          'status': nextStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', applicationId);
      }

      return {
        'success': true,
        'document_status': documentStatus,
        'status': nextStatus,
        'required': requiredKeys.length,
        'verified': verifiedKeys.length,
      };
    } catch (e) {
      print('Refresh document status error: $e');
      return {'success': false, 'message': 'Could not refresh document status.'};
    }
  }

  // ============================================================
  // INTERVIEWS
  // ============================================================
  Future<Map<String, dynamic>> scheduleInterview({
    required String applicationId,
    required DateTime scheduledAt,
    String mode = 'in_person',
    String? venue,
    String? meetingLink,
    List<String> panelMembers = const [],
  }) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) {
      return {'success': false, 'message': 'Only administrators can schedule interviews.'};
    }

    final app = await getApplication(applicationId);
    if (app == null) {
      return {'success': false, 'message': 'Application not found.'};
    }
    if (app['document_status'] != 'verified') {
      return {
        'success': false,
        'message': 'Verify the applicant documents before scheduling an interview.',
      };
    }

    try {
      final row = await _supabase
          .from('school_vacancy_interviews')
          .insert({
            'application_id': applicationId,
            'scheduled_at': scheduledAt.toIso8601String(),
            'mode': mode,
            'venue': venue?.trim().isEmpty == true ? null : venue?.trim(),
            'meeting_link':
                meetingLink?.trim().isEmpty == true ? null : meetingLink?.trim(),
            'panel_members': panelMembers,
            'status': 'scheduled',
            'created_by': await currentUsername(),
          })
          .select()
          .single();

      await _supabase.from('school_vacancy_applications').update({
        'status': 'interview_scheduled',
        'interview_status': 'scheduled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', applicationId);

      return {'success': true, 'data': row, 'message': 'Interview scheduled.'};
    } catch (e) {
      print('Schedule school interview error: $e');
      return {'success': false, 'message': 'Could not schedule the interview.'};
    }
  }

  Future<List<Map<String, dynamic>>> getInterviews({String? status}) async {
    try {
      var query = _supabase.from('school_vacancy_interviews').select(
            '*, school_vacancy_applications(*, '
            'school_vacancies(id, title, department))',
          );
      if (status != null) query = query.eq('status', status);
      final rows = await query.order('scheduled_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Get school interviews error: $e');
      return [];
    }
  }

  Future<bool> completeInterview(
    String interviewId, {
    double? marks,
    String? feedback,
    String? recommendation,
  }) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      final interview = await _supabase
          .from('school_vacancy_interviews')
          .select()
          .eq('id', interviewId)
          .maybeSingle();
      if (interview == null) return false;

      await _supabase.from('school_vacancy_interviews').update({
        'status': 'completed',
        'marks': marks,
        'feedback': feedback?.trim().isEmpty == true ? null : feedback?.trim(),
        'recommendation': recommendation,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', interviewId);

      final applicationId = interview['application_id']?.toString();
      if (applicationId != null) {
        await _supabase.from('school_vacancy_applications').update({
          'status': 'interview_completed',
          'interview_status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', applicationId);
      }
      return true;
    } catch (e) {
      print('Complete school interview error: $e');
      return false;
    }
  }

  Future<bool> cancelInterview(String interviewId, {String? reason}) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      final interview = await _supabase
          .from('school_vacancy_interviews')
          .select()
          .eq('id', interviewId)
          .maybeSingle();
      if (interview == null) return false;

      await _supabase.from('school_vacancy_interviews').update({
        'status': 'cancelled',
        'feedback': reason?.trim().isEmpty == true ? null : reason?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', interviewId);

      final applicationId = interview['application_id']?.toString();
      if (applicationId != null) {
        await _supabase.from('school_vacancy_applications').update({
          'status': 'documents_verified',
          'interview_status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', applicationId);
      }
      return true;
    } catch (e) {
      print('Cancel school interview error: $e');
      return false;
    }
  }

  // ============================================================
  // PIPELINE DECISIONS
  // ============================================================
  Future<bool> selectApplication(String applicationId) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      await _supabase.from('school_vacancy_applications').update({
        'status': 'selected',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', applicationId);
      return true;
    } catch (e) {
      print('Select school applicant error: $e');
      return false;
    }
  }

  Future<bool> rejectApplication(String applicationId, String reason) async {
    final role = await AuthService().getLiveUserRole();
    if (!isAdminRole(role)) return false;
    try {
      await _supabase.from('school_vacancy_applications').update({
        'status': 'rejected',
        'rejection_reason':
            reason.trim().isEmpty ? null : reason.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', applicationId);
      return true;
    } catch (e) {
      print('Reject school applicant error: $e');
      return false;
    }
  }
}
