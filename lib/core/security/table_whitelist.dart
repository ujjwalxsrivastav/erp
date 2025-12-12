/// Safe Table Name Whitelist
///
/// Security Feature:
/// Prevents SQL injection through dynamic table names by whitelisting
/// valid table names instead of constructing them from user input.

/// Whitelist of valid marks table configurations
class TableWhitelist {
  /// Valid year values
  static const Set<String> validYears = {'1', '2', '3', '4'};

  /// Valid section values
  static const Set<String> validSections = {'a', 'b', 'c', 'd'};

  /// Valid exam types and their table suffixes
  static const Map<String, String> examTypeSuffixes = {
    'midterm': 'midterm',
    'mid term': 'midterm',
    'mid-term': 'midterm',
    'endsemester': 'endsem',
    'end semester': 'endsem',
    'end-semester': 'endsem',
    'endsem': 'endsem',
    'quiz': 'quiz',
    'assignment': 'assignment',
  };

  /// Complete whitelist of all valid marks table names
  /// Pre-generated to avoid any string manipulation with user input
  static final Set<String> _validMarksTableNames = _generateValidTableNames();

  /// Generate all valid table name combinations
  static Set<String> _generateValidTableNames() {
    final tables = <String>{};

    for (final year in validYears) {
      for (final section in validSections) {
        for (final suffix in examTypeSuffixes.values.toSet()) {
          tables.add('marks_year${year}_section${section}_$suffix');
        }
      }
    }

    return tables;
  }

  /// Get safe table name or null if invalid
  /// This is the ONLY method that should be used to get table names
  static String? getSafeMarksTableName({
    required String year,
    required String section,
    required String examType,
  }) {
    // Normalize inputs
    final normalizedYear = year.trim();
    final normalizedSection = section.trim().toLowerCase();
    final normalizedExamType = examType.trim().toLowerCase();

    // Validate year
    if (!validYears.contains(normalizedYear)) {
      return null;
    }

    // Validate section
    if (!validSections.contains(normalizedSection)) {
      return null;
    }

    // Get exam type suffix
    final suffix = examTypeSuffixes[normalizedExamType];
    if (suffix == null) {
      return null;
    }

    // Construct table name
    final tableName =
        'marks_year${normalizedYear}_section${normalizedSection}_$suffix';

    // Double-check against whitelist (defense in depth)
    if (!_validMarksTableNames.contains(tableName)) {
      return null;
    }

    return tableName;
  }

  /// Check if a table name is valid (for validation purposes)
  static bool isValidMarksTableName(String tableName) {
    return _validMarksTableNames.contains(tableName);
  }

  /// Get all valid table names (for migration/setup purposes)
  static Set<String> getAllValidMarksTableNames() {
    return Set.unmodifiable(_validMarksTableNames);
  }

  // =====================
  // Other table whitelists
  // =====================

  /// Whitelist of core tables that can be accessed
  static const Set<String> coreTables = {
    'users',
    'student_details',
    'teacher_details',
    'subjects',
    'student_subjects',
    'timetable',
    'assignments',
    'assignment_submissions',
    'study_materials',
    'announcements',
    'teacher_leaves',
    'teacher_arrangements',
    'holidays',
    'events',
    'teacher_salary',
    'teacher_activity_logs',
    'fee_transactions',
    // Security tables
    'device_login_attempts',
    'ip_login_attempts',
    'blocked_devices',
    'blocked_ips',
    'security_audit_log',
  };

  /// Check if a core table name is valid
  static bool isValidCoreTable(String tableName) {
    return coreTables.contains(tableName.toLowerCase());
  }

  /// Whitelist of storage buckets
  static const Set<String> validStorageBuckets = {
    'student-profiles',
    'teacher-profiles',
    'assignments',
    'assignment-submissions',
    'study-materials',
    'teacher-documents',
  };

  /// Check if a storage bucket name is valid
  static bool isValidStorageBucket(String bucketName) {
    return validStorageBuckets.contains(bucketName.toLowerCase());
  }
}

/// Result of table name validation
class TableValidationResult {
  final bool isValid;
  final String? tableName;
  final String? errorMessage;

  const TableValidationResult._({
    required this.isValid,
    this.tableName,
    this.errorMessage,
  });

  factory TableValidationResult.valid(String tableName) {
    return TableValidationResult._(isValid: true, tableName: tableName);
  }

  factory TableValidationResult.invalid(String error) {
    return TableValidationResult._(isValid: false, errorMessage: error);
  }
}

/// Safe table name builder with validation
class SafeTableBuilder {
  /// Build and validate a marks table name
  static TableValidationResult buildMarksTableName({
    required String year,
    required String section,
    required String examType,
  }) {
    final tableName = TableWhitelist.getSafeMarksTableName(
      year: year,
      section: section,
      examType: examType,
    );

    if (tableName == null) {
      return TableValidationResult.invalid(
        'Invalid table parameters: year=$year, section=$section, examType=$examType',
      );
    }

    return TableValidationResult.valid(tableName);
  }

  /// Validate and return a core table name
  static TableValidationResult validateCoreTable(String tableName) {
    if (TableWhitelist.isValidCoreTable(tableName)) {
      return TableValidationResult.valid(tableName.toLowerCase());
    }
    return TableValidationResult.invalid('Invalid table name: $tableName');
  }

  /// Validate and return a storage bucket name
  static TableValidationResult validateStorageBucket(String bucketName) {
    if (TableWhitelist.isValidStorageBucket(bucketName)) {
      return TableValidationResult.valid(bucketName.toLowerCase());
    }
    return TableValidationResult.invalid('Invalid bucket name: $bucketName');
  }
}
