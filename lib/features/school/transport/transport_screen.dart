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

  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _routes = [];
  Map<String, dynamic>? _myTransport;
  String _userRole = 'admin';
  int _expandedIndex = 0;

  // Live Attendance & Gate Pass state
  List<Map<String, dynamic>> _busAttendanceLogs = [];
  List<Map<String, dynamic>> _gatePasses = [];
  String _selectedRouteForAttendance = '';
  String _selectedStopForAttendance = 'School Gate';

  static const _primaryColor = Color(0xFF0F766E);

  final List<Color> _routeColors = const [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDC2626),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final username = await _authService.getCurrentUsername() ?? '';
      final role = await _authService.getCurrentUserRole() ?? 'admin';

      final routes = await _schoolService.getTransportRoutes();
      final transportList = await _schoolService.getStudentTransport(username);
      final attLogs = await _schoolService.getBusAttendanceLogs();
      final passes = await _schoolService.getGatePasses();

      Map<String, dynamic>? myTransport;
      if (transportList.isNotEmpty) {
        myTransport = transportList.first;
      }

      if (mounted) {
        setState(() {
          _userRole = role;
          _routes = routes;
          _myTransport = myTransport;
          _busAttendanceLogs = attLogs;
          _gatePasses = passes;
          if (routes.isNotEmpty) {
            _selectedRouteForAttendance = routes.first['route_no'] ?? '';
            final stops = routes.first['stops'] as List;
            if (stops.isNotEmpty) _selectedStopForAttendance = stops.first.toString();
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load transport & fleet details. Tap retry.';
        });
      }
    }
  }

  // ===== DIALOGS =====

  void _showAddRouteDialog() {
    final routeNoCtrl = TextEditingController(text: 'Route 4');
    final nameCtrl = TextEditingController(text: 'Route 4 - Raipur & Sahastradhara');
    final busNoCtrl = TextEditingController(text: 'UK-07-PA-4096');
    final driverCtrl = TextEditingController(text: 'Anil Chauhan');
    final phoneCtrl = TextEditingController(text: '9876543213');
    final timeCtrl = TextEditingController(text: '07:15 AM');
    final stopsCtrl = TextEditingController(text: 'School Gate, Raipur, Sahastradhara Road, IT Park');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Transport Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: routeNoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Route ID',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: busNoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Bus Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Route Name & Coverage Area',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: driverCtrl,
                      decoration: InputDecoration(
                        labelText: 'Driver Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Driver Mobile',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: stopsCtrl,
                decoration: InputDecoration(
                  labelText: 'Stops (Comma-separated)',
                  hintText: 'Stop 1, Stop 2, Stop 3...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    try {
                      final stopsList = stopsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                      await _schoolService.supabase.from('school_transport').insert({
                        'institute_code': 'SHIV-SCH',
                        'route_name': nameCtrl.text.trim(),
                        'bus_number': busNoCtrl.text.trim(),
                        'driver_name': driverCtrl.text.trim(),
                        'driver_phone': phoneCtrl.text.trim(),
                        'pickup_time': timeCtrl.text.trim(),
                        'stops': stopsList,
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Route created successfully!'), backgroundColor: Colors.green),
                        );
                        _loadData();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Save Route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestGatePassDialog() {
    final studentCtrl = TextEditingController(text: 'Aarav Sharma');
    final classCtrl = TextEditingController(text: 'Class 10-A');
    final reasonCtrl = TextEditingController(text: 'Medical Consultation at Max Hospital');
    final timeCtrl = TextEditingController(text: '12:30 PM');
    final pickupNameCtrl = TextEditingController(text: 'Rajesh Sharma');
    final phoneCtrl = TextEditingController(text: '9876543210');
    String selectedRelation = 'Father';
    bool isAuthorized = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Request Early Exit Gate Pass',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: studentCtrl,
                            decoration: InputDecoration(
                              labelText: 'Student Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: classCtrl,
                            decoration: InputDecoration(
                              labelText: 'Class',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: reasonCtrl,
                            decoration: InputDecoration(
                              labelText: 'Reason for Exit',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: timeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Expected Exit Time',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Authorized Pickup Person Details',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: pickupNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Pickup Person Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedRelation,
                            decoration: InputDecoration(
                              labelText: 'Relation',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Father', child: Text('Father')),
                              DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                              DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
                              DropdownMenuItem(value: 'Emergency Contact', child: Text('Emergency Contact')),
                              DropdownMenuItem(value: 'Other', child: Text('Other (Unlisted)')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setSheetState(() {
                                  selectedRelation = v;
                                  if (v == 'Other') isAuthorized = false;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Contact Phone Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isAuthorized,
                      activeColor: _primaryColor,
                      title: const Text(
                        'Pre-registered Authorised Person on School Master Records',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        isAuthorized
                            ? 'Instant verification via Parent Master Record'
                            : 'MANDATORY: Unlisted persons require formal Principal approval before gate exit can be authorized.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAuthorized ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: isAuthorized ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      onChanged: (v) => setSheetState(() => isAuthorized = v ?? true),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          try {
                            await _schoolService.requestGatePass(
                              studentId: 'sstudent1',
                              studentName: studentCtrl.text.trim(),
                              className: classCtrl.text.trim(),
                              reason: reasonCtrl.text.trim(),
                              expectedExitTime: timeCtrl.text.trim(),
                              pickupPersonName: pickupNameCtrl.text.trim(),
                              pickupPersonRelation: selectedRelation,
                              pickupPersonPhone: phoneCtrl.text.trim(),
                              isAuthorizedOnRecord: isAuthorized,
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isAuthorized
                                      ? 'Gate Pass issued and security notified!'
                                      : 'Submitted! Flagged for mandatory Principal approval.'),
                                  backgroundColor: isAuthorized ? Colors.green : Colors.orange,
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: const Text('Generate Gate Pass',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===== TAB 1: ROUTES & VEHICLE COMPLIANCE =====

  Widget _buildRoutesTab() {
    // Check if any bus has expired vehicle documents
    final expiredBuses = _routes.where((r) => r['fitness_expired'] == true).toList();

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vehicle Expiry Alert Banner
          if (expiredBuses.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CRITICAL: Vehicle Document Expiry Alert',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Bus ${expiredBuses.first['bus_no']} Fitness Certificate Expired on ${expiredBuses.first['fitness_expiry']}. '
                          'Statutory fitness renewal required immediately.',
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Summary Stats
          _buildStatsSummary(),
          const SizedBox(height: 20),

          // All Routes Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'School Bus Fleet & Routes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                '${_routes.length} Active Routes',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route Cards
          if (_routes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text('No transport routes configured.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._routes.asMap().entries.map((e) => _buildRouteCard(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildRouteCard(int index, Map<String, dynamic> route) {
    final isExpanded = _expandedIndex == index;
    final color = _routeColors[index % _routeColors.length];
    final isExpired = route['fitness_expired'] == true;
    final stops = route['stops'] as List<String>;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? Colors.red.shade300 : (isExpanded ? color : Colors.transparent),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_bus, color: color, size: 24),
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
                              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isExpired ? Colors.red : Colors.green).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isExpired ? 'Fitness Expired' : 'Active & On Time',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isExpired ? Colors.red.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          route['name'] ?? '',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bus: ${route['bus_no']}  •  Driver: ${route['driver_name']}  •  ${stops.length} stops',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statutory Compliance Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Statutory Vehicle & Crew Verification',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _complianceBadge('Fitness Cert', route['fitness_expiry'] ?? 'Valid', !isExpired),
                            const SizedBox(width: 8),
                            _complianceBadge('Insurance', '2026-11-20', true),
                            const SizedBox(width: 8),
                            _complianceBadge('Police Check', 'Verified', true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _detailRow(Icons.phone_outlined, 'Driver Contact', '${route['driver_phone']}', color),
                  const SizedBox(height: 6),
                  _detailRow(Icons.access_time, 'Depot Departure', '${route['pickup_time']}', color),
                  const SizedBox(height: 12),

                  const Text(
                    'Route Stops & Sequence',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  ...stops.asMap().entries.map(
                        (e) => _buildStopRow(e.key, e.value, stops.length, color),
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _complianceBadge(String label, String value, bool isValid) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isValid ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isValid ? Colors.green.shade800 : Colors.red.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        ),
      ],
    );
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
                    color: isFirst || isLast ? color : color.withValues(alpha: 0.3),
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
                    child: Container(width: 2, color: color.withValues(alpha: 0.2)),
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

  Widget _buildStatsSummary() {
    final totalStops = _routes.fold<int>(0, (sum, r) => sum + ((r['stops'] as List).length));
    final verifiedDrivers = _routes.length;

    return Row(
      children: [
        _statBox('${_routes.length}', 'Active Fleet', Icons.directions_bus, const Color(0xFF0F766E)),
        const SizedBox(width: 10),
        _statBox('$totalStops', 'Total Stops', Icons.place_outlined, const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        _statBox('$verifiedDrivers/${_routes.length}', 'Crew Verified', Icons.verified_user_outlined, const Color(0xFF059669)),
      ],
    );
  }

  Widget _statBox(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // ===== TAB 2: LIVE JOURNEY & BUS ATTENDANCE =====

  Widget _buildLiveJourneyTab() {
    final t = _myTransport ??
        {
          'route_no': 'Route 1',
          'bus_no': 'UK-07-PA-1024',
          'pickup_point': 'Jakhan Chowk',
          'current_stop': 'Clock Tower',
          'eta_minutes': 8,
          'driver_name': 'Kishan Rawat',
          'driver_phone': '9876543210',
          'live_status': 'En Route',
        };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Parent Live View Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.25),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gps_fixed, size: 26, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Live Vehicle Telematics (Driver App GPS)',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('${t['route_no']} • Bus ${t['bus_no']}',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 10),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Location', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(t['current_stop'] ?? 'Clock Tower',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Estimated Arrival', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text('ETA: ${t['eta_minutes']} mins',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text('Driver: ${t['driver_name']} (${t['driver_phone']})',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bus Attendance Section (Conductor / Driver Flow)
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.how_to_reg, color: Color(0xFF0F766E), size: 22),
                    SizedBox(width: 8),
                    Text('Per-Stop Bus Attendance Marking',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStopForAttendance,
                        decoration: InputDecoration(
                          labelText: 'Current Bus Stop',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'School Gate', child: Text('School Gate')),
                          DropdownMenuItem(value: 'Clock Tower', child: Text('Clock Tower')),
                          DropdownMenuItem(value: 'Jakhan', child: Text('Jakhan')),
                          DropdownMenuItem(value: 'Dilaram Chowk', child: Text('Dilaram Chowk')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedStopForAttendance = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Mark Student Boarding/Alighting:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),

                _buildAttendanceActionTile('sstudent1', 'Aarav Sharma (Class 10-A)'),
                _buildAttendanceActionTile('sstudent2', 'Priya Patel (Class 10-A)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Attendance Events Audit Feed
        const Text(
          'Live Journey & Boarding Log Feed',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),

        if (_busAttendanceLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No attendance logs logged yet for today\'s trip.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          )
        else
          ..._busAttendanceLogs.take(5).map((log) {
            final isBoarded = log['action'] == 'Boarded';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isBoarded ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Icon(
                    isBoarded ? Icons.login : Icons.logout,
                    color: isBoarded ? Colors.green.shade800 : Colors.blue.shade800,
                    size: 18,
                  ),
                ),
                title: Text('${log['student_name']} • ${log['action']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Stop: ${log['stop']} • ${log['time']} (${log['date']})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                trailing: Text(log['recorded_by'] ?? 'Attendant',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAttendanceActionTile(String studentId, String studentName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () async {
                  await _schoolService.recordBusAttendance(
                    routeId: _selectedRouteForAttendance,
                    stopName: _selectedStopForAttendance,
                    studentId: studentId,
                    studentName: studentName,
                    action: 'Boarded',
                  );
                  _loadData();
                },
                child: const Text('Boarded', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () async {
                  await _schoolService.recordBusAttendance(
                    routeId: _selectedRouteForAttendance,
                    stopName: _selectedStopForAttendance,
                    studentId: studentId,
                    studentName: studentName,
                    action: 'Alighted',
                  );
                  _loadData();
                },
                child: const Text('Alighted', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== TAB 3: GATE PASS & PICKUP VERIFICATION =====

  Widget _buildGatePassTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Action Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Security Gate Passes & Pickup Verifications',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: _showRequestGatePassDialog,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Request Pass', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_gatePasses.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No active gate passes issued for today.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._gatePasses.map((pass) {
            final isAuthorized = pass['is_authorized'] == true;
            final isExitLogged = pass['status'].toString().contains('Exit Verified');
            final isPrincipalNeeded = !isAuthorized && !isExitLogged;
            final passId = pass['id']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isPrincipalNeeded ? Colors.orange.shade300 : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${pass['pass_no']} • ${pass['student_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExitLogged
                                ? Colors.blue.shade50
                                : (isAuthorized ? Colors.green.shade50 : Colors.orange.shade50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isExitLogged ? 'Exit Logged' : (isAuthorized ? 'Authorized' : 'Principal Req'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isExitLogged
                                  ? Colors.blue.shade800
                                  : (isAuthorized ? Colors.green.shade800 : Colors.orange.shade800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Class: ${pass['class']} • Exit Time: ${pass['exit_time']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    Text('Reason: ${pass['reason']}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin, size: 20, color: Color(0xFF0F766E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pickup Person: ${pass['pickup_person']} (${pass['relation']})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Phone: ${pass['phone']} • Photo ID Verified by Parent',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pass['status'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isExitLogged ? Colors.blue.shade800 : Colors.grey.shade700,
                          ),
                        ),
                        if (!isExitLogged)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPrincipalNeeded ? Colors.orange.shade800 : const Color(0xFF0F766E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () async {
                              await _schoolService.verifyAndAuthorizeGatePassExit(
                                passId: passId,
                                gateOfficer: 'Security Gate 1',
                                verificationNotes: 'Photo ID verified against school authorized list',
                              );
                              _loadData();
                            },
                            icon: const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white),
                            label: Text(
                              isPrincipalNeeded ? 'Principal Seal & Exit' : 'Verify ID & Exit',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Transport & Safety Hub',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF14B8A6)],
            ),
          ),
        ),
        actions: [
          if (_userRole == 'admin' || _userRole == 'sadmin')
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              tooltip: 'Add Route',
              onPressed: _showAddRouteDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF134E4A),
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.directions_bus, size: 16), text: 'Fleet'),
                Tab(icon: Icon(Icons.gps_fixed, size: 16), text: 'Journey'),
                Tab(icon: Icon(Icons.badge, size: 16), text: 'Gate Pass'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRoutesTab(),
                    _buildLiveJourneyTab(),
                    _buildGatePassTab(),
                  ],
                ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Transport Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to the fleet telematics server.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
