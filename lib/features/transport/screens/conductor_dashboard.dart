import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/transport_service.dart';
import '../../../services/auth_service.dart';

class ConductorDashboard extends StatefulWidget {
  const ConductorDashboard({super.key});

  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard>
    with SingleTickerProviderStateMixin {
  final _service = TransportService();
  final _authService = AuthService();

  late AnimationController _fadeCtrl;
  bool _loading = true;
  String? _username;
  Map<String, dynamic>? _myBus;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final username = await _authService.getCurrentUsername();
    _username = username;

    if (username != null) {
      final bus = await _service.getConductorBus(username);
      if (mounted) setState(() => _myBus = bus);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleTripStatus() async {
    if (_myBus == null) return;
    
    final currentStatus = _myBus!['trip_status'] ?? 'At Depot';
    final newStatus = currentStatus == 'At Depot' ? 'In Transit' : 'At Depot';

    setState(() => _loading = true);
    final success = await _service.updateBusStatus(_myBus!['id'], newStatus);
    if (success) {
      await _load(); // reload bus data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Trip marked as $newStatus'),
          backgroundColor: newStatus == 'In Transit' ? const Color(0xFF10B981) : const Color(0xFFD97706),
        ));
      }
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _showReportIssueDialog() async {
    String type = 'Delay';
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2D3D),
          title: const Text('Report Issue', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: const Color(0xFF111827),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: ['Delay', 'Breakdown', 'Accident', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setDialogState(() => type = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the issue...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                final success = await _service.reportIssue(
                  busId: _myBus!['id'],
                  conductorUsername: _username!,
                  alertType: type,
                  description: descCtrl.text,
                );
                setState(() => _loading = false);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Issue reported successfully. Officer notified.'),
                    backgroundColor: Color(0xFFEF4444),
                  ));
                }
              },
              child: const Text('Send Alert', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)))
            : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: _myBus == null
                        ? _buildNoBusView()
                        : _buildMainContent(),
                  ),
                ],
              ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0A0F1E),
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout),
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
                  colors: [Color(0xFF92400E), Color(0xFFD97706)],
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Conductor Terminal', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_myBus != null ? 'Bus #${_myBus!['bus_number']}' : 'No Bus Assigned',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const SizedBox(height: 4),
                  Text(_myBus != null && _myBus!['transport_routes'] != null
                      ? _myBus!['transport_routes']['route_name']
                      : 'Welcome back, $_username',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusView() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus_outlined, color: Color(0xFFD97706), size: 48),
            const SizedBox(height: 20),
            const Text('No Bus Assigned', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('You have not been assigned to a bus yet.', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final status = _myBus!['trip_status'] ?? 'At Depot';
    final inTransit = status == 'In Transit';

    return SliverList(
      delegate: SliverChildListDelegate([
        
        // 1. Trip Management Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: inTransit 
                  ? [const Color(0xFF047857), const Color(0xFF059669)]
                  : [const Color(0xFF1E2D3D), const Color(0xFF334155)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: inTransit ? [BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))] : [],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Status', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Icon(inTransit ? Icons.airport_shuttle_rounded : Icons.garage_rounded, color: Colors.white, size: 40),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _toggleTripStatus,
                  icon: Icon(inTransit ? Icons.stop_rounded : Icons.play_arrow_rounded, color: inTransit ? const Color(0xFF047857) : Colors.white),
                  label: Text(inTransit ? 'END TRIP' : 'START TRIP', style: TextStyle(color: inTransit ? const Color(0xFF047857) : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inTransit ? Colors.white : const Color(0xFFD97706),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 2. Features Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            // Attendance Feature
            _buildFeatureCard(
              title: 'Digital Register',
              subtitle: 'Mark daily attendance',
              icon: Icons.fact_check_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () {
                context.push('/conductor-attendance', extra: {
                  'bus': _myBus,
                  'conductorUsername': _username,
                });
              },
            ),
            
            // SOS / Report Issue
            _buildFeatureCard(
              title: 'Report Issue',
              subtitle: 'Delay or Breakdown',
              icon: Icons.warning_rounded,
              color: const Color(0xFFEF4444),
              onTap: _showReportIssueDialog,
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
