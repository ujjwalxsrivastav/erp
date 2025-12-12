/// Input Validation Utility
///
/// Security Features:
/// 1. SQL Injection prevention
/// 2. XSS prevention
/// 3. Email/Phone validation
/// 4. Name sanitization
/// 5. Password strength validation

/// Result of input validation
class ValidationResult {
  final bool isValid;
  final String? sanitizedValue;
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.sanitizedValue,
    this.errorMessage,
  });

  factory ValidationResult.valid(String value) {
    return ValidationResult(isValid: true, sanitizedValue: value);
  }

  factory ValidationResult.invalid(String error) {
    return ValidationResult(isValid: false, errorMessage: error);
  }
}

/// Password strength levels
enum PasswordStrength {
  weak,
  fair,
  good,
  strong,
}

/// Input validator with comprehensive security checks
class InputValidator {
  // SQL injection patterns to check for
  static const List<String> _sqlKeywords = [
    'select',
    'insert',
    'update',
    'delete',
    'drop',
    'create',
    'alter',
    'exec',
    'execute',
    'union',
    'join',
    'where',
    'from',
    'having',
    'group by',
    'order by',
    '--',
    '/*',
    '*/',
    'xp_',
    'sp_',
    'char(',
    'nchar(',
    'varchar(',
    'nvarchar(',
  ];

  // XSS patterns to check for
  static const List<String> _xssPatterns = [
    '<script',
    '</script',
    'javascript:',
    'vbscript:',
    'onclick',
    'onerror',
    'onload',
    'onmouseover',
    '<iframe',
    '<object',
    '<embed',
    '<form',
    'expression(',
    '<svg',
    '<math',
    '<style',
    '<link',
    '<meta',
  ];

  /// Check if input contains SQL injection patterns
  static bool containsSqlInjection(String input) {
    if (input.isEmpty) return false;

    final lowerInput = input.toLowerCase();

    // Check for quotes and semicolons
    if (input.contains("'") ||
        input.contains('"') ||
        input.contains(';') ||
        input.contains('\\')) {
      return true;
    }

    // Check for SQL keywords
    for (final keyword in _sqlKeywords) {
      if (lowerInput.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Check if input contains XSS patterns
  static bool containsXss(String input) {
    if (input.isEmpty) return false;

    final lowerInput = input.toLowerCase();

    // Check for angle brackets
    if (input.contains('<') || input.contains('>')) {
      return true;
    }

    // Check for XSS patterns
    for (final pattern in _xssPatterns) {
      if (lowerInput.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Sanitize input to prevent SQL injection
  static String sanitizeForSql(String input) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // Remove dangerous characters
    sanitized = sanitized.replaceAll("'", '');
    sanitized = sanitized.replaceAll('"', '');
    sanitized = sanitized.replaceAll(';', '');
    sanitized = sanitized.replaceAll('\\', '');
    sanitized = sanitized.replaceAll('--', '');
    sanitized = sanitized.replaceAll('/*', '');
    sanitized = sanitized.replaceAll('*/', '');
    sanitized = sanitized.replaceAll('\x00', '');
    sanitized = sanitized.trim();

    return sanitized;
  }

  /// Sanitize input to prevent XSS
  static String sanitizeForXss(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;')
        .trim();
  }

  /// Sanitize general text input (names, descriptions, etc.)
  static String sanitizeText(String input, {int maxLength = 500}) {
    if (input.isEmpty) return input;

    String sanitized = input
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  /// Sanitize for use in search queries
  static String sanitizeSearchQuery(String query) {
    if (query.isEmpty) return query;

    String result = query
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (result.length > 100) {
      result = result.substring(0, 100);
    }

    return result;
  }

  /// Validate email format
  static ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult.invalid('Email is required');
    }

    final sanitized = email.trim().toLowerCase();

    if (sanitized.length > 254) {
      return ValidationResult.invalid('Email is too long');
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(sanitized)) {
      return ValidationResult.invalid('Invalid email format');
    }

    if (containsSqlInjection(sanitized) || containsXss(sanitized)) {
      return ValidationResult.invalid('Email contains invalid characters');
    }

    return ValidationResult.valid(sanitized);
  }

  /// Validate Indian phone number
  static ValidationResult validatePhone(String phone,
      {bool allowEmpty = false}) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.isEmpty) {
      if (allowEmpty) return ValidationResult.valid('');
      return ValidationResult.invalid('Phone number is required');
    }

    String normalized = cleaned;
    if (normalized.startsWith('+91')) {
      normalized = normalized.substring(3);
    } else if (normalized.startsWith('91') && normalized.length > 10) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }

    final phoneRegex = RegExp(r'^[6-9]\d{9}$');

    if (!phoneRegex.hasMatch(normalized)) {
      return ValidationResult.invalid(
        'Invalid phone number. Enter 10-digit mobile number starting with 6-9',
      );
    }

    return ValidationResult.valid(normalized);
  }

  /// Validate and sanitize name
  static ValidationResult validateName(
    String name, {
    int minLength = 2,
    int maxLength = 100,
    bool allowEmpty = false,
  }) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      if (allowEmpty) return ValidationResult.valid('');
      return ValidationResult.invalid('Name is required');
    }

    if (trimmed.length < minLength) {
      return ValidationResult.invalid(
          'Name must be at least $minLength characters');
    }

    if (trimmed.length > maxLength) {
      return ValidationResult.invalid(
          'Name must be less than $maxLength characters');
    }

