/// Lead Status Enum and Helpers
/// Defines all possible lead statuses and their properties

enum LeadStatus {
  newLead('new', 'New', '🆕'),
  assigned('assigned', 'Assigned', '📋'),
  contacted('contacted', 'Contacted', '📞'),
  interested('interested', 'Interested', '✨'),
  followup('followup', 'Follow-up', '🔄'),
  formSent('form_sent', 'Form Sent', '📝'),
  formFilled('form_filled', 'Form Filled', '✅'),
  seatBooked('seat_booked', 'Seat Booked', '💺'),
  converted('converted', 'Converted', '🎉'),
  notInterested('not_interested', 'Not Interested', '😔'),
  trash('trash', 'Trash', '🗑️');

  final String value;
  final String label;
  final String emoji;

  const LeadStatus(this.value, this.label, this.emoji);

  static LeadStatus fromString(String? value) {
    if (value == null) return LeadStatus.newLead;
    return LeadStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => LeadStatus.newLead,
    );
  }

  bool get isActive => [
        LeadStatus.assigned,
        LeadStatus.contacted,
        LeadStatus.interested,
        LeadStatus.followup,
        LeadStatus.formSent,
        LeadStatus.formFilled,
        LeadStatus.seatBooked,
      ].contains(this);

  bool get isTerminal => [
        LeadStatus.converted,
        LeadStatus.notInterested,
        LeadStatus.trash,
      ].contains(this);

  bool get isPositive => [
        LeadStatus.interested,
        LeadStatus.formSent,
        LeadStatus.formFilled,
        LeadStatus.seatBooked,
        LeadStatus.converted,
      ].contains(this);
}

enum LeadPriority {
  high('high', 'High', '🔴'),
  normal('normal', 'Normal', '🟡'),
  low('low', 'Low', '🟢');

  final String value;
  final String label;
  final String emoji;

  const LeadPriority(this.value, this.label, this.emoji);

  static LeadPriority fromString(String? value) {
    if (value == null) return LeadPriority.normal;
    return LeadPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => LeadPriority.normal,
    );
  }
}

enum LeadSource {
  website('website', 'Website', '🌐'),
  manual('manual', 'Manual', '✍️'),
  referral('referral', 'Referral', '👥'),
  walkIn('walk-in', 'Walk-in', '🚶'),
  socialMedia('social_media', 'Social Media', '📱'),
  advertisement('advertisement', 'Advertisement', '📺');

  final String value;
  final String label;
  final String emoji;

  const LeadSource(this.value, this.label, this.emoji);

  static LeadSource fromString(String? value) {
    if (value == null) return LeadSource.website;
    return LeadSource.values.firstWhere(
      (s) => s.value == value,
      orElse: () => LeadSource.website,
    );
  }

  bool get isManual => this == LeadSource.manual;
}

/// Referral Type for manual leads
enum ReferralType {
  websiteCall('website_call', 'Website Call', '📞'),
  studentReferral('student', 'Student Referral', '🎓'),
  facultyReferral('faculty', 'Faculty Referral', '👨‍🏫'),
  other('other', 'Other', '📋');

  final String value;
  final String label;
  final String emoji;

  const ReferralType(this.value, this.label, this.emoji);

  static ReferralType? fromString(String? value) {
    if (value == null) return null;
    return ReferralType.values.firstWhere(
      (r) => r.value == value,
      orElse: () => ReferralType.other,
    );
  }

  bool get requiresReferrerInfo =>
      this == ReferralType.studentReferral ||
      this == ReferralType.facultyReferral;
}

enum FollowupType {
  call('call', 'Call', '📞'),
  email('email', 'Email', '📧'),
  whatsapp('whatsapp', 'WhatsApp', '💬'),
  sms('sms', 'SMS', '📱'),
  visit('visit', 'Campus Visit', '🏫');

  final String value;
  final String label;
  final String emoji;

  const FollowupType(this.value, this.label, this.emoji);

  static FollowupType fromString(String? value) {
    if (value == null) return FollowupType.call;
    return FollowupType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => FollowupType.call,
    );
  }
}

enum FollowupStatus {
  pending('pending', 'Pending'),
  completed('completed', 'Completed'),
  missed('missed', 'Missed'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;

  const FollowupStatus(this.value, this.label);

  static FollowupStatus fromString(String? value) {
    if (value == null) return FollowupStatus.pending;
    return FollowupStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => FollowupStatus.pending,
    );
  }
}

/// Helper class for status-related UI properties
class LeadStatusHelper {
  static int getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.newLead:
        return 0xFF2196F3; // Blue
      case LeadStatus.assigned:
        return 0xFF9C27B0; // Purple
      case LeadStatus.contacted:
        return 0xFFFF9800; // Orange
      case LeadStatus.interested:
        return 0xFF4CAF50; // Green
      case LeadStatus.followup:
        return 0xFFFFEB3B; // Yellow
      case LeadStatus.formSent:
        return 0xFF00BCD4; // Cyan
      case LeadStatus.formFilled:
        return 0xFF8BC34A; // Light Green
      case LeadStatus.seatBooked:
        return 0xFF009688; // Teal
      case LeadStatus.converted:
        return 0xFF4CAF50; // Green
      case LeadStatus.notInterested:
        return 0xFF9E9E9E; // Grey
      case LeadStatus.trash:
        return 0xFFF44336; // Red
    }
  }

  static int getPriorityColor(LeadPriority priority) {
    switch (priority) {
      case LeadPriority.high:
        return 0xFFF44336; // Red
      case LeadPriority.normal:
        return 0xFFFF9800; // Orange
      case LeadPriority.low:
        return 0xFF4CAF50; // Green
    }
  }

  /// Get next possible statuses based on current status
  static List<LeadStatus> getNextStatuses(LeadStatus current) {
    switch (current) {
      case LeadStatus.newLead:
        return [LeadStatus.assigned];
      case LeadStatus.assigned:
        return [
          LeadStatus.contacted,
          LeadStatus.notInterested,
          LeadStatus.trash
        ];
      case LeadStatus.contacted:
        return [
          LeadStatus.interested,
          LeadStatus.followup,
          LeadStatus.notInterested,
          LeadStatus.trash
        ];
      case LeadStatus.interested:
        return [
          LeadStatus.formSent,
          LeadStatus.followup,
          LeadStatus.notInterested
        ];
      case LeadStatus.followup:
        return [
          LeadStatus.contacted,
          LeadStatus.interested,
          LeadStatus.notInterested,
          LeadStatus.trash
        ];
      case LeadStatus.formSent:
        return [
          LeadStatus.formFilled,
          LeadStatus.followup,
          LeadStatus.notInterested
        ];
      case LeadStatus.formFilled:
        return [LeadStatus.seatBooked, LeadStatus.followup];
      case LeadStatus.seatBooked:
        return [LeadStatus.converted, LeadStatus.followup];
      case LeadStatus.converted:
        return []; // Terminal state
      case LeadStatus.notInterested:
        return [LeadStatus.trash, LeadStatus.followup]; // Can revive
      case LeadStatus.trash:
        return []; // Terminal state
    }
  }
}
