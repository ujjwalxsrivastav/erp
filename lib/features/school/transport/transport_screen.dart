import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen>
    with SingleTickerProviderStateMixin {
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _routes = [];
  Map<String, dynamic>? _myTransport;
  String _userRole = 'student';
  int _expandedIndex = -1;

  static const _primaryColor = Color(0xFF06B6D4);

  final List<Color> _routeColors = const [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final username = await _authService.getCurrentUsername() ?? '';
      final role = await _authService.getCurrentUserRole() ?? 'student';

      final routes = await _schoolService.getTransportRoutes();
      Map<String, dynamic>? myTransport;
      if (role == 'student') {
        final list = await _schoolService.getStudentTransport(username);
        if (list.isNotEmpty) myTransport = list.first;
      }

      if (mounted) {
        setState(() {
          _userRole = role;
          _routes = routes;
          _myTransport = myTransport;
          _isLoading = false;
          if (routes.isNotEmpty) _expandedIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Transport', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_userRole == 'admin' || _userRole == 'sadmin')
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Route',
              onPressed: _showAddRouteDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // My Bus Card (for students)
                  if (_userRole == 'student' && _myTransport != null) ...[
                    _buildMyBusCard(),
                    const SizedBox(height: 20),
                  ],

                  // Summary Stats
                  _buildStatsSummary(),
                  const SizedBox(height: 20),

                  // All Routes Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Routes',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${_routes.length} routes',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Route Cards
                  ..._routes.asMap().entries.map((e) => _buildRouteCard(e.key, e.value)),
                ],
              ),
            ),
    );
  }

  Widget _buildMyBusCard() {
    final t = _myTransport!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_bus, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Bus', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(
                      t['route_no'] ?? 'Route A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bus: ${t['bus_no'] ?? 'N/A'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t['live_status'] ?? 'On Time',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              _busInfoItem(Icons.location_on_outlined, 'Pickup', t['pickup_point'] ?? 'School Gate'),
              const SizedBox(width: 20),
              _busInfoItem(Icons.access_time, 'Pickup Time', t['pickup_time'] ?? '07:25 AM'),
              const SizedBox(width: 20),
              _busInfoItem(Icons.flag_outlined, 'Drop Time', t['drop_time'] ?? '02:45 PM'),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showDriverContact(t),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Driver: ${t['driver_name'] ?? 'N/A'}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Spacer(),
                  const Icon(Icons.phone, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    t['driver_phone'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _busInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    final totalStudents = _routes.fold<int>(
        0, (sum, r) => sum + ((r['students'] as num?)?.toInt() ?? 0));
    final onTime = _routes.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'on time').length;

    return Row(
      children: [
        _statBox('${_routes.length}', 'Routes', Icons.route, const Color(0xFF3B82F6)),
        const SizedBox(width: 12),
        _statBox('$totalStudents', 'Students', Icons.people_outline, const Color(0xFF10B981)),
        const SizedBox(width: 12),
        _statBox('$onTime/${_routes.length}', 'On Time', Icons.check_circle_outline, const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _statBox(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(int index, Map<String, dynamic> route) {
    final isExpanded = _expandedIndex == index;
    final color = _routeColors[index % _routeColors.length];
    final status = route['status']?.toString() ?? 'On Time';
    final isDelay = !status.toLowerCase().contains('on time');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? color : Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : index),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_bus, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              route['route_no'] ?? 'Route',
                              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDelay ? Colors.orange : Colors.green).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDelay ? Colors.orange.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          route['name'] ?? '',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bus: ${route['bus_no'] ?? 'N/A'}  •  ${route['students'] ?? 0} students  •  ${route['stops'] ?? 0} stops',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
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

          // Expanded Details
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver Info
                  _detailRow(
                    Icons.person_outline,
                    'Driver',
                    '${route['driver_name'] ?? 'N/A'}  •  ${route['driver_phone'] ?? ''}',
                    color,
                  ),
                  const SizedBox(height: 8),
                  _detailRow(Icons.people_outline, 'Students', '${route['students'] ?? 0} enrolled', color),
                  const SizedBox(height: 8),
                  _detailRow(Icons.place_outlined, 'Total Stops', '${route['stops'] ?? 0} stops', color),
                  const SizedBox(height: 14),

                  // Stops timeline (from route stops data)
                  const Text(
                    'Route Stops',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 10),
                  ..._getStopsForRoute(route).asMap().entries.map(
                        (e) => _buildStopRow(e.key, e.value, _getStopsForRoute(route).length, color),
                      ),

                  if (_userRole == 'admin' || _userRole == 'sadmin') ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit Route'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color),
                            ),
                            onPressed: () => _showEditRouteDialog(index, route),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.people, size: 16),
                            label: const Text('View Students'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showRouteStudents(route),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
        ),
      ],
    );
  }

  List<String> _getStopsForRoute(Map<String, dynamic> route) {
    final rawStops = route['stops'];
    if (rawStops is List) {
      return rawStops.map((s) => s.toString()).toList();
    } else if (rawStops is String && rawStops.trim().isNotEmpty) {
      if (rawStops.startsWith('[')) {
        try {
          final decoded = jsonDecode(rawStops);
          if (decoded is List) return decoded.map((s) => s.toString()).toList();
        } catch (_) {}
      }
      return rawStops.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return ['School Campus'];
  }

  Widget _buildStopRow(int index, String stop, int total, Color color) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isFirst || isLast ? color : color.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: isFirst
                      ? const Icon(Icons.school, size: 10, color: Colors.white)
                      : isLast
                          ? const Icon(Icons.flag, size: 10, color: Colors.white)
                          : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: color.withOpacity(0.2)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              stop,
              style: TextStyle(
                fontSize: 13,
                color: isFirst || isLast ? color : const Color(0xFF374151),
                fontWeight: isFirst || isLast ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverContact(Map<String, dynamic> transport) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Driver Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: _primaryColor.withOpacity(0.1),
              radius: 36,
              child: const Icon(Icons.person, color: _primaryColor, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              transport['driver_name'] ?? 'N/A',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(transport['driver_phone'] ?? '', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showRouteStudents(Map<String, dynamic> route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          builder: (_, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${route['route_no']} Students',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: (route['students'] as num?)?.toInt() ?? 10,
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      child: Text('${i + 1}', style: const TextStyle(color: _primaryColor)),
                    ),
                    title: Text('Student ${i + 1}'),
                    subtitle: Text('Stop: Stop ${i % 4 + 2}'),
                    trailing: const Text('07:25 AM', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddRouteDialog() {
    final nameCtrl = TextEditingController();
    final busCtrl = TextEditingController();
    final driverCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final stopsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Route'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Route Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: busCtrl,
                decoration: const InputDecoration(labelText: 'Bus Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverCtrl,
                decoration: const InputDecoration(labelText: 'Driver Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Driver Phone', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stopsCtrl,
                decoration: const InputDecoration(labelText: 'Number of Stops', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || busCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill route name and bus number')),
                );
                return;
              }
              Navigator.pop(ctx);
              final newRoute = {
                'id': 'R-0${_routes.length + 1}',
                'route_no': 'R-0${_routes.length + 1}',
                'name': nameCtrl.text,
                'bus_no': busCtrl.text,
                'driver_name': driverCtrl.text,
                'driver_phone': phoneCtrl.text,
                'stops': int.tryParse(stopsCtrl.text) ?? 5,
                'students': 0,
                'status': 'On Time',
              };
              setState(() => _routes.add(newRoute));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Route added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Add Route'),
          ),
        ],
      ),
    );
  }

  void _showEditRouteDialog(int index, Map<String, dynamic> route) {
    final statusOptions = ['On Time', '5 min delay', '10 min delay', 'Not Running'];
    String selectedStatus = route['status'] ?? 'On Time';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit ${route['route_no']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Update Route Status:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: statusOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setS(() => selectedStatus = v ?? selectedStatus),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _routeColors[index % _routeColors.length],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _routes[index] = {..._routes[index], 'status': selectedStatus};
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Route status updated'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