    // Only allow letters, spaces, hyphens, apostrophes, and periods
    final nameRegex = RegExp(r"^[a-zA-Z\s\-'.]+$");

    if (!nameRegex.hasMatch(trimmed)) {
      return ValidationResult.invalid('Name contains invalid characters');
    }

    if (containsSqlInjection(trimmed) || containsXss(trimmed)) {
      return ValidationResult.invalid('Name contains invalid characters');
    }

    final sanitized = _capitalizeName(trimmed);

    return ValidationResult.valid(sanitized);
  }

  /// Capitalize name properly
  static String _capitalizeName(String name) {
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Check password strength
  static PasswordStrength checkPasswordStrength(String password) {
    int score = 0;

    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 3) return PasswordStrength.fair;
    if (score <= 4) return PasswordStrength.good;
    return PasswordStrength.strong;
  }

  /// Validate password with configurable requirements
  static ValidationResult validatePassword(
    String password, {
    int minLength = 8,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireNumber = true,
    bool requireSpecial = true,
  }) {
    if (password.isEmpty) {
      return ValidationResult.invalid('Password is required');
    }

    if (password.length < minLength) {
      return ValidationResult.invalid(
        'Password must be at least $minLength characters',
      );
    }

    if (password.length > 128) {
      return ValidationResult.invalid('Password is too long');
    }

    List<String> missing = [];

    if (requireUppercase && !RegExp(r'[A-Z]').hasMatch(password)) {
      missing.add('uppercase letter');
    }

    if (requireLowercase && !RegExp(r'[a-z]').hasMatch(password)) {
      missing.add('lowercase letter');
    }

    if (requireNumber && !RegExp(r'[0-9]').hasMatch(password)) {
      missing.add('number');
    }

    if (requireSpecial &&
        !RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      missing.add('special character');
    }

    if (missing.isNotEmpty) {
      return ValidationResult.invalid(
        'Password must contain: ${missing.join(', ')}',
      );
    }

    const commonPasswords = [
      'password',
      'password123',
      '123456',
      '12345678',
      'qwerty',
      'admin',
      'administrator',
      'letmein',
      'welcome',
      'monkey',
    ];

    if (commonPasswords.contains(password.toLowerCase())) {
      return ValidationResult.invalid('Password is too common');
    }

    return ValidationResult.valid(password);
  }

  /// Validate student ID format (e.g., BT25CSE001)
  static ValidationResult validateStudentId(String id) {
    if (id.isEmpty) {
      return ValidationResult.invalid('Student ID is required');
    }

    final studentIdRegex = RegExp(r'^BT\d{2}[A-Z]{2,4}\d{3}$');

    if (!studentIdRegex.hasMatch(id.toUpperCase())) {
      return ValidationResult.invalid(
        'Invalid student ID format. Expected: BT25CSE001',
      );
    }

    return ValidationResult.valid(id.toUpperCase());
  }

  /// Validate teacher ID format (e.g., teacher1, teacher10)
  static ValidationResult validateTeacherId(String id) {
    if (id.isEmpty) {
      return ValidationResult.invalid('Teacher ID is required');
    }

    final teacherIdRegex = RegExp(r'^teacher\d+$', caseSensitive: false);

    if (!teacherIdRegex.hasMatch(id.toLowerCase())) {
      return ValidationResult.invalid(
        'Invalid teacher ID format. Expected: teacher1, teacher10, etc.',
      );
    }

    return ValidationResult.valid(id.toLowerCase());
  }

  /// Validate employee ID format (e.g., EMP001)
  static ValidationResult validateEmployeeId(String id) {
    if (id.isEmpty) {
      return ValidationResult.invalid('Employee ID is required');
    }

    final empIdRegex = RegExp(r'^EMP\d{3,}$');

    if (!empIdRegex.hasMatch(id.toUpperCase())) {
      return ValidationResult.invalid(
        'Invalid employee ID format. Expected: EMP001',
      );
    }

    return ValidationResult.valid(id.toUpperCase());
  }

  /// Validate Aadhaar number (12 digits)
  static ValidationResult validateAadhaar(String aadhaar,
      {bool allowEmpty = true}) {
    final cleaned = aadhaar.replaceAll(RegExp(r'\s'), '');

    if (cleaned.isEmpty) {
      if (allowEmpty) return ValidationResult.valid('');
      return ValidationResult.invalid('Aadhaar number is required');
    }

    if (!RegExp(r'^\d{12}$').hasMatch(cleaned)) {
      return ValidationResult.invalid('Aadhaar must be 12 digits');
    }

    final part1 = cleaned.substring(0, 4);
    final part2 = cleaned.substring(4, 8);
    final part3 = cleaned.substring(8, 12);
    final formatted = '$part1 $part2 $part3';

    return ValidationResult.valid(formatted);
  }

  /// Validate PAN number
  static ValidationResult validatePan(String pan, {bool allowEmpty = true}) {
    final cleaned = pan.replaceAll(RegExp(r'\s'), '').toUpperCase();

    if (cleaned.isEmpty) {
      if (allowEmpty) return ValidationResult.valid('');
      return ValidationResult.invalid('PAN number is required');
    }

    if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(cleaned)) {
      return ValidationResult.invalid(
          'Invalid PAN format. Expected: ABCDE1234F');
    }

    return ValidationResult.valid(cleaned);
  }
}
