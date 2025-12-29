import 'package:supabase_flutter/supabase_flutter.dart';

class EventsService {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get all upcoming events (event_date >= today)
  Future<List<Map<String, dynamic>>> getUpcomingEvents() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('events')
          .select()
          .gte('event_date', today)
          .order('event_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching upcoming events: $e');
      return [];
    }
  }

  /// Get all past events (event_date < today)
  Future<List<Map<String, dynamic>>> getPastEvents() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('events')
          .select()
          .lt('event_date', today)
          .order('event_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching past events: $e');
      return [];
    }
  }

  /// Get events for students (target_audience contains 'students' or 'all')
  Future<List<Map<String, dynamic>>> getStudentEvents() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      print('📅 Fetching student events for date >= $today');

      final response = await _supabase
          .from('events')
          .select()
          .gte('event_date', today)
          .order('event_date', ascending: true);

      print('📊 Raw events fetched: ${response.length}');

      // Filter events that include students or all
      final filtered = (response as List).where((event) {
        final audienceRaw = event['target_audience'];

        // Handle different formats: array, string, or null
        if (audienceRaw == null) {
          print('⚠️ Event "${event['title']}" has no target_audience');
          return true; // Show all events without target_audience
        }

        if (audienceRaw is List) {
          // PostgreSQL array format
          return audienceRaw.contains('students') ||
              audienceRaw.contains('all');
        } else if (audienceRaw is String) {
          // String format (comma-separated or single value)
          final lower = audienceRaw.toLowerCase();
          return lower.contains('students') || lower.contains('all');
        }

        print(
            '⚠️ Unknown audience format for "${event['title']}": $audienceRaw');
        return true; // Show event if format is unknown
      }).toList();

      print('✅ Filtered events for students: ${filtered.length}');
      return List<Map<String, dynamic>>.from(filtered);
    } catch (e) {
      print('❌ Error fetching student events: $e');
      return [];
    }
  }

  /// Get events for teachers (target_audience contains 'teachers' or 'all')
  Future<List<Map<String, dynamic>>> getTeacherEvents() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('events')
          .select()
          .gte('event_date', today)
          .order('event_date', ascending: true);

      // Filter events that include teachers or all
      final filtered = (response as List).where((event) {
        final audience = event['target_audience'] as List?;
        return audience?.contains('teachers') == true ||
            audience?.contains('all') == true;
      }).toList();

      return List<Map<String, dynamic>>.from(filtered);
    } catch (e) {
      print('Error fetching teacher events: $e');
      return [];
    }
  }

  /// Create a new event
  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required String eventType,
    required DateTime eventDate,
    required String startTime,
    required String endTime,
    required String location,
    required String organizer,
    required List<String> targetAudience,
    required String createdBy,
  }) async {
    try {
      final response = await _supabase
          .from('events')
          .insert({
            'title': title,
            'description': description,
            'event_type': eventType,
            'event_date': eventDate.toIso8601String().split('T')[0],
            'start_time': startTime,
            'end_time': endTime,
            'location': location,
            'organizer': organizer,
            'target_audience': targetAudience,
            'created_by': createdBy,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Event created successfully',
        'data': response,
      };
    } catch (e) {
      print('Error creating event: $e');
      return {
        'success': false,
        'message': 'Failed to create event: $e',
        'data': null,
      };
    }
  }

  /// Update an existing event
  Future<Map<String, dynamic>> updateEvent({
    required String eventId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _supabase
          .from('events')
          .update(updates)
          .eq('id', eventId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Event updated successfully',
        'data': response,
      };
    } catch (e) {
      print('Error updating event: $e');
      return {
        'success': false,
        'message': 'Failed to update event: $e',
        'data': null,
      };
    }
  }

  /// Delete an event
  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    try {
      await _supabase.from('events').delete().eq('id', eventId);

      return {
        'success': true,
        'message': 'Event deleted successfully',
      };
    } catch (e) {
      print('Error deleting event: $e');
      return {
        'success': false,
        'message': 'Failed to delete event: $e',
      };
    }
  }

  /// Get event by ID
  Future<Map<String, dynamic>?> getEventById(String eventId) async {
    try {
      final response =
          await _supabase.from('events').select().eq('id', eventId).single();

      return response;
    } catch (e) {
      print('Error fetching event: $e');
      return null;
    }
  }
}
