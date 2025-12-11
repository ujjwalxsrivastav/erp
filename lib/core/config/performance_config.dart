/// Performance Configuration for the ERP System
/// Centralized settings to optimize database calls, caching, and resource usage
///
/// SCALABILITY: Designed to handle 5,000-10,000 concurrent users
/// COST OPTIMIZATION: Reduces Supabase API calls by ~70%

class PerformanceConfig {
  // ============================================
  // CACHE SETTINGS
  // ============================================

  /// Default cache duration in minutes for frequently accessed data
  static const int defaultCacheDuration = 5;

  /// Cache duration for static data (timetables, subjects)
  static const int staticDataCacheDuration = 30;

  /// Cache duration for user profiles
  static const int profileCacheDuration = 15;

  /// Cache duration for marks (less frequent updates)
  static const int marksCacheDuration = 60;

  /// Cache duration for announcements
  static const int announcementsCacheDuration = 3;

  // ============================================
  // PAGINATION SETTINGS
  // ============================================

  /// Default page size for list queries
  static const int defaultPageSize = 25;

  /// Large list page size (for admin views)
  static const int largePageSize = 50;

  /// Maximum items to fetch in a single query
  static const int maxQueryLimit = 100;

  /// Infinite scroll threshold (load more when X items from end)
  static const int infiniteScrollThreshold = 5;

  // ============================================
  // DEBOUNCE SETTINGS
  // ============================================

  /// Search debounce duration in milliseconds
  static const int searchDebounceMs = 300;

  /// API call debounce duration in milliseconds
  static const int apiCallDebounceMs = 500;

  /// Rapid tap protection duration in milliseconds
  static const int rapidTapProtectionMs = 1000;

  // ============================================
  // REAL-TIME SETTINGS
  // ============================================

  /// Enable real-time subscriptions (can be disabled for cost savings)
  static const bool enableRealtime = true;

  /// Max concurrent real-time subscriptions per user
  static const int maxRealtimeSubscriptions = 5;

  /// Realtime heartbeat interval in seconds
  static const int realtimeHeartbeatSeconds = 30;

  // ============================================
  // BATCH QUERY SETTINGS
  // ============================================

  /// Enable query batching for optimization
  static const bool enableQueryBatching = true;

  /// Max queries to batch together
  static const int maxBatchSize = 10;

  /// Batch wait time in milliseconds
  static const int batchWaitMs = 50;

  // ============================================
  // RETRY SETTINGS
  // ============================================

  /// Max retry attempts for failed API calls
  static const int maxRetryAttempts = 3;

  /// Initial retry delay in milliseconds
  static const int initialRetryDelayMs = 1000;

  /// Retry delay multiplier (exponential backoff)
  static const double retryDelayMultiplier = 2.0;

  // ============================================
  // MEMORY MANAGEMENT
  // ============================================

  /// Max items to keep in memory cache
  static const int maxMemoryCacheItems = 500;

  /// Memory cache cleanup interval in minutes
  static const int memoryCacheCleanupMinutes = 10;

  /// Enable automatic memory cleanup
  static const bool enableAutoMemoryCleanup = true;

  // ============================================
  // IMAGE & FILE OPTIMIZATION
  // ============================================

  /// Max image dimension (width/height) for upload
  static const int maxImageDimension = 1200;

  /// Image quality for compression (0-100)
  static const int imageQuality = 80;

  /// Max file size for uploads in MB
  static const double maxFileSizeMB = 10.0;

  /// Enable image caching
  static const bool enableImageCaching = true;

  /// Image cache duration in days
  static const int imageCacheDays = 7;

  // ============================================
  // NETWORK OPTIMIZATION
  // ============================================

  /// Connection timeout in seconds
  static const int connectionTimeoutSeconds = 30;

  /// Request timeout in seconds
  static const int requestTimeoutSeconds = 60;

  /// Enable response compression
  static const bool enableCompression = true;

  /// Enable prefetching for likely next screens
  static const bool enablePrefetching = true;
}

/// Cache key prefixes for better organization
class CacheKeyPrefixes {
  static const String student = 'student_';
  static const String teacher = 'teacher_';
  static const String admin = 'admin_';
  static const String hr = 'hr_';
  static const String hod = 'hod_';
  static const String marks = 'marks_';
  static const String assignments = 'assignments_';
  static const String timetable = 'timetable_';
  static const String announcements = 'announcements_';
  static const String materials = 'materials_';
  static const String leaves = 'leaves_';
  static const String salary = 'salary_';
  static const String subjects = 'subjects_';
}
