import 'package:flutter/material.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  final List<Map<String, dynamic>> _routes = [
    {
      'route': 'Route A - North Sector',
      'bus': 'HR-01-2345',
      'driver': 'Ramesh Kumar',
      'phone': '9876543210',
      'stops': ['School', 'Sector 14', 'Sector 18', 'Sector 22', 'Sector 28'],
      'time': '07:30 AM',
      'color': const Color(0xFF3B82F6),
    },
    {
      'route': 'Route B - South Sector',
      'bus': 'HR-02-6789',
      'driver': 'Suresh Sharma',
      'phone': '9876543211',
      'stops': ['School', 'Model Town', 'Civil Lines', 'Railway Station', 'Patel Nagar'],
      'time': '07:45 AM',
      'color': const Color(0xFF10B981),
    },
    {
      'route': 'Route C - East Sector',
      'bus': 'HR-03-1234',
      'driver': 'Mahesh Singh',
      'phone': '9876543212',
      'stops': ['School', 'Sector 7', 'Sector 11', 'Sector 15', 'Village Road'],
      'time': '07:15 AM',
      'color': const Color(0xFF8B5CF6),
    },
  ];

  int _expandedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Transport', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_bus, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Bus', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('Route A - North Sector', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Bus: HR-01-2345 | Pickup: 07:30 AM', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'All Routes',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 12),
            ...List.generate(_routes.length, (index) => _buildRouteCard(index)),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(int index) {
    final route = _routes[index];
    final isExpanded = _expandedIndex == index;
    final color = route['color'] as Color;
    final stops = route['stops'] as List<String>;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? color : Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : index),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.directions_bus, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(route['route'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                        const SizedBox(height: 4),
                        Text(
                          'Bus: ${route['bus']} | Pickup: ${route['time']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text('Driver: ${route['driver']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(width: 16),
                      Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(route['phone'] as String, style: TextStyle(fontSize: 13, color: color)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Stops', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  ...stops.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(e.value, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                        if (e.key == 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('School', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

