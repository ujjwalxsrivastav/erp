import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/transport_service.dart';
import '../../../services/auth_service.dart';

class TransportDashboard extends StatefulWidget {
  const TransportDashboard({super.key});
  @override
  State<TransportDashboard> createState() => _TransportDashboardState();
}

class _TransportDashboardState extends State<TransportDashboard>
    with TickerProviderStateMixin {
  final _service     = TransportService();
  final _authService = AuthService();

  late AnimationController _fadeCtrl;
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _load();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats    = await _service.getDashboardStats();
    final vehicles = await _service.getVehicles();
    if (mounted) setState(() {
      _stats    = stats;
      _vehicles = vehicles;
      _loading  = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading)
                    const SizedBox(
                      height: 300,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF38BDF8))),
                    )
                  else ...[
                    _buildStatGrid(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('🚌  Fleet Overview',
                        subtitle: '${_vehicles.length} vehicles registered'),
                    const SizedBox(height: 14),
                    ..._vehicles.isEmpty
                        ? [_buildEmptyCard('No vehicles registered yet')]
                        : _vehicles.map(_buildVehicleCard),
                    const SizedBox(height: 28),
                    _buildQuickActions(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ──────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0A0F1E),
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient bg
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
                ),
              ),
            ),
            // Decorative circle
            Positioned(
              right: -40, top: -40,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              right: 30, top: 30,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Content
            Positioned(
              left: 20, right: 20, bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
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
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
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
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STAT GRID ────────────────────────────────────────────

  Widget _buildStatGrid() {
    final stats = [
      _StatData(
        label: 'Total Vehicles',
        value: '${_stats['total_vehicles'] ?? 0}',
        icon: Icons.directions_bus_rounded,
        color: const Color(0xFF38BDF8),
      ),
      _StatData(
        label: 'Active Now',
        value: '${_stats['active_vehicles'] ?? 0}',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF34D399),
      ),
      _StatData(
        label: 'Routes',
        value: '${_stats['total_routes'] ?? 0}',
        icon: Icons.route_rounded,
        color: const Color(0xFFA78BFA),
      ),
      _StatData(
        label: 'Students',
        value: '${_stats['allocated_students'] ?? 0}',
        icon: Icons.people_rounded,
        color: const Color(0xFFFBBF24),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats.map((s) => _StatCard(data: s)).toList(),
    );
  }

  // ─── VEHICLE CARD ─────────────────────────────────────────

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final isActive = v['is_active'] == true;
    final statusColor = isActive
        ? const Color(0xFF34D399)
        : const Color(0xFFF87171);
    final type = (v['vehicle_type'] ?? 'bus').toString();
    final icon = type == 'van'
        ? Icons.airport_shuttle_rounded
        : type == 'auto'
            ? Icons.electric_rickshaw_rounded
            : Icons.directions_bus_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v['vehicle_no'] ?? 'Unknown',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${v['route_name'] ?? 'No route assigned'}  •  ${v['capacity'] ?? 0} seats',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
                if (v['driver_name'] != null) ...[
                  const SizedBox(height: 2),
                  Text('👤 ${v['driver_name']}  ${v['driver_phone'] ?? ''}',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── QUICK ACTIONS ────────────────────────────────────────

  Widget _buildQuickActions() {
    final actions = [
      _ActionData('Add Vehicle',      Icons.add_circle_rounded,    const Color(0xFF38BDF8)),
      _ActionData('Manage Routes',    Icons.map_rounded,           const Color(0xFFA78BFA)),
      _ActionData('Allocate Student', Icons.person_add_alt_rounded,const Color(0xFF34D399)),
      _ActionData('Fee Reports',      Icons.receipt_long_rounded,  const Color(0xFFFBBF24)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('⚡  Quick Actions',
            subtitle: 'Manage transport operations'),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: actions.map((a) => _QuickActionCard(data: a)).toList(),
        ),
      ],
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
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildEmptyCard(String msg) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(msg,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
}

// ─── STAT CARD ────────────────────────────────────────────────

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatData({
    required this.label, required this.value,
    required this.icon, required this.color,
  });
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(data.icon, color: data.color, size: 22),
              Text(data.value,
                  style: TextStyle(
                      color: data.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 24)),
            ],
          ),
          Text(data.label,
              style: TextStyle(
                  color: data.color.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── QUICK ACTION CARD ────────────────────────────────────────

class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  const _ActionData(this.label, this.icon, this.color);
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.data});
  final _ActionData data;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${data.label} — Coming Soon'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: data.color.withValues(alpha: 0.8),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: data.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(data.label,
                  style: TextStyle(
                      color: data.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
