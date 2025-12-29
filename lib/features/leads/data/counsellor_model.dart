/// Counsellor Model - Represents a counsellor profile with performance metrics

class Counsellor {
  final String id;
  final String userId;

  // Profile
  final String name;
  final String? email;
  final String? phone;
  final String? profileImage;

  // Configuration
  final int maxActiveLeads;
  final String? specialization;

  // Cached Performance Metrics
  final int totalLeadsAssigned;
  final int totalConversions;
  final double conversionRate;

  // Status
  final bool isActive;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  Counsellor({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.profileImage,
    this.maxActiveLeads = 50,
    this.specialization,
    this.totalLeadsAssigned = 0,
    this.totalConversions = 0,
    this.conversionRate = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Counsellor.fromJson(Map<String, dynamic> json) {
    return Counsellor(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      profileImage: json['profile_image'] as String?,
      maxActiveLeads: json['max_active_leads'] as int? ?? 50,
      specialization: json['specialization'] as String?,
      totalLeadsAssigned: json['total_leads_assigned'] as int? ?? 0,
      totalConversions: json['total_conversions'] as int? ?? 0,
      conversionRate: json['conversion_rate'] != null
          ? double.tryParse(json['conversion_rate'].toString()) ?? 0
          : 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'profile_image': profileImage,
      'max_active_leads': maxActiveLeads,
      'specialization': specialization,
      'total_leads_assigned': totalLeadsAssigned,
      'total_conversions': totalConversions,
      'conversion_rate': conversionRate,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Counsellor copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    int? maxActiveLeads,
    String? specialization,
    int? totalLeadsAssigned,
    int? totalConversions,
    double? conversionRate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Counsellor(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      maxActiveLeads: maxActiveLeads ?? this.maxActiveLeads,
      specialization: specialization ?? this.specialization,
      totalLeadsAssigned: totalLeadsAssigned ?? this.totalLeadsAssigned,
      totalConversions: totalConversions ?? this.totalConversions,
      conversionRate: conversionRate ?? this.conversionRate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get initials for avatar
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// Counsellor Performance - Extended performance data from view
class CounsellorPerformance {
  final String counsellorId;
  final String userId;
  final String counsellorName;
  final String? email;
  final String? phone;
  final String? specialization;
  final bool isActive;

  // Lead Counts
  final int totalAssigned;
  final int leadsWorked;
  final int conversions;
  final int trashed;
  final int notInterested;
  final int activePipeline;

  // Today's Stats
  final int assignedToday;
  final int convertedToday;

  // Metrics
  final double conversionRate;
  final double? avgResponseHours;

  // Workload
  final int maxActiveLeads;
  final int availableCapacity;

  CounsellorPerformance({
    required this.counsellorId,
    required this.userId,
    required this.counsellorName,
    this.email,
    this.phone,
    this.specialization,
    this.isActive = true,
    this.totalAssigned = 0,
    this.leadsWorked = 0,
    this.conversions = 0,
    this.trashed = 0,
    this.notInterested = 0,
    this.activePipeline = 0,
    this.assignedToday = 0,
    this.convertedToday = 0,
    this.conversionRate = 0,
    this.avgResponseHours,
    this.maxActiveLeads = 50,
    this.availableCapacity = 50,
  });

  factory CounsellorPerformance.fromJson(Map<String, dynamic> json) {
    return CounsellorPerformance(
      counsellorId: json['counsellor_id'] as String,
      userId: json['user_id'] as String,
      counsellorName: json['counsellor_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      specialization: json['specialization'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      totalAssigned: json['total_assigned'] as int? ?? 0,
      leadsWorked: json['leads_worked'] as int? ?? 0,
      conversions: json['conversions'] as int? ?? 0,
      trashed: json['trashed'] as int? ?? 0,
      notInterested: json['not_interested'] as int? ?? 0,
      activePipeline: json['active_pipeline'] as int? ?? 0,
      assignedToday: json['assigned_today'] as int? ?? 0,
      convertedToday: json['converted_today'] as int? ?? 0,
      conversionRate: json['conversion_rate'] != null
          ? double.tryParse(json['conversion_rate'].toString()) ?? 0
          : 0,
      avgResponseHours: json['avg_response_hours'] != null
          ? double.tryParse(json['avg_response_hours'].toString())
          : null,
      maxActiveLeads: json['max_active_leads'] as int? ?? 50,
      availableCapacity: json['available_capacity'] as int? ?? 50,
    );
  }

  /// Get performance rating (1-5 stars based on conversion rate)
  int get performanceRating {
    if (conversionRate >= 40) return 5;
    if (conversionRate >= 30) return 4;
    if (conversionRate >= 20) return 3;
    if (conversionRate >= 10) return 2;
    return 1;
  }

  /// Check if counsellor is available for new leads
  bool get isAvailable => isActive && availableCapacity > 0;

  /// Get workload percentage
  double get workloadPercentage {
    if (maxActiveLeads == 0) return 100;
    return ((maxActiveLeads - availableCapacity) / maxActiveLeads) * 100;
  }
}
