import 'package:supabase_flutter/supabase_flutter.dart';

/// Teacher Lifecycle Service — the full zero-to-hero hiring journey:
/// CV received -> interviews -> selection / rejection record -> offer ->
/// joining & onboarding -> department + subject mapping -> payroll
/// seeding -> HOD subject allotment.
///
/// Tables: job_postings, job_applications, interview_rounds,
///         recruitment_events, offer_letters, employee_onboarding,
///         teacher_subject_competency, subject_allotments,
///         users, teacher_details, teacher_salary
/// (see `run karwade/05_teacher_lifecycle.sql`)
class TeacherLifecycleService {
  final _supabase = Supabase.instance.client;

  /// Document checklist keys stored in employee_onboarding.documents.
  static const List<String> documentKeys = [
    'aadhaar',
    'pan',
    'degree',
    'experience_letter',
    'photo',
    'bank_passbook',
  ];

  static const Map<String, String> documentLabels = {
    'aadhaar': 'Aadhaar Card',
    'pan': 'PAN Card',
    'degree': 'Degree Certificate',
    'experience_letter': 'Experience Letter',
    'photo': 'Photograph',
    'bank_passbook': 'Bank Passbook',
  };

  static const List<String> roundTypes = [
    'screening',
    'demo_lecture',
    'panel',
    'hr',
    'final',
  ];

  static const List<String> recommendations = [
    'strong_yes',
    'yes',
    'no',
    'strong_no',
  ];

  /// Professional tax seeded at joining (flat monthly amount, same
  /// convention as the existing salary records).
  static const double defaultProfessionalTax = 200;

  // ============================================================
  // HELPERS
  // ============================================================
  String _today() => DateTime.now().toIso8601String();

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Writes one row into the management timeline. Never throws —
  /// a failed event log must not break the actual workflow.
  Future<void> _logEvent({
    String? applicationId,
    String? postingId,
    required String eventType,
    required String title,
    String? notes,
    String? createdBy,
  }) async {
    try {
      await _supabase.from('recruitment_events').insert({
        'application_id': applicationId,
        'posting_id': postingId,
        'event_type': eventType,
        'title': title,
        'notes': notes,
        'created_by': createdBy,
      });
    } catch (e) {
      print('Log recruitment event error: $e');
    }
  }

  Future<void> _updateApplication(
      String applicationId, Map<String, dynamic> fields) async {
    fields['updated_at'] = _today();
    await _supabase
        .from('job_applications')
        .update(fields)
        .eq('id', applicationId);
  }

  Future<Map<String, dynamic>?> _getApplication(String applicationId) async {
    try {
      final r = await _supabase
          .from('job_applications')
          .select()
          .eq('id', applicationId)
          .maybeSingle();
      return r == null ? null : Map<String, dynamic>.from(r);
    } catch (e) {
      print('Get application error: $e');
      return null;
    }
  }

  // ============================================================
  // POSTINGS + PIPELINE
  // ============================================================
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

