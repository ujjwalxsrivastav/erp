/// File Upload Validation Utility
///
/// Security Features:
/// 1. MIME type validation (magic bytes)
/// 2. File extension whitelist
/// 3. File size limits
/// 4. Filename sanitization
/// 5. Malicious content detection

import 'dart:io';
import 'dart:typed_data';

/// Result of file validation
class FileValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? sanitizedFileName;
  final String? detectedMimeType;

  const FileValidationResult({
    required this.isValid,
    this.errorMessage,
    this.sanitizedFileName,
    this.detectedMimeType,
  });

  factory FileValidationResult.valid({
    required String sanitizedFileName,
    required String mimeType,
  }) {
    return FileValidationResult(
      isValid: true,
      sanitizedFileName: sanitizedFileName,
      detectedMimeType: mimeType,
    );
  }

  factory FileValidationResult.invalid(String error) {
    return FileValidationResult(
      isValid: false,
      errorMessage: error,
    );
  }
}

/// File type categories for different upload contexts
enum FileCategory {
  image,
  document,
  all,
}

/// File validator for secure file uploads
class FileValidator {
  // Maximum file sizes (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5 MB
  static const int maxDocumentSize = 10 * 1024 * 1024; // 10 MB
  static const int maxAssignmentSize = 25 * 1024 * 1024; // 25 MB

  // Allowed extensions by category
  static const Map<FileCategory, List<String>> _allowedExtensions = {
    FileCategory.image: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
    FileCategory.document: [
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt'
    ],
    FileCategory.all: [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt'
    ],
  };

  // Magic bytes (file signatures) for MIME type detection
  static const Map<String, List<int>> _magicBytes = {
    // Images
    'image/jpeg': [0xFF, 0xD8, 0xFF],
    'image/png': [0x89, 0x50, 0x4E, 0x47],
    'image/gif': [0x47, 0x49, 0x46],
    'image/webp': [0x52, 0x49, 0x46, 0x46], // RIFF header
    // Documents
    'application/pdf': [0x25, 0x50, 0x44, 0x46], // %PDF
    // MS Office (newer .docx, .xlsx, .pptx are ZIP files)
    'application/zip': [0x50, 0x4B, 0x03, 0x04],
    // MS Office (older .doc, .xls, .ppt)
    'application/msoffice': [0xD0, 0xCF, 0x11, 0xE0],
  };

  // Dangerous file patterns to block
  static const List<String> _dangerousExtensions = [
    'exe', 'bat', 'cmd', 'com', 'msi', 'scr', 'pif',
    'vbs', 'js', 'jse', 'wsf', 'wsh', 'ps1', 'psm1',
    'sh', 'bash', 'csh', 'ksh', 'zsh',
    'php', 'php3', 'php4', 'php5', 'phtml',
    'asp', 'aspx', 'cer', 'csr',
    'dll', 'sys', 'drv',
    'app', 'dmg', 'pkg', 'deb', 'rpm',
    'jar', 'class', 'war',
    'html', 'htm', 'xhtml', 'svg', // Can contain scripts
  ];

  // Dangerous content patterns in files
  static const List<String> _dangerousPatterns = [
    '<script',
    '<?php',
    '<%',
    'javascript:',
    'vbscript:',
    'data:text/html',
    'data:application',
  ];

  /// Validate a file for upload
  static Future<FileValidationResult> validate(
    File file, {
    FileCategory category = FileCategory.all,
    int? maxSizeBytes,
  }) async {
    try {
      // 1. Check if file exists
      if (!await file.exists()) {
        return FileValidationResult.invalid('File does not exist');
      }

      // 2. Get file info
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final fileSize = await file.length();

      // 3. Check for dangerous extensions (double extensions like .jpg.exe)
      final allParts = fileName.toLowerCase().split('.');
      for (final part in allParts) {
        if (_dangerousExtensions.contains(part)) {
          return FileValidationResult.invalid(
            'File type not allowed: .$part',
          );
        }
      }

      // 4. Validate extension against category
      final allowedExts = _allowedExtensions[category] ?? [];
      if (!allowedExts.contains(extension)) {
        return FileValidationResult.invalid(
          'File extension not allowed. Allowed: ${allowedExts.join(', ')}',
        );
      }

      // 5. Check file size
      final maxSize = maxSizeBytes ?? _getMaxSize(category);
      if (fileSize > maxSize) {
        final maxMb = maxSize / (1024 * 1024);
        return FileValidationResult.invalid(
          'File too large. Maximum size: ${maxMb.toStringAsFixed(1)} MB',
        );
      }

      // 6. Check file size minimum (empty files)
      if (fileSize < 10) {
        return FileValidationResult.invalid('File appears to be empty');
      }

      // 7. Validate MIME type by magic bytes
      final bytes = await _readFileHeader(file, 16);
      final detectedMime = _detectMimeType(bytes);

      if (detectedMime == null) {
        return FileValidationResult.invalid(
          'Unable to verify file type. File may be corrupted.',
        );
      }

      // 8. Validate MIME type matches extension
      if (!_isMimeExtensionMatch(detectedMime, extension)) {
        return FileValidationResult.invalid(
          'File content does not match extension. Possible file type spoofing.',
        );
      }

      // 9. Check for malicious content (basic check)
      if (category == FileCategory.document && extension == 'txt') {
        final content = await file.readAsString();
        for (final pattern in _dangerousPatterns) {
          if (content.toLowerCase().contains(pattern.toLowerCase())) {
            return FileValidationResult.invalid(
              'File contains potentially dangerous content',
            );
          }
        }
      }

      // 10. Sanitize filename
      final sanitized = _sanitizeFileName(fileName);

      return FileValidationResult.valid(
        sanitizedFileName: sanitized,
        mimeType: detectedMime,
      );
    } catch (e) {
      return FileValidationResult.invalid('Error validating file: $e');
    }
  }

