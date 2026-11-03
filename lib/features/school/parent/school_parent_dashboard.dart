import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../core/widgets/erp_stat_card.dart';
import '../../../core/widgets/erp_section_header.dart';

class SchoolParentDashboard extends StatefulWidget {
  const SchoolParentDashboard({super.key});

  @override
  State<SchoolParentDashboard> createState() => _SchoolParentDashboardState();
}

class _SchoolParentDashboardState extends State<SchoolParentDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  late AnimationController _fadeController;

  String _parentName = 'Parent';
  final String _childName = 'Aarav Sharma';
  final String _childClass = 'Class 9-A';
  final String _admissionNo = 'SCH2024001';

  // Child stats
  final double _attendance = 92.0;
  final String _pendingFees = '₹5,000';
  final int _pendingHomework = 2;
  final String _lastResult = 'A (85%)';

  // Recent circulars
  final List<Map<String, dynamic>> _circulars = [
    {'title': 'Annual Day Celebration', 'date': '15 Nov 2024', 'category': 'Event'},
    {'title': 'Winter Vacation Notice', 'date': '20 Nov 2024', 'category': 'Holiday'},
    {'title': 'PTM Schedule', 'date': '25 Nov 2024', 'category': 'Meeting'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await _authService.getCurrentUsername();
    if (mounted) setState(() => _parentName = username ?? 'Parent');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: _buildSidebar(context),
      body: FadeTransition(
        opacity: _fadeController,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildChildInfoCard(),
                  const SizedBox(height: 20),
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  ERPSectionHeader(
                    title: 'Recent Circulars',
                    icon: Icons.campaign_outlined,
                    actionLabel: 'View All',
                    onAction: () => context.go('/school/circulars'),
                  ),
                  ..._circulars.map((c) => _buildCircularCard(c)),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFDB2777),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                        ),
                        child: const Icon(Icons.family_restroom, size: 30, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $_parentName 👋',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Parent Portal',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
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
                        child: const Text(
                          'SCHOOL',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDB2777).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.child_care, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _childName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_childClass • $_admissionNo',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Attendance',
                value: '${_attendance.toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => context.go('/school/attendance'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Fees Due',
                value: _pendingFees,
                icon: Icons.payment_outlined,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => context.go('/school/fees'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Homework Due',
                value: '$_pendingHomework',
                icon: Icons.assignment_outlined,
                color: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFFFEE2E2),
                onTap: () => context.go('/school/homework'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Last Result',
                value: _lastResult,
                icon: Icons.grade_outlined,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign_outlined, color: Color(0xFF8B5CF6), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['title'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 4),
                Text(
                  c['date'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              c['category'] as String,
              style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.family_restroom, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_parentName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Parent', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              _buildDrawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
              _buildDrawerItem(Icons.check_circle_outline, 'Attendance', () => context.go('/school/attendance')),
              _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
              _buildDrawerItem(Icons.payment_outlined, 'Fees', () => context.go('/school/fees')),
              _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
              _buildDrawerItem(Icons.directions_bus_outlined, 'Transport', () => context.go('/school/transport')),
              _buildDrawerItem(Icons.grade_outlined, 'Results', () => context.go('/school/report-card')),
              const Spacer(),
              const Divider(color: Colors.white24),
              _buildDrawerItem(Icons.logout, 'Logout', () async {
                await _authService.logout();
                if (mounted) context.go('/login');
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }
}

