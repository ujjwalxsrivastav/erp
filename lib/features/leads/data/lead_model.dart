import 'lead_status.dart';

/// Lead Model - Represents a prospective student inquiry
class Lead {
  final String id;

  // Student Information
  final String studentName;
  final String? email;
  final String phone;
  final String? alternatePhone;
  final String? city;
  final String? state;
  final String? address;

  // Academic Background
  final String? qualification;
  final double? percentage;
  final int? passingYear;

  // Course Interest
  final String preferredCourse;
  final String? preferredBatch;
  final String? preferredSession;

  // Lead Metadata
  final LeadSource source;
  final String? sourceDetail;
  final LeadPriority priority;
  final List<String>? tags;

  // Assignment
  final String? assignedCounsellorId;
  final String? assignedBy;
  final DateTime? assignedAt;

  // Status Tracking
  final LeadStatus status;
  final String? subStatus;
  final DateTime? lastContactDate;
  final DateTime? nextFollowupDate;
  final int followupCount;

  // Conversion Tracking
  final bool isConverted;
  final DateTime? convertedAt;
  final String? admissionFormId;
  final String? seatAllotmentId;

  // Notes
  final String? notes;
  final String? lastRemark;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  Lead({
    required this.id,
    required this.studentName,
    this.email,
    required this.phone,
    this.alternatePhone,
    this.city,
    this.state,
    this.address,
    this.qualification,
    this.percentage,
    this.passingYear,
    required this.preferredCourse,
    this.preferredBatch,
    this.preferredSession,
    this.source = LeadSource.website,
    this.sourceDetail,
    this.priority = LeadPriority.normal,
    this.tags,
    this.assignedCounsellorId,
    this.assignedBy,
    this.assignedAt,
    this.status = LeadStatus.newLead,
    this.subStatus,
    this.lastContactDate,
    this.nextFollowupDate,
    this.followupCount = 0,
    this.isConverted = false,
    this.convertedAt,
    this.admissionFormId,
    this.seatAllotmentId,
    this.notes,
    this.lastRemark,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] as String,
      studentName: json['student_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      alternatePhone: json['alternate_phone'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      address: json['address'] as String?,
      qualification: json['qualification'] as String?,
      percentage: json['percentage'] != null
          ? double.tryParse(json['percentage'].toString())
          : null,
      passingYear: json['passing_year'] as int?,
      preferredCourse: json['preferred_course'] as String,
      preferredBatch: json['preferred_batch'] as String?,
      preferredSession: json['preferred_session'] as String?,
      source: LeadSource.fromString(json['source'] as String?),
      sourceDetail: json['source_detail'] as String?,
      priority: LeadPriority.fromString(json['priority'] as String?),
      tags:
          json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      assignedCounsellorId: json['assigned_counsellor_id'] as String?,
      assignedBy: json['assigned_by'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      status: LeadStatus.fromString(json['status'] as String?),
      subStatus: json['sub_status'] as String?,
      lastContactDate: json['last_contact_date'] != null
          ? DateTime.parse(json['last_contact_date'] as String)
          : null,
      nextFollowupDate: json['next_followup_date'] != null
          ? DateTime.parse(json['next_followup_date'] as String)
          : null,
      followupCount: json['followup_count'] as int? ?? 0,
      isConverted: json['is_converted'] as bool? ?? false,
      convertedAt: json['converted_at'] != null
          ? DateTime.parse(json['converted_at'] as String)
          : null,
      admissionFormId: json['admission_form_id'] as String?,
      seatAllotmentId: json['seat_allotment_id'] as String?,
      notes: json['notes'] as String?,
      lastRemark: json['last_remark'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_name': studentName,
      'email': email,
      'phone': phone,
      'alternate_phone': alternatePhone,
      'city': city,
      'state': state,
      'address': address,
      'qualification': qualification,
      'percentage': percentage,
      'passing_year': passingYear,
      'preferred_course': preferredCourse,
      'preferred_batch': preferredBatch,
      'preferred_session': preferredSession,
      'source': source.value,
      'source_detail': sourceDetail,
      'priority': priority.value,
      'tags': tags,
      'assigned_counsellor_id': assignedCounsellorId,
      'assigned_by': assignedBy,
      'assigned_at': assignedAt?.toIso8601String(),
      'status': status.value,
      'sub_status': subStatus,
      'last_contact_date': lastContactDate?.toIso8601String(),
      'next_followup_date': nextFollowupDate?.toIso8601String(),
      'followup_count': followupCount,
      'is_converted': isConverted,
      'converted_at': convertedAt?.toIso8601String(),
      'admission_form_id': admissionFormId,
      'seat_allotment_id': seatAllotmentId,
      'notes': notes,
      'last_remark': lastRemark,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Lead copyWith({
    String? id,
    String? studentName,
    String? email,
    String? phone,
    String? alternatePhone,
    String? city,
    String? state,
    String? address,
    String? qualification,
    double? percentage,
    int? passingYear,
    String? preferredCourse,
    String? preferredBatch,
    String? preferredSession,
    LeadSource? source,
    String? sourceDetail,
    LeadPriority? priority,
    List<String>? tags,
    String? assignedCounsellorId,
    String? assignedBy,
    DateTime? assignedAt,
    LeadStatus? status,
    String? subStatus,
    DateTime? lastContactDate,
    DateTime? nextFollowupDate,
    int? followupCount,
    bool? isConverted,
    DateTime? convertedAt,
    String? admissionFormId,
    String? seatAllotmentId,
    String? notes,
    String? lastRemark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      city: city ?? this.city,
      state: state ?? this.state,
      address: address ?? this.address,
      qualification: qualification ?? this.qualification,
      percentage: percentage ?? this.percentage,
      passingYear: passingYear ?? this.passingYear,
      preferredCourse: preferredCourse ?? this.preferredCourse,
      preferredBatch: preferredBatch ?? this.preferredBatch,
      preferredSession: preferredSession ?? this.preferredSession,
      source: source ?? this.source,
      sourceDetail: sourceDetail ?? this.sourceDetail,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      assignedCounsellorId: assignedCounsellorId ?? this.assignedCounsellorId,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      status: status ?? this.status,
      subStatus: subStatus ?? this.subStatus,
      lastContactDate: lastContactDate ?? this.lastContactDate,
      nextFollowupDate: nextFollowupDate ?? this.nextFollowupDate,
      followupCount: followupCount ?? this.followupCount,
      isConverted: isConverted ?? this.isConverted,
      convertedAt: convertedAt ?? this.convertedAt,
      admissionFormId: admissionFormId ?? this.admissionFormId,
      seatAllotmentId: seatAllotmentId ?? this.seatAllotmentId,
      notes: notes ?? this.notes,
      lastRemark: lastRemark ?? this.lastRemark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if lead needs follow-up today
  bool get needsFollowupToday {
    if (nextFollowupDate == null) return false;
    final today = DateTime.now();
    return nextFollowupDate!.year == today.year &&
        nextFollowupDate!.month == today.month &&
        nextFollowupDate!.day == today.day;
  }

  /// Check if follow-up is overdue
  bool get isFollowupOverdue {
    if (nextFollowupDate == null) return false;
    return nextFollowupDate!.isBefore(DateTime.now());
  }

  /// Get time since creation
  String get timeSinceCreation {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

/// Lead Status History - Audit trail entry
class LeadStatusHistory {
  final String id;
  final String leadId;
  final String? oldStatus;
  final String newStatus;
  final String? oldSubStatus;
  final String? newSubStatus;
  final String changedBy;
  final String changeType;
  final String? changeReason;
  final String? notes;
  final DateTime createdAt;

  LeadStatusHistory({
    required this.id,
    required this.leadId,
    this.oldStatus,
    required this.newStatus,
    this.oldSubStatus,
    this.newSubStatus,
    required this.changedBy,
    required this.changeType,
    this.changeReason,
    this.notes,
    required this.createdAt,
  });

  factory LeadStatusHistory.fromJson(Map<String, dynamic> json) {
    return LeadStatusHistory(
      id: json['id'] as String,
      leadId: json['lead_id'] as String,
      oldStatus: json['old_status'] as String?,
      newStatus: json['new_status'] as String,
      oldSubStatus: json['old_sub_status'] as String?,
      newSubStatus: json['new_sub_status'] as String?,
      changedBy: json['changed_by'] as String,
      changeType: json['change_type'] as String? ?? 'status_update',
      changeReason: json['change_reason'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Lead Followup - Scheduled follow-up entry
class LeadFollowup {
  final String id;
  final String leadId;
  final String counsellorId;
  final DateTime scheduledDate;
  final DateTime? completedAt;
  final FollowupType type;
  final String? purpose;
  final String? outcome;
  final String? notes;
  final String? nextAction;
  final FollowupStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeadFollowup({
    required this.id,
    required this.leadId,
    required this.counsellorId,
    required this.scheduledDate,
    this.completedAt,
    this.type = FollowupType.call,
    this.purpose,
    this.outcome,
    this.notes,
    this.nextAction,
    this.status = FollowupStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeadFollowup.fromJson(Map<String, dynamic> json) {
    return LeadFollowup(
      id: json['id'] as String,
      leadId: json['lead_id'] as String,
      counsellorId: json['counsellor_id'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      type: FollowupType.fromString(json['type'] as String?),
      purpose: json['purpose'] as String?,
      outcome: json['outcome'] as String?,
      notes: json['notes'] as String?,
      nextAction: json['next_action'] as String?,
      status: FollowupStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lead_id': leadId,
      'counsellor_id': counsellorId,
      'scheduled_date': scheduledDate.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'type': type.value,
      'purpose': purpose,
      'outcome': outcome,
      'notes': notes,
      'next_action': nextAction,
      'status': status.value,
    };
  }

  bool get isPending => status == FollowupStatus.pending;
  bool get isOverdue => isPending && scheduledDate.isBefore(DateTime.now());
  bool get isDueToday {
    final today = DateTime.now();
    return scheduledDate.year == today.year &&
        scheduledDate.month == today.month &&
        scheduledDate.day == today.day;
  }
}
