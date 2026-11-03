import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/counsellor_model.dart';

/// Counsellor Service - Handles counsellor management and performance tracking
class CounsellorService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // COUNSELLOR CRUD
  // ============================================================================

  /// Get all active counsellors
  Future<List<Counsellor>> getCounsellors({bool activeOnly = true}) async {
    try {
      var query = _supabase.from('counsellor_details').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('name', ascending: true);

      return (response as List)
          .map((json) => Counsellor.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching counsellors: $e');
      return [];
    }
  }

  /// Get counsellor by ID
  Future<Counsellor?> getCounsellorById(String id) async {
    try {
      final response = await _supabase
          .from('counsellor_details')
          .select()
          .eq('id', id)
          .single();

      return Counsellor.fromJson(response);
    } catch (e) {
      print('Error fetching counsellor: $e');
      return null;
    }
  }

  /// Get counsellor by user ID (username)
  Future<Counsellor?> getCounsellorByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('counsellor_details')
          .select()
          .eq('user_id', userId)
          .single();

      return Counsellor.fromJson(response);
    } catch (e) {
      print('Error fetching counsellor by user ID: $e');
      return null;
    }
  }

  /// Create a new counsellor
  Future<Counsellor?> createCounsellor({
    required String userId,
    required String name,
    String? email,
    String? phone,
    String? specialization,
    int maxActiveLeads = 50,
  }) async {
    try {
      final response = await _supabase
          .from('counsellor_details')
          .insert({
            'user_id': userId,
            'name': name,
            'email': email,
            'phone': phone,
            'specialization': specialization,
            'max_active_leads': maxActiveLeads,
            'is_active': true,
          })
          .select()
          .single();

      return Counsellor.fromJson(response);
    } catch (e) {
      print('Error creating counsellor: $e');
      return null;
    }
  }

  /// Update counsellor details
  Future<bool> updateCounsellor(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('counsellor_details').update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);
      return true;
    } catch (e) {
      print('Error updating counsellor: $e');
      return false;
    }
  }

  /// Toggle counsellor active status
  Future<bool> toggleCounsellorStatus(String id, bool isActive) async {
    return updateCounsellor(id, {'is_active': isActive});
  }

  // ============================================================================
  // PERFORMANCE ANALYTICS
  // ============================================================================

  /// Get all counsellors with performance data
  Future<List<CounsellorPerformance>> getCounsellorPerformance() async {
    try {
      final response = await _supabase
          .from('counsellor_performance')
          .select()
          .order('conversions', ascending: false);

      return (response as List)
          .map((json) => CounsellorPerformance.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching counsellor performance: $e');
      return [];
    }
  }

  /// Get performance for a specific counsellor
  Future<CounsellorPerformance?> getCounsellorPerformanceById(
      String counsellorId) async {
    try {
      final response = await _supabase
          .from('counsellor_performance')
          .select()
          .eq('counsellor_id', counsellorId)
          .single();

      return CounsellorPerformance.fromJson(response);
    } catch (e) {
      print('Error fetching counsellor performance: $e');
      return null;
    }
  }

  /// Get counsellor rankings
  Future<List<Map<String, dynamic>>> getCounsellorRankings() async {
    try {
      final performance = await getCounsellorPerformance();

      return performance.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final counsellor = entry.value;
        return {
          'rank': rank,
          'counsellor_id': counsellor.counsellorId,
          'name': counsellor.counsellorName,
          'conversions': counsellor.conversions,
          'conversion_rate': counsellor.conversionRate,
          'active_pipeline': counsellor.activePipeline,
          'badge': rank == 1
              ? '🏆'
              : rank == 2
                  ? '🥈'
                  : rank == 3
                      ? '🥉'
                      : '',
        };
      }).toList();
    } catch (e) {
      print('Error getting rankings: $e');
      return [];
    }
  }

  // ============================================================================
  // SMART ASSIGNMENT SUGGESTIONS
  // ============================================================================

  /// Get suggested counsellor for a lead based on various factors
  Future<Counsellor?> getSuggestedCounsellor({
    String? preferredCourse,
    bool considerWorkload = true,
    bool considerPerformance = true,
  }) async {
    try {
      final performance = await getCounsellorPerformance();

      if (performance.isEmpty) return null;

      // Filter only available counsellors
      var available = performance.where((p) => p.isAvailable).toList();

      if (available.isEmpty) {
        // All counsellors are at capacity
        return null;
      }

      // Score each counsellor
      Map<String, double> scores = {};

      for (final p in available) {
        double score = 0;

        // Course specialization match (highest weight)
        if (preferredCourse != null &&
            p.specialization != null &&
            (p.specialization!
                    .toLowerCase()
                    .contains(preferredCourse.toLowerCase()) ||
                p.specialization!.toLowerCase() == 'all courses')) {
          score += 30;
        }

        // Conversion rate (high performers get more)
        if (considerPerformance) {
          score += p.conversionRate * 0.5; // Max ~20 points for 40% rate
        }

        // Workload (less loaded counsellors get more)
        if (considerWorkload) {
          score += (100 - p.workloadPercentage) * 0.2; // Max 20 points
        }

        // Available capacity bonus
        score += p.availableCapacity * 0.1;

        scores[p.counsellorId] = score;
      }

      // Sort by score and get best match
      available.sort((a, b) =>
          (scores[b.counsellorId] ?? 0).compareTo(scores[a.counsellorId] ?? 0));

      // Return the top counsellor
      return await getCounsellorById(available.first.counsellorId);
    } catch (e) {
      print('Error getting suggested counsellor: $e');
      return null;
    }
  }

  /// Get counsellors with availability
  Future<List<Map<String, dynamic>>> getCounsellorsWithAvailability() async {
    try {
      final performance = await getCounsellorPerformance();

      return performance
          .map((p) => {
                'id': p.counsellorId,
                'user_id': p.userId,
                'name': p.counsellorName,
                'specialization': p.specialization,
                'is_available': p.isAvailable,
                'active_leads': p.activePipeline,
                'max_leads': p.maxActiveLeads,
                'available_capacity': p.availableCapacity,
                'workload_percentage': p.workloadPercentage,
                'conversion_rate': p.conversionRate,
              })
          .toList();
    } catch (e) {
      print('Error getting availability: $e');
      return [];
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get team statistics
  Future<Map<String, dynamic>> getTeamStats() async {
    try {
      final performance = await getCounsellorPerformance();

      if (performance.isEmpty) {
        return {
          'total_counsellors': 0,
          'active_counsellors': 0,
          'total_leads': 0,
          'total_conversions': 0,
          'avg_conversion_rate': 0,
          'total_pipeline': 0,
        };
      }

      int totalLeads = 0;
      int totalConversions = 0;
      int totalPipeline = 0;
      int activeCounsellors = 0;

      for (final p in performance) {
        totalLeads += p.totalAssigned;
        totalConversions += p.conversions;
        totalPipeline += p.activePipeline;
        if (p.isActive) activeCounsellors++;
      }

      double avgConversionRate =
          totalLeads > 0 ? (totalConversions / totalLeads) * 100 : 0;

      return {
        'total_counsellors': performance.length,
        'active_counsellors': activeCounsellors,
        'total_leads': totalLeads,
        'total_conversions': totalConversions,
        'avg_conversion_rate': avgConversionRate.toStringAsFixed(1),
        'total_pipeline': totalPipeline,
      };
    } catch (e) {
      print('Error getting team stats: $e');
      return {};
    }
  }

  /// Get today's team activity
  Future<Map<String, int>> getTodaysActivity() async {
    try {
      final performance = await getCounsellorPerformance();

      int assignedToday = 0;
      int convertedToday = 0;

      for (final p in performance) {
        assignedToday += p.assignedToday;
        convertedToday += p.convertedToday;
      }

      return {
        'assigned_today': assignedToday,
        'converted_today': convertedToday,
      };
    } catch (e) {
      print('Error getting today\'s activity: $e');
      return {'assigned_today': 0, 'converted_today': 0};
    }
  }

  // ============================================================================
  // REGION-BASED ASSIGNMENT
  // ============================================================================

  /// Get counsellor assigned to a specific state/region
  Future<Counsellor?> getCounsellorByRegion(String state) async {
    try {
      final response = await _supabase.rpc('get_counsellor_by_state', params: {
        'p_state': state,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final counsellorId = response[0]['counsellor_id'];
        if (counsellorId != null) {
          return await getCounsellorById(counsellorId);
        }
      }
      return null;
    } catch (e) {
      print('Error getting counsellor by region: $e');
      return null;
    }
  }

  /// Get regions assigned to a counsellor
  Future<List<Map<String, dynamic>>> getCounsellorRegions(
      String counsellorId) async {
    try {
      final response = await _supabase
          .from('counsellor_regions')
          .select()
          .eq('counsellor_id', counsellorId)
          .order('priority', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching counsellor regions: $e');
      return [];
    }
  }

  /// Get all region mappings
  Future<List<Map<String, dynamic>>> getAllRegionMappings() async {
    try {
      final response = await _supabase
          .from('counsellor_regions')
          .select('*, counsellor_details(name, user_id)')
          .order('priority', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching region mappings: $e');
      return [];
    }
  }

  /// Update region mapping for a counsellor
  Future<bool> updateCounsellorRegion({
    required String counsellorId,
    required String regionName,
    required List<String> states,
    bool isDefault = false,
    int priority = 1,
  }) async {
    try {
      // Upsert - update if exists, insert if not
      await _supabase.from('counsellor_regions').upsert({
        'counsellor_id': counsellorId,
        'region_name': regionName,
        'states': states,
        'is_default': isDefault,
        'priority': priority,
      });
      return true;
    } catch (e) {
      print('Error updating region: $e');
      return false;
    }
  }
}
