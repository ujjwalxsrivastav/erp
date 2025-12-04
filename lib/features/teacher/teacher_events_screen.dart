import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/events_service.dart';

class TeacherEventsScreen extends StatefulWidget {
  const TeacherEventsScreen({super.key});

  @override
  State<TeacherEventsScreen> createState() => _TeacherEventsScreenState();
}

class _TeacherEventsScreenState extends State<TeacherEventsScreen> {
  final _eventsService = EventsService();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await _eventsService.getTeacherEvents();
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF1E3A8A),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E3A8A),
                      Color(0xFF3B82F6),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    const SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 40,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Campus Events',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Stay updated with upcoming events',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  )
                : _events.isEmpty
                    ? SliverFillRemaining(
                        child: _buildEmptyState(),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final event = _events[index];
                            return _buildEventCard(event);
                          },
                          childCount: _events.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Upcoming Events',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new events',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventType = event['event_type'] as String;
    final gradient = _getEventGradient(eventType);
    final icon = _getEventIcon(eventType);

    final eventDate = DateTime.parse(event['event_date']);
    final formattedDate = DateFormat('MMM dd, yyyy').format(eventDate);
    final startTime = event['start_time'] ?? '';
    final endTime = event['end_time'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showEventDetails(event),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            eventType.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.white.withOpacity(0.9), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (startTime.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.access_time,
                          color: Colors.white.withOpacity(0.9), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$startTime - $endTime',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (event['location'] != null &&
                    event['location'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Colors.white.withOpacity(0.9), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event['location'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (event['description'] != null &&
                    event['description'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    event['description'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getEventGradient(event['event_type'])
                            .colors
                            .first
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event['event_type'].toString().toUpperCase(),
                        style: TextStyle(
                          color: _getEventGradient(event['event_type'])
                              .colors
                              .first,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Date',
                      DateFormat('EEEE, MMMM dd, yyyy')
                          .format(DateTime.parse(event['event_date'])),
                    ),
                    if (event['start_time'] != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.access_time,
                        'Time',
                        '${event['start_time']} - ${event['end_time']}',
                      ),
                    ],
                    if (event['location'] != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.location_on,
                        'Location',
                        event['location'],
                      ),
                    ],
                    if (event['organizer'] != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.person,
                        'Organizer',
                        event['organizer'],
                      ),
                    ],
                    if (event['description'] != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  LinearGradient _getEventGradient(String eventType) {
    switch (eventType) {
      case 'academic':
        return const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        );
      case 'cultural':
        return const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
        );
      case 'sports':
        return const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
        );
      case 'workshop':
        return const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        );
      case 'seminar':
        return const LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
        );
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'academic':
        return Icons.school;
      case 'cultural':
        return Icons.theater_comedy;
      case 'sports':
        return Icons.sports_basketball;
      case 'workshop':
        return Icons.build;
      case 'seminar':
        return Icons.mic;
      default:
        return Icons.event;
    }
  }
}