  /// Validate file bytes (for web/memory uploads)
  static FileValidationResult validateBytes(
    Uint8List bytes,
    String originalFileName, {
    FileCategory category = FileCategory.all,
    int? maxSizeBytes,
  }) {
    try {
      final extension = originalFileName.split('.').last.toLowerCase();

      // Check dangerous extensions
      final allParts = originalFileName.toLowerCase().split('.');
      for (final part in allParts) {
        if (_dangerousExtensions.contains(part)) {
          return FileValidationResult.invalid('File type not allowed: .$part');
        }
      }

      // Validate extension
      final allowedExts = _allowedExtensions[category] ?? [];
      if (!allowedExts.contains(extension)) {
        return FileValidationResult.invalid(
          'File extension not allowed. Allowed: ${allowedExts.join(', ')}',
        );
      }

      // Check size
      final maxSize = maxSizeBytes ?? _getMaxSize(category);
      if (bytes.length > maxSize) {
        final maxMb = maxSize / (1024 * 1024);
        return FileValidationResult.invalid(
          'File too large. Maximum size: ${maxMb.toStringAsFixed(1)} MB',
        );
      }

      // Validate MIME type
      final headerBytes = bytes.length > 16 ? bytes.sublist(0, 16) : bytes;
      final detectedMime = _detectMimeType(headerBytes);

      if (detectedMime == null ||
          !_isMimeExtensionMatch(detectedMime, extension)) {
        return FileValidationResult.invalid(
          'File content does not match extension',
        );
      }

      return FileValidationResult.valid(
        sanitizedFileName: _sanitizeFileName(originalFileName),
        mimeType: detectedMime,
      );
    } catch (e) {
      return FileValidationResult.invalid('Error validating file: $e');
    }
  }

  /// Read file header bytes
  static Future<List<int>> _readFileHeader(File file, int length) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final bytes = await raf.read(length);
      return bytes;
    } finally {
      await raf.close();
    }
  }

  /// Detect MIME type from magic bytes
  static String? _detectMimeType(List<int> bytes) {
    if (bytes.isEmpty) return null;

    for (final entry in _magicBytes.entries) {
      final signature = entry.value;
      if (bytes.length >= signature.length) {
        bool matches = true;
        for (int i = 0; i < signature.length; i++) {
          if (bytes[i] != signature[i]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          return entry.key;
        }
      }
    }

    // Check for text file (all printable ASCII)
    bool isText = bytes.every(
        (b) => b >= 0x20 && b <= 0x7E || b == 0x0A || b == 0x0D || b == 0x09);
    if (isText) {
      return 'text/plain';
    }

    return null;
  }

  /// Check if MIME type matches file extension
  static bool _isMimeExtensionMatch(String mimeType, String extension) {
    const mimeToExt = {
      'image/jpeg': ['jpg', 'jpeg'],
      'image/png': ['png'],
      'image/gif': ['gif'],
      'image/webp': ['webp'],
      'application/pdf': ['pdf'],
      'application/zip': ['docx', 'xlsx', 'pptx', 'zip'],
      'application/msoffice': ['doc', 'xls', 'ppt'],
      'text/plain': ['txt'],
    };

    final allowedExts = mimeToExt[mimeType];
    if (allowedExts == null) return false;
    return allowedExts.contains(extension.toLowerCase());
  }

  /// Get maximum file size for category
  static int _getMaxSize(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return maxImageSize;
      case FileCategory.document:
        return maxDocumentSize;
      case FileCategory.all:
        return maxAssignmentSize;
    }
  }

  /// Sanitize filename to prevent path traversal and special characters
  static String _sanitizeFileName(String fileName) {
    // Extract base name and extension
    final parts = fileName.split('.');
    final extension = parts.length > 1 ? parts.last.toLowerCase() : '';
    final baseName = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('.')
        : fileName;

    // Remove path traversal attempts
    String sanitized = baseName
        .replaceAll(RegExp(r'\.\.'), '')
        .replaceAll(RegExp(r'[/\\]'), '')
        .replaceAll(
            RegExp(r'[\x00-\x1F\x7F]'), ''); // Remove control characters

    // Replace spaces and special characters
    sanitized = sanitized
        .replaceAll(RegExp(r'[<>:"|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_'); // Collapse multiple underscores

    // Limit length
    if (sanitized.length > 50) {
      sanitized = sanitized.substring(0, 50);
    }

    // Ensure not empty
    if (sanitized.isEmpty) {
      sanitized = 'file_${DateTime.now().millisecondsSinceEpoch}';
    }

    return extension.isNotEmpty ? '$sanitized.$extension' : sanitized;
  }

  /// Generate a safe unique filename
  static String generateSafeFileName(String prefix, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedPrefix = _sanitizeFileName(prefix).replaceAll('.', '_');
    final sanitizedExt =
        extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${sanitizedPrefix}_$timestamp.$sanitizedExt';
  }
}
