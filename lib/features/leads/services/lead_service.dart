import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/lead_model.dart';
import '../data/lead_status.dart';

/// Lead Service - Handles all lead-related operations
class LeadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // LEAD CRUD OPERATIONS
  // ============================================================================

  /// Create a new lead (used by public form)
  Future<Lead?> createLead({
    required String studentName,
    required String phone,
    String? email,
    String? city,
    String? state,
    String? preferredCourse,
    String? preferredBatch,
    String source = 'website',
    String? sourceDetail,
  }) async {
    try {
      final response = await _supabase.rpc('public_create_lead', params: {
        'p_student_name': studentName,
        'p_phone': phone,
        'p_email': email,
        'p_city': city,
        'p_state': state,
        'p_preferred_course': preferredCourse ?? 'Not Specified',
        'p_preferred_batch': preferredBatch,
        'p_source': source,
        'p_source_detail': sourceDetail,
      });

      if (response != null) {
        // Fetch the created lead
        return await getLeadById(response as String);
      }
      return null;
    } catch (e) {
      print('Error creating lead: $e');
      return null;
    }
  }

  /// Create lead with full details (used by internal forms)
  Future<Lead?> createLeadFull(Map<String, dynamic> leadData) async {
    try {
      final response =
          await _supabase.from('leads').insert(leadData).select().single();

      return Lead.fromJson(response);
    } catch (e) {
      print('Error creating lead: $e');
      return null;
    }
  }

  /// Get lead by ID
  Future<Lead?> getLeadById(String id) async {
    try {
      final response =
          await _supabase.from('leads').select().eq('id', id).single();

      return Lead.fromJson(response);
    } catch (e) {
      print('Error fetching lead: $e');
      return null;
    }
  }

  /// Get all leads with optional filters
  Future<List<Lead>> getLeads({
    LeadStatus? status,
    String? counsellorId,
    LeadPriority? priority,
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _supabase.from('leads').select();

      // Apply filters
      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (counsellorId != null) {
        query = query.eq('assigned_counsellor_id', counsellorId);
      }
      if (priority != null) {
        query = query.eq('priority', priority.value);
      }
      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('created_at', toDate.toIso8601String());
      }
      if (search != null && search.isNotEmpty) {
        query = query.or(
            'student_name.ilike.%$search%,phone.ilike.%$search%,email.ilike.%$search%');
      }

      // Apply ordering and pagination
      final response = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) => Lead.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching leads: $e');
      return [];
    }
  }

  /// Get unassigned leads (for Dean)
  Future<List<Lead>> getUnassignedLeads() async {
    try {
      final response = await _supabase
          .from('leads')
          .select()
          .eq('status', 'new')
          .isFilter('assigned_counsellor_id', null)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Lead.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching unassigned leads: $e');
      return [];
    }
  }

  /// Get leads assigned to a specific counsellor
  Future<List<Lead>> getCounsellorLeads(
    String counsellorId, {
    LeadStatus? status,
    bool activeOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('leads')
          .select()
          .eq('assigned_counsellor_id', counsellorId);

      if (status != null) {
        query = query.eq('status', status.value);
      }
      if (activeOnly) {
        query = query.inFilter('status', [
          'assigned',
          'contacted',
          'interested',
          'followup',
          'form_sent',
          'form_filled',
          'seat_booked'
        ]);
      }

      final response = await query.order('updated_at', ascending: false);

      return (response as List).map((json) => Lead.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching counsellor leads: $e');
      return [];
    }
  }

  /// Get leads with follow-up due today
  Future<List<Lead>> getTodaysFollowups(String? counsellorId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      var query = _supabase
          .from('leads')
          .select()
          .gte('next_followup_date', startOfDay.toIso8601String())
          .lt('next_followup_date', endOfDay.toIso8601String());

      if (counsellorId != null) {
        query = query.eq('assigned_counsellor_id', counsellorId);
      }

      final response = await query.order('next_followup_date', ascending: true);

      return (response as List).map((json) => Lead.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching today\'s followups: $e');
      return [];
    }
  }

  /// Get overdue leads (missed follow-up)
  Future<List<Lead>> getOverdueLeads(String? counsellorId) async {
    try {
      final now = DateTime.now();

      var query = _supabase
          .from('leads')
          .select()
          .lt('next_followup_date', now.toIso8601String())
          .inFilter(
              'status', ['assigned', 'contacted', 'interested', 'followup']);

      if (counsellorId != null) {
        query = query.eq('assigned_counsellor_id', counsellorId);
      }

      final response = await query.order('next_followup_date', ascending: true);

      return (response as List).map((json) => Lead.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching overdue leads: $e');
      return [];
    }
  }

  // ============================================================================
  // LEAD ASSIGNMENT
  // ============================================================================

  /// Assign lead to a counsellor
  Future<bool> assignLead({
    required String leadId,
    required String counsellorId,
    required String assignedBy,
  }) async {
    try {
      await _supabase.rpc('assign_lead', params: {
        'p_lead_id': leadId,
        'p_counsellor_id': counsellorId,
        'p_assigned_by': assignedBy,
      });
      return true;
    } catch (e) {
      print('Error assigning lead: $e');
      return false;
    }
  }

  /// Bulk assign leads to counsellors
  Future<int> bulkAssignLeads({
    required List<String> leadIds,
    required String counsellorId,
    required String assignedBy,
  }) async {
    int successCount = 0;
    for (final leadId in leadIds) {
      final success = await assignLead(
        leadId: leadId,
        counsellorId: counsellorId,
        assignedBy: assignedBy,
      );
      if (success) successCount++;
    }
    return successCount;
  }

  // ============================================================================
  // LEAD STATUS UPDATES
  // ============================================================================

  /// Update lead status
  Future<bool> updateLeadStatus({
    required String leadId,
    required LeadStatus newStatus,
    String? subStatus,
    required String changedBy,
    String? notes,
    DateTime? nextFollowup,
  }) async {
    try {
      await _supabase.rpc('update_lead_status', params: {
        'p_lead_id': leadId,
        'p_new_status': newStatus.value,
        'p_sub_status': subStatus,
        'p_changed_by': changedBy,
        'p_notes': notes,
        'p_next_followup': nextFollowup?.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error updating lead status: $e');
      return false;
    }
  }

  /// Quick update for simple field changes
  Future<bool> updateLead(String leadId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('leads').update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', leadId);
      return true;
    } catch (e) {
      print('Error updating lead: $e');
      return false;
    }
  }

  /// Mark lead as contacted
  Future<bool> markAsContacted(
      String leadId, String changedBy, String? notes) async {
    return updateLeadStatus(
      leadId: leadId,
      newStatus: LeadStatus.contacted,
      changedBy: changedBy,
      notes: notes,
    );
  }

  /// Mark lead as interested
  Future<bool> markAsInterested(
    String leadId,
    String changedBy,
    String? notes,
    DateTime? nextFollowup,
  ) async {
    return updateLeadStatus(
      leadId: leadId,
      newStatus: LeadStatus.interested,
      changedBy: changedBy,
      notes: notes,
      nextFollowup: nextFollowup,
    );
  }

  /// Mark lead as converted
  Future<bool> markAsConverted(String leadId, String changedBy) async {
    return updateLeadStatus(
      leadId: leadId,
      newStatus: LeadStatus.converted,
      changedBy: changedBy,
      notes: 'Lead successfully converted to admission',
    );
  }

  /// Move lead to trash
  Future<bool> moveToTrash(
      String leadId, String changedBy, String? reason) async {
    return updateLeadStatus(
      leadId: leadId,
      newStatus: LeadStatus.trash,
      changedBy: changedBy,
      notes: reason ?? 'Lead moved to trash',
    );
  }

  // ============================================================================
  // LEAD HISTORY
  // ============================================================================

  /// Get lead status history
  Future<List<LeadStatusHistory>> getLeadHistory(String leadId) async {
    try {
      final response = await _supabase
          .from('lead_status_history')
          .select()
          .eq('lead_id', leadId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => LeadStatusHistory.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching lead history: $e');
      return [];
    }
  }

  /// Add note to lead history
  Future<bool> addLeadNote({
    required String leadId,
    required String note,
    required String addedBy,
  }) async {
    try {
      await _supabase.from('lead_status_history').insert({
        'lead_id': leadId,
        'new_status': 'note', // Special status for notes
        'changed_by': addedBy,
        'change_type': 'note',
        'notes': note,
      });

      // Also update the last_remark on lead
      await updateLead(leadId, {'last_remark': note});

      return true;
    } catch (e) {
      print('Error adding lead note: $e');
      return false;
    }
  }

  // ============================================================================
  // FOLLOW-UP MANAGEMENT
  // ============================================================================

  /// Schedule a follow-up
  Future<bool> scheduleFollowup({
    required String leadId,
    required String counsellorId,
    required DateTime scheduledDate,
    FollowupType type = FollowupType.call,
    String? purpose,
  }) async {
    try {
      // Insert follow-up
      await _supabase.from('lead_followups').insert({
        'lead_id': leadId,
        'counsellor_id': counsellorId,
        'scheduled_date': scheduledDate.toIso8601String(),
        'type': type.value,
        'purpose': purpose,
        'status': 'pending',
      });

      // Update lead's next_followup_date
      await updateLead(leadId, {
        'next_followup_date': scheduledDate.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error scheduling followup: $e');
      return false;
    }
  }

  /// Complete a follow-up
  Future<bool> completeFollowup({
    required String followupId,
    required String outcome,
    String? notes,
    String? nextAction,
  }) async {
    try {
      await _supabase.from('lead_followups').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'outcome': outcome,
        'notes': notes,
        'next_action': nextAction,
      }).eq('id', followupId);

      return true;
    } catch (e) {
      print('Error completing followup: $e');
      return false;
    }
  }

  /// Get follow-ups for a lead
  Future<List<LeadFollowup>> getLeadFollowups(String leadId) async {
    try {
      final response = await _supabase
          .from('lead_followups')
          .select()
          .eq('lead_id', leadId)
          .order('scheduled_date', ascending: false);

      return (response as List)
          .map((json) => LeadFollowup.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching followups: $e');
      return [];
    }
  }

  /// Get pending follow-ups for a counsellor
  Future<List<LeadFollowup>> getPendingFollowups(String counsellorId) async {
    try {
      final response = await _supabase
          .from('lead_followups')
          .select()
          .eq('counsellor_id', counsellorId)
          .eq('status', 'pending')
          .order('scheduled_date', ascending: true);

      return (response as List)
          .map((json) => LeadFollowup.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching pending followups: $e');
      return [];
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get overall lead statistics
  Future<Map<String, dynamic>> getLeadStats() async {
    try {
      final response = await _supabase.rpc('get_lead_stats');

      if (response != null && response is List && response.isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error fetching lead stats: $e');
      return {};
    }
  }

  /// Get lead count by status
  Future<Map<String, int>> getLeadCountByStatus() async {
    try {
      final response = await _supabase.from('leads').select('status');

      final leads = response as List;
      final counts = <String, int>{};

      for (final lead in leads) {
        final status = lead['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      print('Error fetching status counts: $e');
      return {};
    }
  }

  /// Get lead count for a counsellor
  Future<Map<String, int>> getCounsellorLeadCounts(String counsellorId) async {
    try {
      final response = await _supabase
          .from('leads')
          .select('status, is_converted')
          .eq('assigned_counsellor_id', counsellorId);

      final leads = response as List;
      int total = leads.length;
      int active = 0;
      int converted = 0;

      for (final lead in leads) {
        if (lead['is_converted'] == true) converted++;
        if (['assigned', 'contacted', 'interested', 'followup', 'form_sent']
            .contains(lead['status'])) {
          active++;
        }
      }

      return {
        'total': total,
        'active': active,
        'converted': converted,
      };
    } catch (e) {
      print('Error fetching counsellor counts: $e');
      return {'total': 0, 'active': 0, 'converted': 0};
    }
  }

  // ============================================================================
  // REAL-TIME SUBSCRIPTIONS
  // ============================================================================

  /// Subscribe to new leads (for Dean)
  Stream<List<Lead>> subscribeToNewLeads() {
    return _supabase
        .from('leads')
        .stream(primaryKey: ['id'])
        .eq('status', 'new')
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Lead.fromJson(json)).toList());
  }

  /// Subscribe to counsellor's leads
  Stream<List<Lead>> subscribeToCounsellorLeads(String counsellorId) {
    return _supabase
        .from('leads')
        .stream(primaryKey: ['id'])
        .eq('assigned_counsellor_id', counsellorId)
        .order('updated_at', ascending: false)
        .map((data) => data.map((json) => Lead.fromJson(json)).toList());
  }

  // ============================================================================
  // LEAD TRANSFER
  // ============================================================================

  /// Transfer lead to another counsellor (preserves status)
  Future<bool> transferLead({
    required String leadId,
    required String newCounsellorId,
    required String transferredBy,
    String? reason,
  }) async {
    try {
      await _supabase.rpc('transfer_lead', params: {
        'p_lead_id': leadId,
        'p_new_counsellor_id': newCounsellorId,
        'p_transferred_by': transferredBy,
        'p_reason': reason,
      });
      return true;
    } catch (e) {
      print('Error transferring lead: $e');
      return false;
    }
  }

  // ============================================================================
  // ACTIVITY FEED
  // ============================================================================

  /// Get recent activity for all leads (for Dean)
  Future<List<Map<String, dynamic>>> getActivityFeed({
    int limit = 50,
    String? counsellorId,
  }) async {
    try {
      dynamic query = _supabase.from('lead_activity_feed').select();

      if (counsellorId != null) {
        query = query.eq('counsellor_id', counsellorId);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching activity feed: $e');
      return [];
    }
  }

  /// Subscribe to activity feed (real-time updates)
  Stream<List<Map<String, dynamic>>> subscribeToActivityFeed() {
    return _supabase
        .from('lead_status_history')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.cast<Map<String, dynamic>>());
  }

  // ============================================================================
  // SLA VIOLATIONS
  // ============================================================================

  /// Get all SLA violations
  Future<List<Map<String, dynamic>>> getSlaViolations({
    String? counsellorId,
    String? violationType,
  }) async {
    try {
      var query = _supabase.from('sla_violations').select();

      if (counsellorId != null) {
        query = query.eq('assigned_counsellor_id', counsellorId);
      }
      if (violationType != null) {
        query = query.eq('violation_type', violationType);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching SLA violations: $e');
      return [];
    }
  }

  /// Get SLA statistics
  Future<Map<String, int>> getSlaStats() async {
    try {
      final response = await _supabase.rpc('get_sla_stats');

      if (response != null && response is List && response.isNotEmpty) {
        final stats = response[0];
        return {
          'total': (stats['total_violations'] as int?) ?? 0,
          'critical': (stats['critical_count'] as int?) ?? 0,
          'warning': (stats['warning_count'] as int?) ?? 0,
          'stale': (stats['stale_count'] as int?) ?? 0,
        };
      }
      return {'total': 0, 'critical': 0, 'warning': 0, 'stale': 0};
    } catch (e) {
      print('Error fetching SLA stats: $e');
      return {'total': 0, 'critical': 0, 'warning': 0, 'stale': 0};
    }
  }

  /// Get critical violations only
  Future<List<Map<String, dynamic>>> getCriticalViolations() async {
    try {
      final response = await _supabase
          .from('sla_violations')
          .select()
          .like('violation_type', 'critical%')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching critical violations: $e');
      return [];
    }
  }
}
