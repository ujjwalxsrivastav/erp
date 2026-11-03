import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../core/widgets/erp_section_header.dart';
import '../../../core/widgets/erp_stat_card.dart';

class SchoolParentDashboard extends StatefulWidget {
  const SchoolParentDashboard({super.key});

  @override
  State<SchoolParentDashboard> createState() => _SchoolParentDashboardState();
}

class _SchoolParentDashboardState extends State<SchoolParentDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();
  late AnimationController _fadeController;

  String _parentName = 'Parent';
  bool _isLoading = true;
  String? _errorMessage;

  // Children state
  List<Map<String, dynamic>> _children = [];
  int _selectedChildIndex = 0;

  // Child dynamic stats
  double _attendance = 92.5;
  String _pendingFees = '₹0';
  int _pendingHomework = 0;
  String _lastResult = 'A1 (94%)';

  // Child leaves & circulars
  List<Map<String, dynamic>> _recentLeaves = [];
  List<Map<String, dynamic>> _circulars = [];

  static const Color _accent = Color(0xFFDB2777);
  static const Color _accentDeep = Color(0xFFBE185D);
  static const Color _accentSoft = Color(0xFFF472B6);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _currentChild =>
      _children.isNotEmpty && _selectedChildIndex < _children.length
          ? _children[_selectedChildIndex]
          : null;

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = await _authService.getCurrentUsername();
      _parentName = username ?? 'parent1';

      final kids = await _schoolService.getParentChildren(_parentName);
      _children = kids;

      if (_children.isNotEmpty) {
        await _loadSelectedChildData(_children[_selectedChildIndex]);
      }

      final circs = await _schoolService.getCirculars();
      _circulars = circs.take(3).map((c) => {
        'title': c['title']?.toString() ?? 'Notice',
        'date': c['published_at']?.toString() ?? 'Recent',
        'category': c['category']?.toString() ?? 'General',
      }).toList();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load parent dashboard data. Please tap retry.';
        });
      }
    }
  }

  Future<void> _loadSelectedChildData(Map<String, dynamic> child) async {
    final studentId = child['username']?.toString() ?? child['id']?.toString() ?? '';
    final classId = child['class_id']?.toString() ??
        ((child['class_name']?.toString().toLowerCase().contains('9') ?? false) ? 'cls-9a' : 'cls-10a');

    final metrics = await _schoolService.getChildDashboardMetrics(
      studentId: studentId,
      classId: classId,
    );

    final leaves = await _schoolService.getStudentLeaves(studentId: studentId);

    if (mounted) {
      setState(() {
        _attendance = (metrics['attendance'] as num?)?.toDouble() ?? 92.5;
        _pendingFees = metrics['pendingFeesDisplay']?.toString() ?? '₹0';
        _pendingHomework = (metrics['pendingHomework'] as num?)?.toInt() ?? 0;
        _lastResult = metrics['lastResult']?.toString() ?? 'A1 (94%)';
        _recentLeaves = leaves.take(3).toList();
      });
    }
  }

  void _onChildChanged(int index) {
    if (index == _selectedChildIndex || index >= _children.length) return;
    setState(() {
      _selectedChildIndex = index;
    });
    _loadSelectedChildData(_children[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildSidebar(context),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground()),
          Positioned.fill(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : FadeTransition(
                        opacity: _fadeController,
                        child: RefreshIndicator(
                          onRefresh: _loadInitialData,
                          color: _accent,
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            slivers: [
                              _buildAppBar(),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    // 1. Multi-child selector pills
                                    if (_children.length > 1) ...[
                                      _buildChildSwitcher(),
                                      const SizedBox(height: 16),
                                    ],

                                    // 2. Active child profile card
                                    _buildChildInfoCard(),
                                    const SizedBox(height: 18),

                                    // 3. Quick Action Buttons
                                    _buildQuickActionButtons(),
                                    const SizedBox(height: 18),

                                    // 4. Live Child Metrics Grid
                                    _buildStatsGrid(),
                                    const SizedBox(height: 22),

                                    // 5. Instant Alerts Bar
                                    _buildInstantAlertsCard(),
                                    const SizedBox(height: 22),

                                    // 6. Recent Leaves & Requests
                                    _buildRecentLeavesSection(),
                                    const SizedBox(height: 22),

                                    // 7. Recent Circulars
                                    ERPSectionHeader(
                                      title: 'School Circulars & Notices',
                                      icon: Icons.campaign_outlined,
                                      actionLabel: 'View All',
                                      onAction: () => context.go('/school/circulars'),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_circulars.isEmpty)
                                      _buildEmptyCard('No circulars published for today.')
                                    else
                                      ..._circulars.map((c) => _buildCircularCard(c)),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _accent),
          SizedBox(height: 16),
          Text(
            'Connecting to Shivalik Student Ledger...',
            style: TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 54, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSwitcher() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_children.length, (idx) {
          final isSelected = idx == _selectedChildIndex;
          final c = _children[idx];
          final name = c['name']?.toString() ?? 'Child';
          final className = c['class_name']?.toString() ?? 'Class';

          return Expanded(
            child: InkWell(
              onTap: () => _onChildChanged(idx),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [_accentDeep, _accent],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$name ($className)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF2F8), Color(0xFFFFF1F2), Color(0xFFF5F3FF)],
        ),
      ),
      child: Stack(
        children: [
          _buildOrb(top: -90, right: -70, size: 280, color: _accent),
          _buildOrb(top: 330, left: -110, size: 260, color: const Color(0xFF8B5CF6)),
          _buildOrb(bottom: -80, right: -60, size: 240, color: const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildOrb({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _accentDeep,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9D174D), Color(0xFFDB2777), Color(0xFFF472B6)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GlassPanel(
                        padding: const EdgeInsets.all(14),
                        borderRadius: 22,
                        blur: 16,
                        shadowOpacity: 0.14,
                        gradientColors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                        borderColor: Colors.white.withValues(alpha: 0.38),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.family_restroom, size: 28, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, $_parentName 👋',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Shivalik International School — Parent Portal',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
                                ),
                              ),
                              child: const Text(
                                'CBSE K-12',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildChildInfoCard() {
    final child = _currentChild;
    final name = child?['name']?.toString() ?? 'Aarav Sharma';
    final className = child?['class_name']?.toString() ?? 'Class 10';
    final section = child?['section']?.toString() ?? 'A';
    final rollNo = child?['roll_no']?.toString() ?? child?['admission_number']?.toString() ?? 'SCH2026-10A';
    final relation = child?['relation']?.toString() ?? 'Parent';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.school, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$className-$section • Roll: $rollNo',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Linked as: $relation • Active Session 2025-26',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.go('/school/report-card'),
                tooltip: 'View Report Card',
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            icon: Icons.event_note,
            label: 'Apply Leave',
            color: const Color(0xFF0F766E),
            onTap: _showApplyLeaveDialog,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionBtn(
            icon: Icons.calendar_month,
            label: 'Book PTM',
            color: const Color(0xFF6366F1),
            onTap: _showBookPtmDialog,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionBtn(
            icon: Icons.report_problem_outlined,
            label: 'Grievance',
            color: const Color(0xFFE11D48),
            onTap: _showFileComplaintDialog,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionBtn(
            icon: Icons.menu_book,
            label: 'LMS-Lite',
            color: const Color(0xFFD97706),
            onTap: _showLmsMaterialsModal,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                value: '${_attendance.toStringAsFixed(1)}%',
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
                title: 'Latest Result',
                value: _lastResult,
                icon: Icons.grade_outlined,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
                onTap: () => context.go('/school/report-card'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstantAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, color: Color(0xFF0F766E), size: 20),
              SizedBox(width: 8),
              Text(
                'Live Student & Safety Alerts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            icon: Icons.directions_bus,
            title: 'School Transport Live',
            subtitle: 'Bus UK-07-PA-1024 on Rajpur Road route (ETA 12 mins). Tap to view live stops.',
            color: const Color(0xFF0284C7),
            onTap: () => context.go('/school/transport'),
          ),
          const Divider(height: 16),
          _buildAlertItem(
            icon: Icons.assignment_turned_in,
            title: 'Class Homework Assigned',
            subtitle: 'Science & Mathematics worksheets pending submission before Friday.',
            color: const Color(0xFFD97706),
            onTap: () => context.go('/school/homework'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLeavesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ERPSectionHeader(
          title: 'Student Leave Applications',
          icon: Icons.event_available,
          actionLabel: '+ New Leave',
          onAction: _showApplyLeaveDialog,
        ),
        const SizedBox(height: 8),
        if (_recentLeaves.isEmpty)
          _buildEmptyCard('No leave applications filed for this child.')
        else
          ..._recentLeaves.map((l) => _buildLeaveCard(l)),
      ],
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> l) {
    final status = l['status']?.toString() ?? 'pending';
    final isApproved = status.toLowerCase().contains('approved');
    final isRejected = status.toLowerCase().contains('rejected');
    final statusColor = isApproved
        ? const Color(0xFF059669)
        : isRejected
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isApproved
                  ? const Color(0xFFECFDF5)
                  : isRejected
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isApproved
                  ? Icons.check_circle
                  : isRejected
                      ? Icons.cancel
                      : Icons.hourglass_top,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l['type']} (${l['start_date']} to ${l['end_date']})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                Text(
                  'Reason: ${l['reason']}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isApproved
                  ? const Color(0xFFDCFCE7)
                  : isRejected
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isApproved
                  ? 'Approved'
                  : isRejected
                      ? 'Rejected'
                      : 'Pending',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularCard(Map<String, dynamic> c) {
    return _GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      blur: 14,
      shadowOpacity: 0.06,
      gradientColors: [
        Colors.white.withValues(alpha: 0.85),
        const Color(0xFF8B5CF6).withValues(alpha: 0.08),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.campaign_outlined, color: Color(0xFF8B5CF6), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (c['title']?.toString() ?? 'Notice'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (c['date']?.toString() ?? 'Recent'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.18)),
            ),
            child: Text(
              (c['category']?.toString() ?? 'General'),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  // ===== DIALOGS =====

  void _showApplyLeaveDialog() {
    final child = _currentChild;
    final studentId = child?['username']?.toString() ?? child?['id']?.toString() ?? 'sstudent1';
    final studentName = child?['name']?.toString() ?? 'Aarav Sharma';
    final classId = child?['class_id']?.toString() ?? 'cls-10a';

    final reasonCtrl = TextEditingController();
    String leaveType = 'Medical Leave';
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.event_note, color: _accent),
              const SizedBox(width: 8),
              Text('Apply Leave: $studentName', style: const TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: leaveType,
                  decoration: const InputDecoration(labelText: 'Leave Category'),
                  items: const [
                    DropdownMenuItem(value: 'Medical Leave', child: Text('Medical Leave')),
                    DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
                    DropdownMenuItem(value: 'Family Function', child: Text('Family Function')),
                  ],
                  onChanged: (v) => setDlgState(() => leaveType = v ?? leaveType),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('From: ${startDate.toIso8601String().split('T')[0]}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (picked != null) setDlgState(() => startDate = picked);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('To: ${endDate.toIso8601String().split('T')[0]}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (picked != null) setDlgState(() => endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Leave',
                    hintText: 'Enter reason or medical condition...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _schoolService.applyStudentLeave(
                  studentId: studentId,
                  studentName: studentName,
                  classId: classId,
                  startDate: startDate.toIso8601String().split('T')[0],
                  endDate: endDate.toIso8601String().split('T')[0],
                  leaveType: leaveType,
                  reason: reasonCtrl.text.trim(),
                  documentUrl: 'Self-Certified by Parent $_parentName',
                  className: child?['class_name']?.toString(),
                  section: child?['section']?.toString(),
                  appliedBy: _parentName,
                  appliedByRole: 'parent',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leave request submitted to Class Teacher for approval!'),
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                  if (_currentChild != null) {
                    _loadSelectedChildData(_currentChild!);
                  }
                }
              },
              child: const Text('Submit Application', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookPtmDialog() {
    final child = _currentChild;
    final studentName = child?['name']?.toString() ?? 'Aarav Sharma';
    final agendaCtrl = TextEditingController(text: 'Academic progress and term feedback');
    String teacher = 'Mrs. Sunita Sharma (Class Teacher)';
    String timeSlot = '10:00 AM - 10:15 AM';
    String date = DateTime.now().add(const Duration(days: 3)).toIso8601String().split('T')[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Text('Book PTM Slot', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: teacher,
                  decoration: const InputDecoration(labelText: 'Select Faculty'),
                  items: const [
                    DropdownMenuItem(value: 'Mrs. Sunita Sharma (Class Teacher)', child: Text('Mrs. Sunita Sharma')),
                    DropdownMenuItem(value: 'Mrs. Gupta (Chemistry)', child: Text('Mrs. Gupta (Chemistry)')),
                    DropdownMenuItem(value: 'Ms. Nair (English)', child: Text('Ms. Nair (English)')),
                  ],
                  onChanged: (v) => setDlgState(() => teacher = v ?? teacher),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: timeSlot,
                  decoration: const InputDecoration(labelText: 'Available Slot'),
                  items: const [
                    DropdownMenuItem(value: '09:30 AM - 09:45 AM', child: Text('09:30 AM - 09:45 AM')),
                    DropdownMenuItem(value: '10:00 AM - 10:15 AM', child: Text('10:00 AM - 10:15 AM')),
                    DropdownMenuItem(value: '11:15 AM - 11:30 AM', child: Text('11:15 AM - 11:30 AM')),
                  ],
                  onChanged: (v) => setDlgState(() => timeSlot = v ?? timeSlot),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: agendaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Agenda / Discussion Points',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _schoolService.bookPtmSlot(
                  parentUsername: _parentName,
                  studentName: studentName,
                  teacherName: teacher,
                  date: date,
                  timeSlot: timeSlot,
                  agenda: agendaCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PTM slot booked with $teacher on $date!'),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  );
                }
              },
              child: const Text('Confirm Booking', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileComplaintDialog() {
    final child = _currentChild;
    final studentName = child?['name']?.toString() ?? 'Aarav Sharma';
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Academic';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.report_problem_outlined, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text('Parent Grievance / Query', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Grievance Department'),
                  items: const [
                    DropdownMenuItem(value: 'Academic', child: Text('Academic & Homework')),
                    DropdownMenuItem(value: 'Transport', child: Text('Transport & Bus Route')),
                    DropdownMenuItem(value: 'Finance', child: Text('Fees & Concession')),
                    DropdownMenuItem(value: 'Infrastructure', child: Text('Campus & Safety')),
                  ],
                  onChanged: (v) => setDlgState(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Detailed Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
              onPressed: () async {
                if (subjectCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final res = await _schoolService.fileParentComplaint(
                  parentUsername: _parentName,
                  studentName: studentName,
                  category: category,
                  subject: subjectCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Complaint Registered'),
                      content: Text(
                        'Your grievance has been submitted under Ticket #${res['ticket_no']}. '
                        'The Principal\'s office and Academic Head have been notified.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('File Complaint', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLmsMaterialsModal() {
    final child = _currentChild;
    final className = child?['class_name']?.toString() ?? 'Class 10';
    final classId = child?['class_id']?.toString() ??
        (className.toLowerCase().contains('9') ? 'cls-9a' : 'cls-10a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => FutureBuilder<List<Map<String, dynamic>>>(
          future: _schoolService.getStudyMaterials(classId: classId),
          builder: (ctx, snapshot) {
            final materials = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Text(
                        'LMS-Lite: $className Study Materials',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Class-restricted syllabus notes, formulas, and online MCQ quizzes.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ...materials.map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFEF3C7),
                            child: Icon(Icons.picture_as_pdf, color: Color(0xFFD97706), size: 20),
                          ),
                          title: Text(
                            m['title']?.toString() ?? 'Study Guide',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Subject: ${m['subject']} • By ${m['uploaded_by']}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.download_rounded, color: Color(0xFF0F766E)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Downloading ${m['title']}...')),
                              );
                            },
                          ),
                        ),
                      )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF9D174D).withValues(alpha: 0.94),
                  _accent.withValues(alpha: 0.89),
                  _accentSoft.withValues(alpha: 0.86),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: _GlassPanel(
                      padding: const EdgeInsets.all(14),
                      borderRadius: 20,
                      blur: 12,
                      shadowOpacity: 0,
                      gradientColors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                      borderColor: Colors.white.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.20),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.family_restroom, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _parentName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Parent Portal',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
                  _buildDrawerItem(Icons.check_circle_outline, 'Attendance', () => context.go('/school/attendance')),
                  _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
                  _buildDrawerItem(Icons.payment_outlined, 'Fees & Receipts', () => context.go('/school/fees')),
                  _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
                  _buildDrawerItem(Icons.directions_bus_outlined, 'Transport & Bus', () => context.go('/school/transport')),
                  _buildDrawerItem(Icons.grade_outlined, 'Report Cards', () => context.go('/school/report-card')),
                  _buildDrawerItem(Icons.calendar_today_outlined, 'Timetable', () => context.go('/school/timetable')),
                  _buildDrawerItem(Icons.local_library_outlined, 'Library', () => context.go('/school/library')),
                  _buildDrawerItem(Icons.card_membership_outlined, 'Certificates', () => context.go('/school/certificates')),
                  const Spacer(),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(Icons.logout, 'Logout', () async {
                    await _authService.logout();
                    if (mounted) context.go('/login');
                  }),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Frosted glass surface used by the School dashboards.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 22,
    this.blur = 18,
    this.gradientColors,
    this.borderColor,
    this.shadowOpacity = 0.10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF334155).withValues(alpha: shadowOpacity),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ??
                    [
                      Colors.white.withValues(alpha: 0.78),
                      Colors.white.withValues(alpha: 0.46),
                    ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.75),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
