import 'package:flutter/material.dart';
import '../services/transport_service.dart';

class StudentTransportScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  const StudentTransportScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentTransportScreen> createState() => _StudentTransportScreenState();
}

class _StudentTransportScreenState extends State<StudentTransportScreen>
    with SingleTickerProviderStateMixin {
  final _service = TransportService();
  late AnimationController _fadeCtrl;

  bool _loading = true;
  List<Map<String, dynamic>> _routes = [];
  Map<String, dynamic>? _myRequest;
  Map<String, dynamic>? _myRoute;
  Map<String, dynamic>? _myBus;
  String? _selectedRouteId;
  int? _selectedStopIndex;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final routes = await _service.getRoutes();
    final request = await _service.getStudentRequest(widget.studentId);

    Map<String, dynamic>? route;
    Map<String, dynamic>? bus;

    if (request != null && request['route_id'] != null) {
      route = await _service.getRouteById(request['route_id']);
    }
    if (request != null && request['bus_id'] != null) {
      bus = await _service.getBusById(request['bus_id']);
    }

    if (mounted) {
      setState(() {
        _routes = routes;
        _myRequest = request;
        _myRoute = route;
        _myBus = bus;
        _loading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a route first'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    
    final stopName = 'S${_selectedStopIndex!}';
    final feeAmount = _selectedStopIndex! * 500.0;

    final result = await _service.submitRouteRequest(
      studentId: widget.studentId,
      studentName: widget.studentName,
      routeId: _selectedRouteId!,
      stopName: stopName,
      feeAmount: feeAmount,
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _selectedStopIndex = null;
      await _loadData();
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : FadeTransition(
              opacity: _fadeCtrl,
              child: _myRequest != null ? _buildStatusView() : _buildRouteSelector(),
            ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  STATUS VIEW — when student already has a request
  // ════════════════════════════════════════════════════════════
  Widget _buildStatusView() {
    final status = _myRequest!['status'] ?? 'pending';
    final isApproved = status == 'approved';
    final isPending = status == 'pending';

    return CustomScrollView(
      slivers: [
        _buildAppBar(
          title: isApproved ? 'Bus Allocated' : 'Request Status',
          subtitle: isApproved
              ? 'Your bus has been assigned!'
              : 'Waiting for transport officer',
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Status Badge
              _buildStatusCard(status),
              const SizedBox(height: 20),

              // Route Info
              if (_myRoute != null) ...[
                _sectionHeader('🗺️  Your Route'),
                const SizedBox(height: 12),
                _buildRouteInfoCard(_myRoute!),
                const SizedBox(height: 20),
              ],

              // Bus Info (only if approved)
              if (isApproved && _myBus != null) ...[
                _sectionHeader('🚌  Assigned Bus'),
                const SizedBox(height: 12),
                _buildBusInfoCard(_myBus!),
                const SizedBox(height: 20),

                // Stop & Fee Info
                _sectionHeader('💳  Stop & Fee Details'),
                const SizedBox(height: 12),
                _buildFeeInfoCard(),
                const SizedBox(height: 20),

                // Route Stops
                if (_myRequest?['stop_name'] != null) ...[
                  _sectionHeader('📍  Route Stops'),
                  const SizedBox(height: 12),
                  _buildDynamicRouteStops(_myRequest!['stop_name']),
                  const SizedBox(height: 20),
                ],
              ],

              // Pending animation
              if (isPending) ...[
                const SizedBox(height: 20),
                _buildPendingCard(),
                const SizedBox(height: 20),
              ],

              // Track Bus Button & Change Route
              _buildTrackBusButton(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String status) {
    Color color;
    IconData icon;
    String label;
    String desc;

    switch (status) {
      case 'approved':
        color = const Color(0xFF22C55E);
        icon = Icons.check_circle_rounded;
        label = 'Approved';
        desc = 'Your transport has been allocated by the officer';
        break;
      case 'rejected':
        color = const Color(0xFFEF4444);
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        desc = _myRequest?['remarks'] ?? 'Your request was not approved';
        break;
      default:
        color = const Color(0xFFFBBF24);
        icon = Icons.hourglass_top_rounded;
        label = 'Pending';
        desc = 'Transport officer will review and assign your bus';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(desc,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard(Map<String, dynamic> route) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.route_rounded,
                    color: Color(0xFF3B82F6), size: 24),
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
                            fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(route['route_description'] ?? '',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoChip(Icons.timer_outlined, route['estimated_time'] ?? '-'),
              const SizedBox(width: 10),
              _infoChip(Icons.straighten,
                  '${route['distance_km'] ?? '-'} km'),
              const SizedBox(width: 10),
              _infoChip(Icons.currency_rupee,
                  '₹${route['fare'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusInfoCard(Map<String, dynamic> bus) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0369A1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${bus['bus_number'] ?? '-'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bus #${bus['bus_number']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(bus['vehicle_no'] ?? '',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _busDetailItem(Icons.person, 'Driver',
                    bus['driver_name'] ?? '-'),
                Container(width: 1, height: 30, color: Colors.white12),
                _busDetailItem(Icons.phone, 'Phone',
                    bus['driver_phone'] ?? '-'),
                Container(width: 1, height: 30, color: Colors.white12),
                _busDetailItem(Icons.event_seat, 'Capacity',
                    '${bus['capacity'] ?? '-'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _busDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildDynamicRouteStops(String stopName) {
    int stopNum = 1;
    if (stopName.startsWith('S')) {
      stopNum = int.tryParse(stopName.substring(1)) ?? 1;
    }
    
    List<String> stops = ['Shivalik College'];
    for (int i = 1; i <= stopNum; i++) {
      stops.add('S$i');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: stops.asMap().entries.map((e) {
          final idx = e.key;
          final stop = e.value;
          final isLast = idx == stops.length - 1;
          final isFirst = idx == 0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFirst
                          ? const Color(0xFF22C55E)
                          : isLast
                              ? const Color(0xFF3B82F6)
                              : Colors.white12,
                      border: Border.all(
                          color: isFirst
                              ? const Color(0xFF22C55E)
                              : isLast
                                  ? const Color(0xFF3B82F6)
                                  : Colors.white24,
                          width: 2),
                    ),
                    child: Center(
                      child: Text('${idx + 1}',
                          style: TextStyle(
                              color: (isFirst || isLast)
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2, height: 30,
                      color: Colors.white10,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(stop,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeeInfoCard() {
    final fee = _myRequest!['fee_amount'] ?? 0;
    final stop = _myRequest!['stop_name'] ?? 'S1';
    final isPaid = _myRequest!['fee_status'] == 'paid';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stop: $stop', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Fee: ₹$fee', style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPaid ? const Color(0xFF22C55E).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isPaid ? 'PAID' : 'NOT PAID',
                style: TextStyle(color: isPaid ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFBBF24).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (_, value, child) => Opacity(
                opacity: 0.4 + (0.6 * value), child: child),
            child: const Icon(Icons.pending_actions_rounded,
                color: Color(0xFFFBBF24), size: 48),
          ),
          const SizedBox(height: 16),
          const Text('Awaiting Approval',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'The transport officer will review your request\nand assign you a bus soon.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white38, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackBusButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🚧 Track Bus feature is coming soon!'),
                backgroundColor: Color(0xFFFBBF24),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Track Bus',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            setState(() {
              _myRequest = null;
              _myRoute = null;
              _myBus = null;
            });
          },
          child: const Text(
            'Change Route',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ROUTE SELECTOR — when student hasn't requested yet
  // ════════════════════════════════════════════════════════════
  Widget _buildRouteSelector() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(
          title: 'Select Route',
          subtitle: 'Choose your daily transport route',
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF38BDF8), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select a route below. After submitting, the transport officer will assign you a bus.',
                        style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _sectionHeader('📍  Available Routes'),
              const SizedBox(height: 14),

              // Route Cards
              ..._routes.map((route) => _buildSelectableRouteCard(route)),
              const SizedBox(height: 24),

              if (_selectedRouteId != null) ...[
                _sectionHeader('🚏  Select Your Stop'),
                const SizedBox(height: 14),
                _buildStopsList(),
                const SizedBox(height: 24),
              ],

              // Submit Button
              GestureDetector(
                onTap: _submitRequest,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: (_selectedRouteId != null && _selectedStopIndex != null)
                        ? const LinearGradient(
                            colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)])
                        : null,
                    color: (_selectedRouteId == null || _selectedStopIndex == null)
                        ? Colors.white.withOpacity(0.05)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (_selectedRouteId != null && _selectedStopIndex != null)
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFF0369A1).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Submit Request',
                      style: TextStyle(
                        color: (_selectedRouteId != null && _selectedStopIndex != null)
                            ? Colors.white
                            : Colors.white24,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableRouteCard(Map<String, dynamic> route) {
    final isSelected = _selectedRouteId == route['id'];
    final routeColors = {
      'Paonta Sahib': const Color(0xFF22C55E),
      'Clock Tower': const Color(0xFFA78BFA),
      'ISBT': const Color(0xFFFBBF24),
    };
    final color = routeColors[route['route_name']] ?? const Color(0xFF38BDF8);
    final routeIcons = {
      'Paonta Sahib': Icons.landscape_rounded,
      'Clock Tower': Icons.access_time_rounded,
      'ISBT': Icons.directions_bus_filled_rounded,
    };
    final icon =
        routeIcons[route['route_name']] ?? Icons.route_rounded;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedRouteId = route['id'];
        _selectedStopIndex = null; // reset stop when route changes
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.12)
              : const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isSelected ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route['route_name'] ?? '',
                          style: TextStyle(
                              color: isSelected ? color : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(route['route_description'] ?? '',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                // Radio-like indicator
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                        color: isSelected ? color : Colors.white24,
                        width: 2),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _infoChip(Icons.timer_outlined,
                    route['estimated_time'] ?? '-'),
                const SizedBox(width: 10),
                _infoChip(Icons.straighten,
                    '${route['distance_km'] ?? '-'} km'),
                const SizedBox(width: 10),
                _infoChip(Icons.currency_rupee,
                    '₹${route['fare'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 10,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (ctx, i) {
          final idx = i + 1;
          final fee = idx * 500;
          final isSelected = _selectedStopIndex == idx;

          return ListTile(
            onTap: () => setState(() => _selectedStopIndex = idx),
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent),
              ),
              child: Center(child: Text('S$idx', style: TextStyle(color: isSelected ? const Color(0xFF3B82F6) : Colors.white70, fontWeight: FontWeight.bold))),
            ),
            title: Text('Stop $idx', style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            trailing: Text('+ ₹$fee', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  COMMON WIDGETS
  // ════════════════════════════════════════════════════════════
  SliverAppBar _buildAppBar({required String title, required String subtitle}) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
      elevation: 0,
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
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFF38BDF8).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus_rounded,
                            color: Color(0xFF38BDF8), size: 12),
                        SizedBox(width: 4),
                        Text('Transport',
                            style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white38, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16),
      );
}