  /// Applications of one posting, each enriched with:
  /// rounds_count, rounds_completed, offer (map|null), offer_status,
  /// latest_event (map|null).
  Future<List<Map<String, dynamic>>> getPipeline(String postingId) async {
    try {
      final r = await _supabase
          .from('job_applications')
          .select()
          .eq('posting_id', postingId)
          .order('applied_at', ascending: false);
      final apps = List<Map<String, dynamic>>.from(r);
      if (apps.isEmpty) return apps;

      final ids = apps.map((a) => a['id'].toString()).toList();

      // Interview rounds (counts per application)
      final roundsByApp = <String, List<Map<String, dynamic>>>{};
      try {
        final rounds = await _supabase
            .from('interview_rounds')
            .select('application_id, status')
            .inFilter('application_id', ids);
        for (var round in rounds) {
          final key = round['application_id'].toString();
          roundsByApp.putIfAbsent(key, () => []).add(
              Map<String, dynamic>.from(round as Map));
        }
      } catch (e) {
        print('Pipeline rounds error: $e');
      }

      // Offers
      final offerByApp = <String, Map<String, dynamic>>{};
      try {
        final offers = await _supabase
            .from('offer_letters')
            .select()
            .inFilter('application_id', ids);
        for (var offer in offers) {
          offerByApp[offer['application_id'].toString()] =
              Map<String, dynamic>.from(offer as Map);
        }
      } catch (e) {
        print('Pipeline offers error: $e');
      }

      // Latest event per application
      final latestEventByApp = <String, Map<String, dynamic>>{};
      try {
        final events = await _supabase
            .from('recruitment_events')
            .select()
            .inFilter('application_id', ids)
            .order('created_at', ascending: false);
        for (var event in events) {
          final key = event['application_id'].toString();
          latestEventByApp.putIfAbsent(
              key, () => Map<String, dynamic>.from(event as Map));
        }
      } catch (e) {
        print('Pipeline events error: $e');
      }

      for (var app in apps) {
        final id = app['id'].toString();
        final rounds = roundsByApp[id] ?? [];
        app['rounds_count'] = rounds.length;
        app['rounds_completed'] =
            rounds.where((x) => x['status'] == 'completed').length;
        app['offer'] = offerByApp[id];
        app['offer_status'] = offerByApp[id]?['status'];
        app['latest_event'] = latestEventByApp[id];
      }
      return apps;
    } catch (e) {
      print('Get pipeline error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getApplicationsForPosting(
      String postingId) async {
    try {
      final r = await _supabase
          .from('job_applications')
          .select()
          .eq('posting_id', postingId)
          .order('applied_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get applications error: $e');
      return [];
    }
  }

  /// Rejected candidates are a permanent record — stage + reason kept.
  Future<List<Map<String, dynamic>>> getRejectedPool(
      {String? postingId}) async {
    try {
      var query = _supabase
          .from('job_applications')
          .select()
          .eq('status', 'rejected');
      if (postingId != null) query = query.eq('posting_id', postingId);
      final r = await query.order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get rejected pool error: $e');
      return [];
    }
  }

  // ============================================================
  // TIMELINE EVENTS
  // ============================================================
  Future<List<Map<String, dynamic>>> getEvents({
    String? applicationId,
    int limit = 20,
  }) async {
    try {
      var query = _supabase.from('recruitment_events').select();
      if (applicationId != null) {
        query = query.eq('application_id', applicationId);
      }
      final r =
          await query.order('created_at', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get events error: $e');
      return [];
    }
  }

  // ============================================================
  // INTERVIEW ROUNDS
  // ============================================================
  Future<List<Map<String, dynamic>>> getRounds(String applicationId) async {
    try {
      final r = await _supabase
          .from('interview_rounds')
          .select()
          .eq('application_id', applicationId)
          .order('round_no');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get rounds error: $e');
      return [];
    }
  }

  /// Schedules the next interview round, moves the application to
  /// interview stage and writes the management timeline event.
  Future<Map<String, dynamic>?> scheduleInterview({
    required String applicationId,
    required String roundType,
    required DateTime scheduledAt,
    String? venue,
    List<String> panelMembers = const [],
    String? createdBy,
  }) async {
    try {
      final existing = await getRounds(applicationId);
      final roundNo = existing.length + 1;
      final app = await _getApplication(applicationId);

      final res = await _supabase
          .from('interview_rounds')
          .insert({
            'application_id': applicationId,
            'round_no': roundNo,
            'round_type': roundType,
            'scheduled_at': scheduledAt.toIso8601String(),
            'venue': venue,
            'panel_members': panelMembers,
            'status': 'scheduled',
            'created_by': createdBy,
          })
          .select()
          .single();

      await _updateApplication(applicationId, {
        'status': 'interview_scheduled',
        'current_stage': 'interview',
        'interview_date': scheduledAt.toIso8601String(),
      });

      await _logEvent(
        applicationId: applicationId,
        postingId: app?['posting_id']?.toString(),
        eventType: 'interview_scheduled',
        title:
            'Interview scheduled — Round $roundNo (${roundType.replaceAll('_', ' ')})',
        notes: venue == null ? null : 'Venue: $venue',
        createdBy: createdBy,
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('Schedule interview error: $e');
      return null;
    }
  }

  Future<bool> completeInterview(
    String roundId, {
    double? marks,
    String? feedback,
    String? recommendation,
    String? by,
  }) async {
    try {
      Map<String, dynamic>? round;
      try {
        final r = await _supabase
            .from('interview_rounds')
            .select()
            .eq('id', roundId)
            .maybeSingle();
        if (r != null) round = Map<String, dynamic>.from(r);
      } catch (e) {
        print('Fetch round error: $e');
      }

      await _supabase.from('interview_rounds').update({
        'status': 'completed',
        'marks': marks,
        'feedback': feedback,
        'recommendation': recommendation,
        'updated_at': _today(),
      }).eq('id', roundId);

      final applicationId = round?['application_id']?.toString();
      if (applicationId != null) {
        // Keep the legacy single-interview columns roughly in sync.
        if (marks != null) {
          try {
            await _updateApplication(applicationId, {
              'interview_marks': marks,
            });
          } catch (e) {
            print('Sync interview marks error: $e');
          }
        }
        final app = await _getApplication(applicationId);
        await _logEvent(
          applicationId: applicationId,
          postingId: app?['posting_id']?.toString(),
          eventType: 'interview_done',
          title:
              'Interview completed — Round ${round?['round_no'] ?? ''} (${(round?['round_type'] ?? '').toString().replaceAll('_', ' ')})',
          notes: [
            if (marks != null) 'Marks: $marks',
            if (recommendation != null)
              'Recommendation: ${recommendation.replaceAll('_', ' ')}',
            if (feedback != null && feedback.isNotEmpty) feedback,
          ].join(' • '),
          createdBy: by,
        );
      }
      return true;
    } catch (e) {
      print('Complete interview error: $e');
      return false;
    }
  }

  // ============================================================
  // PIPELINE DECISIONS — shortlist / select / reject
  // ============================================================
  Future<bool> shortlistApplication(String applicationId,
      {String? by}) async {
    try {
      await _updateApplication(applicationId, {
        'status': 'shortlisted',
        'current_stage': 'shortlisted',
      });
      final app = await _getApplication(applicationId);
      await _logEvent(
        applicationId: applicationId,
        postingId: app?['posting_id']?.toString(),
        eventType: 'shortlisted',
        title: 'Candidate shortlisted',
        createdBy: by,
      );
      return true;
    } catch (e) {
      print('Shortlist application error: $e');
      return false;
    }
  }

  Future<bool> selectApplication(String applicationId, {String? by}) async {
    try {
      await _updateApplication(applicationId, {
        'status': 'selected',
        'current_stage': 'selected',
      });
      final app = await _getApplication(applicationId);
      await _logEvent(
        applicationId: applicationId,
        postingId: app?['posting_id']?.toString(),
        eventType: 'selected',
        title: 'Candidate selected',
        createdBy: by,
      );
      return true;
    } catch (e) {
      print('Select application error: $e');
      return false;
    }
  }

  /// Rejection is a record, not a deletion: stage + reason are stored
  /// on the application so the candidate stays in the rejected pool.
  Future<bool> rejectApplication(
    String applicationId, {
    required String stage,
    required String reason,
    String? by,
  }) async {
    try {
      await _updateApplication(applicationId, {
        'status': 'rejected',
        'current_stage': 'rejected',
        'rejection_stage': stage,
        'rejection_reason': reason,
      });
      final app = await _getApplication(applicationId);
      await _logEvent(
        applicationId: applicationId,
        postingId: app?['posting_id']?.toString(),
        eventType: 'rejected',
        title: 'Candidate rejected at ${stage.replaceAll('_', ' ')} stage',
        notes: reason,
        createdBy: by,
      );
      return true;
    } catch (e) {
      print('Reject application error: $e');
      return false;
    }
  }

  // ============================================================
  // OFFER LETTERS
  // ============================================================
  Future<Map<String, dynamic>?> getOfferForApplication(
      String applicationId) async {
    try {
      final r = await _supabase
          .from('offer_letters')
          .select()
          .eq('application_id', applicationId)
          .maybeSingle();
      return r == null ? null : Map<String, dynamic>.from(r);
    } catch (e) {
      print('Get offer error: $e');
      return null;
    }
  }

  /// Issues the (single) offer for an application and moves the
  /// application to the offered stage.
  Future<Map<String, dynamic>?> issueOffer({
    required String applicationId,
    required String department,
    required String designation,
    required String employmentType,
    required double basic,
    required double hra,
    required double other,
    DateTime? joiningDate,
    String? remarks,
    String? by,
  }) async {
    try {
      final res = await _supabase
          .from('offer_letters')
          .insert({
            'application_id': applicationId,
            'department': department,
            'designation': designation,
            'employment_type': employmentType,
            'basic_salary': basic,
            'hra': hra,
            'other_allowances': other,
            'joining_date':
                joiningDate == null ? null : _dateOnly(joiningDate),
            'status': 'issued',
            'remarks': remarks,
          })
          .select()
          .single();

      await _updateApplication(applicationId, {
        'status': 'offered',
        'current_stage': 'offered',
      });

      final app = await _getApplication(applicationId);
      await _logEvent(
        applicationId: applicationId,
        postingId: app?['posting_id']?.toString(),
        eventType: 'offer_issued',
        title: 'Offer issued — $designation, $department',
        notes: 'Basic ₹${basic.toStringAsFixed(0)}/month'
            '${joiningDate == null ? '' : ' • Joining ${_dateOnly(joiningDate)}'}',
        createdBy: by,
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('Issue offer error: $e');
      return null;
    }
  }

  /// Offer status flow. On 'joined' the application is also marked
  /// joined and the timeline event is written.
  Future<bool> updateOfferStatus(
    String offerId,
    String status,
    String applicationId, {
    String? by,
  }) async {
    try {
      await _supabase.from('offer_letters').update({
        'status': status,
        'updated_at': _today(),
      }).eq('id', offerId);

      if (status == 'accepted' || status == 'joined') {
        final app = await _getApplication(applicationId);
        if (status == 'accepted') {
          await _logEvent(
            applicationId: applicationId,
            postingId: app?['posting_id']?.toString(),
            eventType: 'offer_accepted',
            title: 'Offer accepted by candidate',
            createdBy: by,
          );
        } else {
          await _updateApplication(applicationId, {
            'status': 'joined',
            'current_stage': 'joined',
          });
          await _logEvent(
            applicationId: applicationId,
            postingId: app?['posting_id']?.toString(),
            eventType: 'joined',
            title: 'Candidate joined the institute',
            createdBy: by,
          );
        }
      }
      return true;
    } catch (e) {
      print('Update offer status error: $e');
      return false;
    }
  }

  // ============================================================
  // ONBOARDING — username / employee id generation
  // ============================================================
  static const Set<String> _honorifics = {
    'dr',
    'mr',
    'mrs',
    'ms',
    'prof',
    'professor',
    'shri',
    'smt',
    'kumari',
  };

  String _nameToken(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '')
      .trim();

  /// Suggests firstname.lastname, appending 2, 3... on clashes with
  /// the users table or pending onboarding cases.
  Future<String> _suggestUsername(String fullName) async {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .map(_nameToken)
        .where((t) => t.isNotEmpty && !_honorifics.contains(t))
        .toList();
    String base;
    if (parts.isEmpty) {
      base = 'teacher';
    } else if (parts.length == 1) {
      base = parts.first;
    } else {
      base = '${parts.first}.${parts.last}';
    }

    var candidate = base;
    var suffix = 2;
    while (await _usernameTaken(candidate)) {
      candidate = '$base$suffix';
      suffix++;
    }
    return candidate;
  }

  Future<bool> _usernameTaken(String username) async {
    try {
      final u = await _supabase
          .from('users')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      if (u != null) return true;
      final o = await _supabase
          .from('employee_onboarding')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      return o != null;
    } catch (e) {
      print('Username check error: $e');
      return false;
    }
  }

  /// EMP<year><4-digit seq>, e.g. EMP2026001. Sequence starts from the
  /// onboarding count and is bumped until unique across onboarding
  /// and teacher_details.
  Future<String> _generateEmployeeId() async {
    final year = DateTime.now().year;
    var seq = 1;
    try {
      final res = await _supabase
          .from('employee_onboarding')
          .select('id')
          .count(CountOption.exact);
      seq = res.count + 1;
    } catch (e) {
      print('Employee id count error: $e');
    }
    while (true) {
      final candidate = 'EMP$year${seq.toString().padLeft(4, '0')}';
      var taken = false;
      try {
        final o = await _supabase
            .from('employee_onboarding')
            .select('employee_id')
            .eq('employee_id', candidate)
            .maybeSingle();
        if (o != null) taken = true;
        if (!taken) {
          final t = await _supabase
              .from('teacher_details')
              .select('employee_id')
              .eq('employee_id', candidate)
              .maybeSingle();
          if (t != null) taken = true;
        }
      } catch (e) {
        print('Employee id check error: $e');
      }
      if (!taken) return candidate;
      seq++;
    }
  }

  // ============================================================
  // ONBOARDING — case lifecycle
  // ============================================================
  /// Opens the onboarding case for an accepted offer: generates the
  /// employee id + login username and seeds an empty document
  /// checklist. Returns the onboarding row (existing row if a case
  /// was already opened for this application).
  Future<Map<String, dynamic>?> startOnboarding(
      Map<String, dynamic> offer) async {
    try {
      final applicationId = offer['application_id']?.toString();
      if (applicationId == null) return null;

      final existing = await _supabase
          .from('employee_onboarding')
          .select()
          .eq('application_id', applicationId)
          .maybeSingle();
      if (existing != null) return Map<String, dynamic>.from(existing);

      final app = await _getApplication(applicationId);
      final fullName = app?['applicant_name']?.toString() ?? 'New Teacher';
      final username = await _suggestUsername(fullName);
      final employeeId = await _generateEmployeeId();

      final res = await _supabase
          .from('employee_onboarding')
          .insert({
            'application_id': applicationId,
            'username': username,
            'employee_id': employeeId,
            'full_name': fullName,
            'department': offer['department'],
            'designation': offer['designation'],
            'joining_date': offer['joining_date'],
            'documents': {for (var k in documentKeys) k: false},
            'status': 'pending',
          })
          .select()
          .single();

      await _logEvent(
        applicationId: applicationId,
        postingId: app?['posting_id']?.toString(),
        eventType: 'note',
        title: 'Onboarding started — $employeeId ($username)',
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('Start onboarding error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getOnboardings({String? status}) async {
    try {
      var query = _supabase.from('employee_onboarding').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(r);
      await _enrichOnboardings(rows);
      return rows;
    } catch (e) {
      print('Get onboardings error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getOnboarding(String onboardingId) async {
    try {
      final r = await _supabase
          .from('employee_onboarding')
          .select()
          .eq('id', onboardingId)
          .maybeSingle();
      if (r == null) return null;
      final row = Map<String, dynamic>.from(r);
      await _enrichOnboardings([row]);
      return row;
    } catch (e) {
      print('Get onboarding error: $e');
      return null;
    }
  }

  /// Attaches 'application' and 'offer' maps to onboarding rows so
  /// screens can show contact details + the salary structure.
  Future<void> _enrichOnboardings(List<Map<String, dynamic>> rows) async {
    final appIds = rows
        .map((o) => o['application_id']?.toString())
        .whereType<String>()
        .toList();
    if (appIds.isEmpty) return;
    try {
      final apps = await _supabase
          .from('job_applications')
          .select()
          .inFilter('id', appIds);
      final appById = <String, Map<String, dynamic>>{
        for (var a in apps)
          a['id'].toString(): Map<String, dynamic>.from(a as Map),
      };
      final offers = await _supabase
          .from('offer_letters')
          .select()
          .inFilter('application_id', appIds);
      final offerByApp = <String, Map<String, dynamic>>{
        for (var o in offers)
          o['application_id'].toString(): Map<String, dynamic>.from(o as Map),
      };
      for (var row in rows) {
        final key = row['application_id']?.toString();
        row['application'] = key == null ? null : appById[key];
        row['offer'] = key == null ? null : offerByApp[key];
      }
    } catch (e) {
      print('Enrich onboardings error: $e');
    }
  }

  /// Saves the document checklist and moves the case between
  /// pending / documents_pending (completed is set only by
  /// completeOnboarding).
  Future<bool> updateOnboardingDocuments(
      String onboardingId, Map<String, dynamic> documents) async {
    try {
      final current = await _supabase
          .from('employee_onboarding')
          .select('status')
          .eq('id', onboardingId)
          .maybeSingle();
      final update = <String, dynamic>{
        'documents': documents,
        'updated_at': _today(),
      };
      if (current != null && current['status'] != 'completed') {
        final anyCollected = documents.values.any((v) => v == true);
        update['status'] = anyCollected ? 'documents_pending' : 'pending';
      }
      await _supabase
          .from('employee_onboarding')
          .update(update)
          .eq('id', onboardingId);
      return true;
    } catch (e) {
      print('Update onboarding documents error: $e');
      return false;
    }
  }

  /// Maps the offer-letter employment type vocabulary onto the
  /// teacher_details CHECK constraint values.
  String _mapEmploymentType(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'permanent':
        return 'Permanent';
      case 'contract':
        return 'Contract';
      case 'visiting':
        return 'Visiting';
      case 'adjunct':
      case 'guest':
        return 'Guest';
      default:
        return 'Permanent';
    }
  }

  bool _isDuplicateError(Object e) {
    final s = e.toString();
    return s.contains('23505') ||
        s.contains('duplicate key') ||
        s.contains('already exists');
  }

  /// THE JOINING TRANSACTION — creates the login account, the
  /// teacher profile and the payroll record from the onboarding
  /// case + offer, then closes the loop on offer / application /
  /// timeline. Steps run sequentially; every step's outcome is
  /// reported in the returned map so partial failures are visible
  /// and the case can be retried safely ('exists' steps are skipped
  /// on retry).
  ///
  /// Returns: {success, alreadyCompleted, username, employee_id,
  ///           steps: {...}, errors: [...]}
  Future<Map<String, dynamic>> completeOnboarding(String onboardingId) async {
    final result = <String, dynamic>{
      'success': false,
      'alreadyCompleted': false,
      'username': null,
      'employee_id': null,
      'steps': <String, String>{},
      'errors': <String>[],
    };
    final steps = result['steps'] as Map<String, String>;
    final errors = result['errors'] as List<String>;

    try {
      final obRes = await _supabase
          .from('employee_onboarding')
          .select()
          .eq('id', onboardingId)
          .maybeSingle();
      if (obRes == null) {
        errors.add('Onboarding case not found');
        return result;
      }
      final ob = Map<String, dynamic>.from(obRes);
      result['username'] = ob['username'];
      result['employee_id'] = ob['employee_id'];

      if (ob['status'] == 'completed') {
        result['success'] = true;
        result['alreadyCompleted'] = true;
        steps['onboarding'] = 'already_completed';
        return result;
      }

      final username = ob['username']?.toString() ?? '';
      final employeeId = ob['employee_id']?.toString() ?? '';
      if (username.isEmpty || employeeId.isEmpty) {
        errors.add('Username / employee id missing on the onboarding case');
        return result;
      }

      final applicationId = ob['application_id']?.toString();
      final app =
          applicationId == null ? null : await _getApplication(applicationId);
      final offer =
          applicationId == null ? null : await getOfferForApplication(applicationId);

      // ---- Step 1: login account (same secure RPC the Add Teacher
      // screen uses; default password = username, as on that screen)
      try {
        final authResult = await _supabase.rpc('secure_add_user_v2', params: {
          'p_username': username,
          'p_password': username,
          'p_role': 'teacher',
          'p_created_by': 'hr',
        });
        final auth = Map<String, dynamic>.from(authResult as Map);
        if (auth['success'] == true) {
          steps['user_account'] = 'created';
        } else if ((auth['message']?.toString() ?? '')
            .toLowerCase()
            .contains('exist')) {
          steps['user_account'] = 'exists';
        } else {
          steps['user_account'] = 'failed';
          errors.add(
              'User account: ${auth['message'] ?? 'secure_add_user_v2 rejected the request'}');
        }
      } catch (e) {
        steps['user_account'] = 'failed';
        errors.add('User account: $e');
      }

      // ---- Step 2: teacher profile (mirrors the Add Teacher insert,
      // extended with designation / joining / employment type)
      try {
        await _supabase.from('teacher_details').insert({
          'teacher_id': username,
          'employee_id': employeeId,
          'name': ob['full_name'],
          'designation': ob['designation'] ?? 'Assistant Professor',
          'department': ob['department'] ?? '',
          'date_of_joining': ob['joining_date'],
          'employment_type': _mapEmploymentType(
              offer?['employment_type']?.toString()),
          'status': 'Active',
          'phone': app?['phone'],
          'email': app?['email'],
          'highest_qualification': app?['qualification'],
          'created_at': _today(),
          'updated_at': _today(),
        });
        steps['teacher_details'] = 'created';
      } catch (e) {
        if (_isDuplicateError(e)) {
          steps['teacher_details'] = 'exists';
        } else {
          steps['teacher_details'] = 'failed';
          errors.add('Teacher profile: $e');
        }
      }

      // ---- Step 3: payroll seeding from the offer structure.
      // teacher_salary gross/net are GENERATED columns — never sent.
      if (offer == null) {
        steps['teacher_salary'] = 'skipped';
        errors.add('Offer letter not found — salary was not seeded');
      } else {
        try {
          final basic = (offer['basic_salary'] as num?)?.toDouble() ?? 0;
          final pf = (basic * 0.12 * 100).round() / 100;
          await _supabase.from('teacher_salary').insert({
            'employee_id': employeeId,
            'basic_salary': basic,
            'hra': (offer['hra'] as num?)?.toDouble() ?? 0,
            'travel_allowance': 0,
            'medical_allowance': 0,
            'special_allowance': 0,
            'other_allowances':
                (offer['other_allowances'] as num?)?.toDouble() ?? 0,
            'provident_fund': pf,
            'professional_tax': defaultProfessionalTax,
            'income_tax': 0,
            'other_deductions': 0,
            'effective_from': ob['joining_date'] ?? _dateOnly(DateTime.now()),
            'is_active': true,
            'created_by': 'hr',
          });
          steps['teacher_salary'] = 'created';
        } catch (e) {
          if (_isDuplicateError(e)) {
            steps['teacher_salary'] = 'exists';
          } else {
            steps['teacher_salary'] = 'failed';
            errors.add('Salary seeding: $e');
          }
        }
      }

      // Core identity must exist before the case is closed.
      final coreOk = steps['user_account'] != 'failed' &&
          steps['teacher_details'] != 'failed';
      if (!coreOk) {
        steps['onboarding'] = 'pending_retry';
        return result;
      }

      // ---- Step 4: close the loop — onboarding, offer, application,
      // management timeline.
      try {
        await _supabase.from('employee_onboarding').update({
          'status': 'completed',
          'updated_at': _today(),
        }).eq('id', onboardingId);
        steps['onboarding'] = 'completed';
      } catch (e) {
        steps['onboarding'] = 'failed';
        errors.add('Onboarding close: $e');
      }

      if (offer != null) {
        try {
          await _supabase.from('offer_letters').update({
            'status': 'joined',
            'updated_at': _today(),
          }).eq('id', offer['id']);
          steps['offer'] = 'joined';
        } catch (e) {
          steps['offer'] = 'failed';
          errors.add('Offer update: $e');
        }
      }

      if (applicationId != null) {
        try {
          await _updateApplication(applicationId, {
            'status': 'joined',
            'current_stage': 'joined',
          });
          steps['application'] = 'joined';
        } catch (e) {
          steps['application'] = 'failed';
          errors.add('Application update: $e');
        }
        await _logEvent(
          applicationId: applicationId,
          postingId: app?['posting_id']?.toString(),
          eventType: 'joined',
          title:
              'Joined — ${ob['full_name']} ($employeeId) • ${ob['department'] ?? ''}',
          notes: 'Login: $username • Payroll seeded from offer',
        );
      }

      result['success'] = steps['onboarding'] == 'completed';
      return result;
    } catch (e) {
      print('Complete onboarding error: $e');
      errors.add('Unexpected error: $e');
      return result;
    }
  }

  // ============================================================
  // SUBJECT COMPETENCY (what a teacher CAN teach)
  // ============================================================
  Future<bool> setCompetency(
      String teacherUsername, List<Map<String, dynamic>> subjects) async {
    try {
      if (subjects.isEmpty) return true;
      final rows = subjects
          .map((s) => {
                'teacher_username': teacherUsername,
                'subject_id': s['subject_id'],
                'subject_name': s['subject_name'],
                'proficiency': s['proficiency'] ?? 'primary',
              })
          .toList();
      await _supabase.from('teacher_subject_competency').upsert(rows,
          onConflict: 'teacher_username,subject_id');
      return true;
    } catch (e) {
      print('Set competency error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCompetency(
      String teacherUsername) async {
    try {
      final r = await _supabase
          .from('teacher_subject_competency')
          .select()
          .eq('teacher_username', teacherUsername)
          .order('subject_name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get competency error: $e');
      return [];
    }
  }

  Future<bool> removeCompetency(String teacherUsername, String subjectId) async {
    try {
      await _supabase
          .from('teacher_subject_competency')
          .delete()
          .eq('teacher_username', teacherUsername)
          .eq('subject_id', subjectId);
      return true;
    } catch (e) {
      print('Remove competency error: $e');
      return false;
    }
  }

  // ============================================================
  // HOD SUBJECT ALLOTMENT (what a teacher IS teaching)
  // ============================================================
  Future<List<String>> getDepartments() async {
    try {
      final r = await _supabase.from('teacher_details').select('department');
      final depts = <String>{};
      for (var row in r) {
        final d = row['department']?.toString();
        if (d != null && d.isNotEmpty) depts.add(d);
      }
      return depts.toList()..sort();
    } catch (e) {
      print('Get departments error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTeachersByDepartment(
      String department) async {
    try {
      final r = await _supabase
          .from('teacher_details')
          .select('teacher_id, name, designation, department, subject')
          .eq('department', department)
          .order('name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get teachers by department error: $e');
      return [];
    }
  }

  /// Subjects master list for allotment dropdowns.
  Future<List<Map<String, dynamic>>> getSubjectsMaster(
      {String? department}) async {
    try {
      var query = _supabase
          .from('subjects')
          .select('subject_id, subject_name, department');
      if (department != null) query = query.eq('department', department);
      final r = await query.order('subject_name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get subjects master error: $e');
      return [];
    }
  }

  Future<bool> allotSubject({
    required String teacherUsername,
    required String subjectId,
    String? subjectName,
    String? department,
    int? semester,
    String? section,
    String? academicYear,
    double weeklyHours = 4,
    String? allottedBy,
  }) async {
    try {
      await _supabase.from('subject_allotments').insert({
        'teacher_username': teacherUsername,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'department': department,
        'semester': semester,
        'section': section,
        'academic_year': academicYear,
        'weekly_hours': weeklyHours,
        'allotted_by': allottedBy,
        'status': 'active',
      });
      return true;
    } catch (e) {
      print('Allot subject error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllotments({
    String? department,
    int? semester,
    String? academicYear,
    String? teacherUsername,
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase.from('subject_allotments').select();
      if (department != null) query = query.eq('department', department);
      if (semester != null) query = query.eq('semester', semester);
      if (academicYear != null) {
        query = query.eq('academic_year', academicYear);
      }
      if (teacherUsername != null) {
        query = query.eq('teacher_username', teacherUsername);
      }
      if (activeOnly) query = query.eq('status', 'active');
      final r = await query.order('teacher_username').order('subject_name');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get allotments error: $e');
      return [];
    }
  }

  Future<bool> updateAllotmentStatus(String allotmentId, String status) async {
    try {
      await _supabase.from('subject_allotments').update({
        'status': status,
      }).eq('id', allotmentId);
      return true;
    } catch (e) {
      print('Update allotment status error: $e');
      return false;
    }
  }

  /// Per-teacher workload for a department: subjects allotted and
  /// total weekly hours (active allotments only).
  /// Returns rows: {teacher_username, teacher_name, subjects_count,
  ///                total_hours, allotments: [...]}
  Future<List<Map<String, dynamic>>> getTeacherWorkload(
    String department, {
    String? academicYear,
  }) async {
    try {
      final teachers = await getTeachersByDepartment(department);
      final nameByUsername = <String, String>{
        for (var t in teachers)
          t['teacher_id'].toString(): t['name']?.toString() ?? '',
      };
      final allotments = await getAllotments(
        department: department,
        academicYear: academicYear,
      );

      final byTeacher = <String, List<Map<String, dynamic>>>{};
      for (var a in allotments) {
        byTeacher
            .putIfAbsent(a['teacher_username'].toString(), () => [])
            .add(a);
      }

      final workload = <Map<String, dynamic>>[];
      // Teachers with allotments first-class, everyone else with zero.
      final usernames = <String>{
        ...nameByUsername.keys,
        ...byTeacher.keys,
      };
      for (var username in usernames) {
        final rows = byTeacher[username] ?? [];
        double hours = 0;
        for (var a in rows) {
          hours += (a['weekly_hours'] as num?)?.toDouble() ?? 0;
        }
        workload.add({
          'teacher_username': username,
          'teacher_name': nameByUsername[username] ?? username,
          'subjects_count': rows.length,
          'total_hours': hours,
          'allotments': rows,
        });
      }
      workload.sort((a, b) =>
          (b['total_hours'] as double).compareTo(a['total_hours'] as double));
      return workload;
    } catch (e) {
      print('Get teacher workload error: $e');
      return [];
    }
  }

  // ============================================================
  // HIGHER-MANAGEMENT STATS + UPDATE FEED
  // ============================================================
  Future<Map<String, dynamic>> getManagementStats() async {
    try {
      final postings = await _supabase
          .from('job_postings')
          .select('vacancies')
          .eq('status', 'published');
      int totalVacancies = 0;
      for (var p in postings) {
        totalVacancies += (p['vacancies'] as num?)?.toInt() ?? 0;
      }

      final applications = await _supabase
          .from('job_applications')
          .select('status, updated_at');
      final now = DateTime.now();
      int inInterview = 0, selected = 0, rejected = 0, joinedThisMonth = 0;
      for (var a in applications) {
        switch (a['status']) {
          case 'interview_scheduled':
            inInterview++;
            break;
          case 'selected':
            selected++;
            break;
          case 'rejected':
            rejected++;
            break;
          case 'joined':
            final updated = DateTime.tryParse(a['updated_at']?.toString() ?? '');
            if (updated != null &&
                updated.year == now.year &&
                updated.month == now.month) {
              joinedThisMonth++;
            }
            break;
        }
      }

      int offersPending = 0;
      try {
        final offers = await _supabase
            .from('offer_letters')
            .select('id')
            .eq('status', 'issued');
        offersPending = (offers as List).length;
      } catch (e) {
        print('Offers pending count error: $e');
      }

      // Recent management feed, with applicant names attached.
      final recentEvents = await getEvents(limit: 10);
      final appIds = recentEvents
          .map((e) => e['application_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      if (appIds.isNotEmpty) {
        try {
          final apps = await _supabase
              .from('job_applications')
              .select('id, applicant_name')
              .inFilter('id', appIds);
          final nameById = <String, String>{
            for (var a in apps)
              a['id'].toString(): a['applicant_name']?.toString() ?? '',
          };
          for (var e in recentEvents) {
            e['applicant_name'] = nameById[e['application_id']?.toString()];
          }
        } catch (e) {
          print('Enrich recent events error: $e');
        }
      }

      return {
        'totalVacancies': totalVacancies,
        'totalApplications': applications.length,
        'inInterview': inInterview,
        'selected': selected,
        'rejected': rejected,
        'offersPending': offersPending,
        'joinedThisMonth': joinedThisMonth,
        'recentEvents': recentEvents,
      };
    } catch (e) {
      print('Management stats error: $e');
      return {
        'totalVacancies': 0,
        'totalApplications': 0,
        'inInterview': 0,
        'selected': 0,
        'rejected': 0,
        'offersPending': 0,
        'joinedThisMonth': 0,
        'recentEvents': <Map<String, dynamic>>[],
      };
    }
  }
}
