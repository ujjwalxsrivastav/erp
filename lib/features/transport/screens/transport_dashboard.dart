import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/transport_service.dart';
import '../../../services/auth_service.dart';
import 'bus_maintenance_dashboard.dart';

class TransportDashboard extends StatefulWidget {
  const TransportDashboard({super.key});
  @override
  State<TransportDashboard> createState() => _TransportDashboardState();
}

class _TransportDashboardState extends State<TransportDashboard>
    with TickerProviderStateMixin {
  final _service = TransportService();
  final _authService = AuthService();

  late AnimationController _fadeCtrl;
  late TabController _tabCtrl;
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _tabCtrl = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await _service.getDashboardStats();
    final pending = await _service.getPendingRequests();
    final all = await _service.getAllRequests();
    final routes = await _service.getRoutes();
    final buses = await _service.getBuses();
    final alerts = await _service.getActiveAlerts();
    if (mounted) {
      setState(() {
        _stats = stats;
        _pendingRequests = pending;
        _allRequests = all;
        _routes = routes;
        _buses = buses;
        _alerts = alerts;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) context.go('/login');
  }

  String _getRouteName(String? routeId) {
    if (routeId == null) return 'Unknown';
    final route = _routes.firstWhere(
        (r) => r['id'] == routeId,
        orElse: () => {'route_name': 'Unknown'});
    return route['route_name'] ?? 'Unknown';
  }

  List<Map<String, dynamic>> _getBusesForRoute(String? routeId) {
    if (routeId == null) return [];
    return _buses.where((b) => b['route_id'] == routeId).toList();
  }

  Future<void> _showAllocateDialog(Map<String, dynamic> request) async {
    final routeBuses = _getBusesForRoute(request['route_id']);
    if (routeBuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No buses available for this route'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    String? selectedBusId;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Allocate Bus to ${request['student_name']}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Route: ${_getRouteName(request['route_id'])}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ...routeBuses.map((bus) {
                  final isSelected = selectedBusId == bus['id'];
                  final occ = bus['current_occupancy'] ?? 0;
                  final cap = bus['capacity'] ?? 40;
                  final isFull = occ >= cap;
                  return GestureDetector(
                    onTap: isFull
                        ? null
                        : () => setModalState(() => selectedBusId = bus['id']),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF38BDF8).withOpacity(0.12)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF38BDF8)
                              : isFull
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('${bus['bus_number']}',
                                  style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bus #${bus['bus_number']}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  '${bus['driver_name'] ?? '-'} • $occ/$cap seats',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (isFull)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Full',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            )
                          else if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Color(0xFF38BDF8)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () async {
                          if (selectedBusId == null) return;
                          Navigator.pop(ctx);
                          setState(() => _loading = true);
                          await _service.allocateBus(
                            requestId: request['id'],
                            busId: selectedBusId!,
                            officerUsername: 'transportofficer1',
                          );
                          await _load();
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content:
                                  Text('✅ Bus allocated successfully!'),
                              backgroundColor: Color(0xFF22C55E),
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: selectedBusId != null
                                ? const LinearGradient(colors: [
                                    Color(0xFF0C4A6E),
                                    Color(0xFF0369A1)
                                  ])
                                : null,
                            color: selectedBusId == null
                                ? Colors.white.withOpacity(0.05)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('Allocate Bus',
                                style: TextStyle(
                                    color: selectedBusId != null
                                        ? Colors.white
                                        : Colors.white24,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF38BDF8)))
            : NestedScrollView(
                headerSliverBuilder: (_, __) => [_buildAppBar()],
                body: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildOverviewTab(),
                    _buildPendingTab(),
                    _buildAllTab(),
                    _buildAlertsTab(),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── APP BAR ──────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0A0F1E),
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh'),
        IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout'),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
                ),
              ),
            ),
            Positioned(
              right: -40, top: -40,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus_rounded,
                            color: Color(0xFF38BDF8), size: 14),
                        SizedBox(width: 6),
                        Text('Transport Officer',
                            style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Transport Hub',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                  const SizedBox(height: 4),
                  Text('Shivalik College — Fleet & Route Management',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: TabBar(
        controller: _tabCtrl,
        labelColor: const Color(0xFF38BDF8),
        unselectedLabelColor: Colors.white38,
        indicatorColor: const Color(0xFF38BDF8),
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: [
          const Tab(text: 'Overview'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pending'),
                if (_pendingRequests.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_pendingRequests.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'All Students'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Alerts'),
                if (_alerts.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_alerts.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── OVERVIEW TAB ─────────────────────────────────────────

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildStatGrid(),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BusMaintenanceDashboard()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.build_circle, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fleet Maintenance & Fuel Logs', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Manage service records, receipts & track mileage.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('🚌  Buses',
            subtitle: '${_buses.length} total'),
        const SizedBox(height: 12),
        ..._buses.map(_buildBusCard),
        const SizedBox(height: 24),
        _buildSectionHeader('🗺️  Routes',
            subtitle: '${_routes.length} active routes'),
        const SizedBox(height: 12),
        ..._routes.map(_buildRouteCard),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatGrid() {
    final stats = [
      _SData('Total Buses', '${_stats['total_buses'] ?? 0}',
          Icons.directions_bus_rounded, const Color(0xFF38BDF8)),
      _SData('Active', '${_stats['active_buses'] ?? 0}',
          Icons.check_circle_rounded, const Color(0xFF34D399)),
      _SData('Pending', '${_stats['pending_requests'] ?? 0}',
          Icons.hourglass_top_rounded, const Color(0xFFFBBF24)),
      _SData('Approved', '${_stats['approved_requests'] ?? 0}',
          Icons.people_rounded, const Color(0xFFA78BFA)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats
          .map((s) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: s.color.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(s.icon, color: s.color, size: 22),
                        Text(s.value,
                            style: TextStyle(
                                color: s.color,
                                fontWeight: FontWeight.w900,
                                fontSize: 24)),
                      ],
                    ),
                    Text(s.label,
                        style: TextStyle(
                            color: s.color.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildBusCard(Map<String, dynamic> bus) {
    final occ = bus['current_occupancy'] ?? 0;
    final cap = bus['capacity'] ?? 40;
    final pct = cap > 0 ? (occ / cap) : 0.0;
    final status = bus['trip_status'] ?? 'At Depot';
    final inTransit = status == 'In Transit';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: inTransit ? const Color(0xFF10B981).withOpacity(0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: inTransit ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFF38BDF8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('${bus['bus_number']}',
                  style: TextStyle(
                      color: inTransit ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bus #${bus['bus_number']} • ${bus['vehicle_no'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: inTransit ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(status, style: TextStyle(color: inTransit ? const Color(0xFF10B981) : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getRouteName(bus['route_id'])} • ${bus['driver_name'] ?? '-'}',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(
                        pct > 0.8 ? Colors.red : const Color(0xFF38BDF8)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 2),
                Text('$occ / $cap seats',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFA78BFA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route_rounded,
                color: Color(0xFFA78BFA), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route['route_name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(
                  '${route['distance_km'] ?? '-'} km • ${route['estimated_time'] ?? '-'} • ₹${route['fare'] ?? 0}',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PENDING TAB ──────────────────────────────────────────

  Widget _buildPendingTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                color: Colors.white.withOpacity(0.1), size: 80),
            const SizedBox(height: 16),
            const Text('No Pending Requests',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('All student requests have been processed',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingRequests.length,
      itemBuilder: (_, i) {
        final req = _pendingRequests[i];
        return _buildRequestCard(req, showActions: true);
      },
    );
  }

  // ─── ALL STUDENTS TAB ─────────────────────────────────────

  Widget _buildAllTab() {
    if (_allRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                color: Colors.white.withOpacity(0.1), size: 80),
            const SizedBox(height: 16),
            const Text('No Requests Yet',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allRequests.length,
      itemBuilder: (_, i) => _buildRequestCard(_allRequests[i]),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req,
      {bool showActions = false}) {
    final status = req['status'] ?? 'pending';
    final statusColor = status == 'approved'
        ? const Color(0xFF22C55E)
        : status == 'rejected'
            ? const Color(0xFFEF4444)
            : const Color(0xFFFBBF24);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (req['student_name'] ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req['student_name'] ?? 'Unknown',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      '${req['student_id']} • ${_getRouteName(req['route_id'])}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Stop: ${req['stop_name'] ?? 'S1'} • Fee: ₹${req['fee_amount'] ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(width: 8),
                        if (req['fee_status'] == 'not_paid')
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                             decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                             child: const Text('FEE NOT PAID', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.bold)),
                           ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      setState(() => _loading = true);
                      await _service.rejectRequest(
                        requestId: req['id'],
                        officerUsername: 'transportofficer1',
                      );
                      await _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text('Reject',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => _showAllocateDialog(req),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF0C4A6E),
                          Color(0xFF0369A1)
                        ]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('Allocate Bus',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── ALERTS TAB ───────────────────────────────────────────

  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: Colors.white.withOpacity(0.1), size: 80),
            const SizedBox(height: 16),
            const Text('No Active Alerts', style: TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('All buses are running smoothly', style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _alerts.length,
      itemBuilder: (_, i) {
        final alert = _alerts[i];
        final type = alert['alert_type'] ?? 'Unknown';
        final desc = alert['description'] ?? '';
        final bus = alert['transport_buses'] ?? {};
        final busNo = bus['bus_number'] ?? '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$type Alert - Bus #$busNo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Reported by ${alert['reported_by']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
                    child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() => _loading = true);
                    await _service.resolveAlert(alert['id'], 'transportofficer1');
                    await _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                    foregroundColor: const Color(0xFFEF4444),
                    elevation: 0,
                  ),
                  child: const Text('Mark as Resolved'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ],
    );
  }
}

class _SData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SData(this.label, this.value, this.icon, this.color);
}
