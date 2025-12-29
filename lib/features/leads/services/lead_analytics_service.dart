import 'package:supabase_flutter/supabase_flutter.dart';

/// Lead Analytics Service - Handles reporting and analytics
class LeadAnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // DAILY ANALYTICS
  // ============================================================================

  /// Get daily analytics for a date range
  Future<List<Map<String, dynamic>>> getDailyAnalytics({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 30,
  }) async {
    try {
      var query = _supabase.from('lead_analytics_daily').select();

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('date', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching daily analytics: $e');
      return [];
    }
  }

  /// Get today's analytics
  Future<Map<String, dynamic>?> getTodaysAnalytics() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('lead_analytics_daily')
          .select()
          .eq('date', today)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching today\'s analytics: $e');
      return null;
    }
  }

  // ============================================================================
  // MONTHLY ANALYTICS
  // ============================================================================

  /// Get monthly trends
  Future<List<Map<String, dynamic>>> getMonthlyTrends({int months = 12}) async {
    try {
      final response = await _supabase
          .from('lead_monthly_trends')
          .select()
          .order('month', ascending: false)
          .limit(months);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching monthly trends: $e');
      return [];
    }
  }

  // ============================================================================
  // COURSE ANALYTICS
  // ============================================================================

  /// Get course-wise analytics
  Future<List<Map<String, dynamic>>> getCourseAnalytics() async {
    try {
      final response = await _supabase
          .from('course_lead_analytics')
          .select()
          .order('total_leads', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching course analytics: $e');
      return [];
    }
  }

  // ============================================================================
  // SOURCE ANALYTICS
  // ============================================================================

  /// Get source-wise lead distribution
  Future<List<Map<String, dynamic>>> getSourceAnalytics() async {
    try {
      final response =
          await _supabase.from('leads').select('source, is_converted');

      final leads = response as List;
      final Map<String, Map<String, int>> sourceData = {};

      for (final lead in leads) {
        final source = lead['source'] as String? ?? 'unknown';
        final isConverted = lead['is_converted'] as bool? ?? false;

        sourceData[source] ??= {'total': 0, 'converted': 0};
        sourceData[source]!['total'] = sourceData[source]!['total']! + 1;
        if (isConverted) {
          sourceData[source]!['converted'] =
              sourceData[source]!['converted']! + 1;
        }
      }

      return sourceData.entries.map((entry) {
        final total = entry.value['total']!;
        final converted = entry.value['converted']!;
        return {
          'source': entry.key,
          'total': total,
          'converted': converted,
          'conversion_rate':
              total > 0 ? (converted / total * 100).toStringAsFixed(1) : '0.0',
        };
      }).toList()
        ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    } catch (e) {
      print('Error fetching source analytics: $e');
      return [];
    }
  }

  // ============================================================================
  // CONVERSION FUNNEL
  // ============================================================================

  /// Get conversion funnel data
  Future<List<Map<String, dynamic>>> getConversionFunnel() async {
    try {
      final response = await _supabase.from('leads').select('status');

      final leads = response as List;
      final Map<String, int> statusCounts = {};

      for (final lead in leads) {
        final status = lead['status'] as String? ?? 'new';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      // Define funnel stages in order
      final funnelStages = [
        'new',
        'assigned',
        'contacted',
        'interested',
        'form_sent',
        'form_filled',
        'seat_booked',
        'converted',
      ];

      int total = leads.length;

      return funnelStages.map((stage) {
        final count = statusCounts[stage] ?? 0;
        return {
          'stage': stage,
          'count': count,
          'percentage':
              total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0',
        };
      }).toList();
    } catch (e) {
      print('Error fetching conversion funnel: $e');
      return [];
    }
  }

  // ============================================================================
  // PERFORMANCE COMPARISON
  // ============================================================================

  /// Get week-over-week comparison
  Future<Map<String, dynamic>> getWeeklyComparison() async {
    try {
      final now = DateTime.now();
      final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));

      // This week's leads
      final thisWeekResponse = await _supabase
          .from('leads')
          .select('is_converted')
          .gte('created_at', startOfThisWeek.toIso8601String());

      final thisWeekLeads = thisWeekResponse as List;
      final thisWeekTotal = thisWeekLeads.length;
      final thisWeekConverted =
          thisWeekLeads.where((l) => l['is_converted'] == true).length;

      // Last week's leads
      final lastWeekResponse = await _supabase
          .from('leads')
          .select('is_converted')
          .gte('created_at', startOfLastWeek.toIso8601String())
          .lt('created_at', startOfThisWeek.toIso8601String());

      final lastWeekLeads = lastWeekResponse as List;
      final lastWeekTotal = lastWeekLeads.length;
      final lastWeekConverted =
          lastWeekLeads.where((l) => l['is_converted'] == true).length;

      // Calculate growth
      final leadsGrowth = lastWeekTotal > 0
          ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal * 100)
          : (thisWeekTotal > 0 ? 100 : 0);

      final conversionsGrowth = lastWeekConverted > 0
          ? ((thisWeekConverted - lastWeekConverted) / lastWeekConverted * 100)
          : (thisWeekConverted > 0 ? 100 : 0);

      return {
        'this_week': {
          'leads': thisWeekTotal,
          'conversions': thisWeekConverted,
          'conversion_rate': thisWeekTotal > 0
              ? (thisWeekConverted / thisWeekTotal * 100).toStringAsFixed(1)
              : '0.0',
        },
        'last_week': {
          'leads': lastWeekTotal,
          'conversions': lastWeekConverted,
          'conversion_rate': lastWeekTotal > 0
              ? (lastWeekConverted / lastWeekTotal * 100).toStringAsFixed(1)
              : '0.0',
        },
        'growth': {
          'leads': leadsGrowth.toStringAsFixed(1),
          'conversions': conversionsGrowth.toStringAsFixed(1),
        },
      };
    } catch (e) {
      print('Error fetching weekly comparison: $e');
      return {};
    }
  }

  // ============================================================================
  // SUMMARY DASHBOARD DATA
  // ============================================================================

  /// Get complete dashboard summary
  Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      // Get overall stats
      final statsResponse = await _supabase.rpc('get_lead_stats');
      final stats = statsResponse is List && statsResponse.isNotEmpty
          ? statsResponse[0]
          : {};

      // Get today's analytics
      final todayAnalytics = await getTodaysAnalytics();

      // Get weekly comparison
      final weeklyComparison = await getWeeklyComparison();

      return {
        'overall': stats,
        'today': todayAnalytics ?? {},
        'weekly': weeklyComparison,
      };
    } catch (e) {
      print('Error fetching dashboard summary: $e');
      return {};
    }
  }

  // ============================================================================
  // LOCATION ANALYTICS
  // ============================================================================

  /// Get state-wise lead distribution
  Future<List<Map<String, dynamic>>> getStateAnalytics() async {
    try {
      final response =
          await _supabase.from('leads').select('state, is_converted');

      final leads = response as List;
      final Map<String, Map<String, int>> stateData = {};

      for (final lead in leads) {
        final state = lead['state'] as String? ?? 'Not Specified';
        final isConverted = lead['is_converted'] as bool? ?? false;

        stateData[state] ??= {'total': 0, 'converted': 0};
        stateData[state]!['total'] = stateData[state]!['total']! + 1;
        if (isConverted) {
          stateData[state]!['converted'] = stateData[state]!['converted']! + 1;
        }
      }

      return stateData.entries.map((entry) {
        final total = entry.value['total']!;
        final converted = entry.value['converted']!;
        return {
          'state': entry.key,
          'total': total,
          'converted': converted,
          'conversion_rate':
              total > 0 ? (converted / total * 100).toStringAsFixed(1) : '0.0',
        };
      }).toList()
        ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    } catch (e) {
      print('Error fetching state analytics: $e');
      return [];
    }
  }

  // ============================================================================
  // TIME-BASED ANALYTICS
  // ============================================================================

  /// Get hourly lead distribution (best time for leads)
  Future<List<Map<String, dynamic>>> getHourlyDistribution() async {
    try {
      final response = await _supabase.from('leads').select('created_at');

      final leads = response as List;
      final Map<int, int> hourCounts = {};

      for (final lead in leads) {
        final createdAt = DateTime.parse(lead['created_at'] as String);
        final hour = createdAt.hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }

      return List.generate(
          24,
          (hour) => {
                'hour': hour,
                'label': '${hour.toString().padLeft(2, '0')}:00',
                'count': hourCounts[hour] ?? 0,
              });
    } catch (e) {
      print('Error fetching hourly distribution: $e');
      return [];
    }
  }

  /// Get day-of-week distribution
  Future<List<Map<String, dynamic>>> getDayOfWeekDistribution() async {
    try {
      final response = await _supabase.from('leads').select('created_at');

      final leads = response as List;
      final Map<int, int> dayCounts = {};
      final dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];

      for (final lead in leads) {
        final createdAt = DateTime.parse(lead['created_at'] as String);
        final dayOfWeek = createdAt.weekday; // 1 = Monday, 7 = Sunday
        dayCounts[dayOfWeek] = (dayCounts[dayOfWeek] ?? 0) + 1;
      }

      return List.generate(7, (index) {
        final day = index + 1;
        return {
          'day': day,
          'name': dayNames[index],
          'short_name': dayNames[index].substring(0, 3),
          'count': dayCounts[day] ?? 0,
        };
      });
    } catch (e) {
      print('Error fetching day distribution: $e');
      return [];
    }
  }
}
