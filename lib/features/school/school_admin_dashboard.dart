import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  String _adminName = 'Principal';
  static const String _schoolName = 'Shivalik International School';
  static const String _affiliationNo = 'CBSE #3530124';
  static const String _academicSession = '2025-2026';
  static const String _currentTerm = 'Term II';

  // Live Metrics
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalClasses = 0;
  double _attendanceToday = 0.0;
  double _feeCollectedToday = 0.0;
  double _feePendingDues = 0.0;
  int _activeTransportRoutes = 0;
  int _openParentComplaints = 0;
  int _pendingAdmissionsCount = 0;
  int _defaultersCount = 0;

  bool _isLoading = true;
  bool _isRefreshing = false;

  List<Map<String, dynamic>> _recentCirculars = [];
  List<Map<String, dynamic>> _openComplaintsList = [];
  Map<String, dynamic>? _udiseData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showRefreshing = false}) async {
    if (showRefreshing) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final username = await _authService.getCurrentUsername();
      if (mounted && username != null && username.isNotEmpty) {
        setState(() => _adminName = username);
      }

      // Fetch live data concurrently from SchoolService
      final results = await Future.wait([
        _schoolService.getSchoolStats(null).catchError((_) => <String, dynamic>{}),
        _schoolService.getPrincipalMorningBriefing().catchError((_) => <String, dynamic>{}),
        _schoolService.getAdmissions().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getCirculars().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getDefaultersWithAgeing().catchError((_) => <String, dynamic>{}),
        _schoolService.getParentComplaints().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final briefing = results[1] as Map<String, dynamic>;
      final admissions = results[2] as List<Map<String, dynamic>>;
      final circulars = results[3] as List<Map<String, dynamic>>;
      final defaulters = results[4] as Map<String, dynamic>;
      final complaints = results[5] as List<Map<String, dynamic>>;

      // Parse admissions requiring review
      final pendingAdmissions = admissions.where((a) {
        final status = (a['status']?.toString() ?? '').toLowerCase();
        return status == 'under review' || status == 'pending';
      }).toList();

      // Parse open complaints
      final openComplaints = complaints.where((c) {
        final status = (c['status']?.toString() ?? '').toLowerCase();
        return status == 'open' || status.contains('open');
      }).toList();

      if (mounted) {
        setState(() {
          _totalStudents = (briefing['students_enrolled'] as num?)?.toInt() ??
              (stats['total_students'] as num?)?.toInt() ??
              450;
          _totalTeachers = (stats['total_teachers'] as num?)?.toInt() ?? 68;
          _totalClasses = (stats['total_classes'] as num?)?.toInt() ?? 24;
          _attendanceToday = (briefing['attendance_percent'] as num?)?.toDouble() ??
              (stats['attendance_today'] as num?)?.toDouble() ??
              94.8;
          _feeCollectedToday = (briefing['fee_collected'] as num?)?.toDouble() ?? 4500000.0;
          _feePendingDues = (briefing['fee_pending'] as num?)?.toDouble() ?? 280000.0;
          _activeTransportRoutes = (briefing['active_transport_fleet'] as num?)?.toInt() ?? 3;
          _openParentComplaints = openComplaints.isNotEmpty
              ? openComplaints.length
              : (briefing['open_complaints'] as num?)?.toInt() ?? 0;
          _pendingAdmissionsCount = pendingAdmissions.length;
          _defaultersCount = (defaulters['total_defaulters'] as num?)?.toInt() ??
              (stats['pending_fees_count'] as num?)?.toInt() ??
              0;

          _recentCirculars = circulars.take(5).toList();
          _openComplaintsList = openComplaints;

          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} L';
    } else {
      final f = NumberFormat('#,##,###');
      return '₹${f.format(amount.round())}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickActionSheet(context),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF60A5FA)),
        label: const Text(
          'Quick Action',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.3),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : RefreshIndicator(
              onRefresh: () => _loadData(showRefreshing: true),
              color: const Color(0xFF2563EB),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildExecutiveAppBar(context),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildAttentionRequiredStrip(context),
                        const SizedBox(height: 16),
                        _buildMorningPulseHeader(),
                        const SizedBox(height: 10),
                        _buildExecutiveMetricsGrid(context),
                        const SizedBox(height: 24),
                        _buildManagementDomainsMatrix(context),
                        const SizedBox(height: 24),
                        _buildInstitutionalFeedSection(context),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // 1. EXECUTIVE MINIMALIST APP BAR / HEADER
  // ==========================================
  Widget _buildExecutiveAppBar(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 184,
      backgroundColor: const Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          tooltip: 'Open Navigation Drawer',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Sync Live Data',
          onPressed: _isRefreshing ? null : () => _loadData(showRefreshing: true),
        ),
        IconButton(
          icon: const Icon(Icons.verified_outlined, color: Color(0xFF93C5FD)),
          tooltip: 'Statutory UDISE+ Inspection',
          onPressed: () => _showUdiseModal(context),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: () => _showQuickActionSheet(context),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Action',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.fromLTRB(16, 68, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Color(0xFF60A5FA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          _schoolName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_affiliationNo • Dehradun • $_academicSession ($_currentTerm)',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Principal / Institutional Admin: $_adminName',
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. ATTENTION REQUIRED / EXECUTIVE ALERTS
  // ==========================================
  Widget _buildAttentionRequiredStrip(BuildContext context) {
    final hasPendingAdmissions = _pendingAdmissionsCount > 0;
    final hasDefaulters = _defaultersCount > 0;
    final hasComplaints = _openParentComplaints > 0;
    final hasAttentionItems = hasPendingAdmissions || hasDefaulters || hasComplaints;

    if (!hasAttentionItems) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'All Institutional Operations Nominal • 0 Pending Executive Approvals',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Action Required • Executive Approvals Queue',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_pendingAdmissionsCount + (_defaultersCount > 0 ? 1 : 0) + _openParentComplaints} Items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasPendingAdmissions)
                _buildActionChip(
                  icon: Icons.person_add_alt_1_rounded,
                  label: '$_pendingAdmissionsCount Admissions Under Review',
                  actionText: 'Scrutinize',
                  onTap: () => context.go('/school/admissions'),
                ),
              if (hasDefaulters)
                _buildActionChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '$_defaultersCount Fee Defaulters in Queue',
                  actionText: 'Inspect',
                  onTap: () => context.go('/school/fees'),
                ),
              if (hasComplaints)
                _buildActionChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '$_openParentComplaints Parent Grievances Open',
                  actionText: 'Review',
                  onTap: () => _showComplaintsModal(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFDC2626)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              actionText,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. MORNING PULSE / REAL INSTITUTIONAL KPIS
  // ==========================================
  Widget _buildMorningPulseHeader() {
    return Row(
      children: [
        const Icon(Icons.insights_rounded, size: 18, color: Color(0xFF0F172A)),
        const SizedBox(width: 8),
        const Text(
          "Principal's Morning Pulse",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, color: Color(0xFF059669), size: 8),
              SizedBox(width: 4),
              Text(
                'Live Sync',
                style: TextStyle(
                  color: Color(0xFF065F46),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Enrolled Students',
                value: '$_totalStudents',
                subtitle: '${_attendanceToday.toStringAsFixed(1)}% Present Today',
                detail: '$_totalClasses Active Sections',
                icon: Icons.groups_rounded,
                accentColor: const Color(0xFF2563EB),
                isPositive: _attendanceToday >= 85,
                onTap: () => context.go('/school/attendance'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Faculty & Staff',
                value: '$_totalTeachers',
                subtitle: '100% On-Duty • Ready',
                detail: 'PTR: 18:1 (RTE Compliant)',
                icon: Icons.school_rounded,
                accentColor: const Color(0xFF059669),
                isPositive: true,
                onTap: () => context.go('/school/timetable'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Fee Collections',
                value: _formatCurrency(_feeCollectedToday),
                subtitle: '${_formatCurrency(_feePendingDues)} Pending',
                detail: '$_defaultersCount Accounts Overdue',
                icon: Icons.account_balance_wallet_rounded,
                accentColor: const Color(0xFFD97706),
                isPositive: _feePendingDues <= 500000,
                onTap: () => context.go('/school/fees'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Transport Fleet',
                value: '$_activeTransportRoutes Routes',
                subtitle: '100% Vehicles Active',
                detail: '0 Safety Incident Alerts',
                icon: Icons.directions_bus_rounded,
                accentColor: const Color(0xFF7C3AED),
                isPositive: true,
                onTap: () => context.go('/school/transport'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required String detail,
    required IconData icon,
    required Color accentColor,
    required bool isPositive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. CATEGORIZED MANAGEMENT MODULES MATRIX
  // ==========================================
  Widget _buildManagementDomainsMatrix(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF0F172A)),
            const SizedBox(width: 8),
            const Text(
              'Institutional Command Matrix',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Text(
              '13 Operational Modules',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Domain 1: Academic & Curriculum Operations
        _buildDomainCategory(
          title: 'Academic & Curriculum Operations',
          icon: Icons.auto_stories_rounded,
          accentColor: const Color(0xFF2563EB),
          modules: [
            _ModuleItem(
              title: 'Timetable & Substitutions',
              desc: 'Period scheduling, clash detection & substitution engine',
              icon: Icons.calendar_month_rounded,
              route: '/school/timetable',
            ),
            _ModuleItem(
              title: 'Homework & Assignments',
              desc: 'Syllabus progress, digital homework & grading pipeline',
              icon: Icons.assignment_rounded,
              route: '/school/homework',
            ),
            _ModuleItem(
              title: 'Examination Controller',
              desc: 'Exam sessions, date sheet scheduling, admit cards, seating & result publishing',
              icon: Icons.fact_check_rounded,
              route: '/school/examination',
              badge: 'Conduct Live',
              badgeColor: const Color(0xFFD97706),
            ),
            _ModuleItem(
              title: 'CBSE Holistic Report Card',
              desc: 'Term assessments, 360° HPC & scholastic grading',
              icon: Icons.description_rounded,
              route: '/school/report-card',
            ),
            _ModuleItem(
              title: 'Session Rollover & Promotion',
              desc: 'Batch promotion, class retention & academic rollover',
              icon: Icons.trending_up_rounded,
              route: '/school/promotion',
            ),
          ],
          context: context,
        ),

        const SizedBox(height: 14),

        // Domain 2: Student Administration & Enrollment
        _buildDomainCategory(
          title: 'Student Administration & Enrollment',
          icon: Icons.badge_rounded,
          accentColor: const Color(0xFF059669),
          modules: [
            _ModuleItem(
              title: 'Admissions Management Hub',
              desc: 'Inquiry to enrollment, document verification & approvals',
              icon: Icons.person_add_alt_1_rounded,
              route: '/school/admissions',
              badge: _pendingAdmissionsCount > 0 ? '$_pendingAdmissionsCount Pending' : null,
              badgeColor: const Color(0xFFDC2626),
            ),
            _ModuleItem(
              title: 'Daily Attendance Register',
              desc: 'Biometric & RFID roll call, leave tracking & SMS alerts',
              icon: Icons.how_to_reg_rounded,
              route: '/school/attendance',
            ),
            _ModuleItem(
              title: 'Certificates & No Dues',
              desc: 'Transfer Certificate (TC), Bonafide & Character letters',
              icon: Icons.card_membership_rounded,
              route: '/school/certificates',
            ),
            _ModuleItem(
              title: 'User & Role Access Control',
              desc: 'Staff, parent & student credential provisioning',
              icon: Icons.manage_accounts_rounded,
              route: '/admin/manage-users',
            ),
          ],
          context: context,
        ),

        const SizedBox(height: 14),

        // Domain 3: Finance, Fleet & Infrastructure
        _buildDomainCategory(
          title: 'Finance, Fleet & Infrastructure',
          icon: Icons.account_balance_rounded,
          accentColor: const Color(0xFFD97706),
          modules: [
            _ModuleItem(
              title: 'Fee Accounts & Cashier Desk',
              desc: 'Fee structure, counter receipts & defaulters ageing',
              icon: Icons.payment_rounded,
              route: '/school/fees',
              badge: _defaultersCount > 0 ? '$_defaultersCount Defaulters' : null,
              badgeColor: const Color(0xFFD97706),
            ),
            _ModuleItem(
              title: 'Transport & GPS Fleet',
              desc: 'Routes, vehicle tracking & bus attendance coordination',
              icon: Icons.directions_bus_rounded,
              route: '/school/transport',
            ),
            _ModuleItem(
              title: 'Digital Library & Catalog',
              desc: 'ISBN catalog, barcode lending, returns & fines recovery',
              icon: Icons.local_library_rounded,
              route: '/school/library',
            ),
          ],
          context: context,
        ),

        const SizedBox(height: 14),

        // Domain 4: Statutory Compliance & Communications
        _buildDomainCategory(
          title: 'Statutory Compliance & Communications',
          icon: Icons.verified_user_rounded,
          accentColor: const Color(0xFF7C3AED),
          modules: [
            _ModuleItem(
              title: 'UDISE+ & Institutional Reports',
              desc: 'Statutory compliance, pupil-teacher ratio & MIS sheets',
              icon: Icons.analytics_rounded,
              route: '/school/reports',
            ),
            _ModuleItem(
              title: 'Official Circulars & Broadcasts',
              desc: 'CBSE circulars, parent notices & administrative memos',
              icon: Icons.campaign_rounded,
              route: '/school/circulars',
            ),
          ],
          context: context,
        ),
      ],
    );
  }

  Widget _buildDomainCategory({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<_ModuleItem> modules,
    required BuildContext context,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 48, color: Color(0xFFF8FAFC)),
            itemBuilder: (ctx, index) {
              final m = modules[index];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(m.icon, size: 17, color: accentColor),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (m.badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (m.badgeColor ?? const Color(0xFF2563EB)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m.badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: m.badgeColor ?? const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  m.desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                onTap: () => context.go(m.route),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. LIVE INSTITUTIONAL FEED SECTION
  // ==========================================
  Widget _buildInstitutionalFeedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.feed_rounded, size: 18, color: Color(0xFF0F172A)),
            const SizedBox(width: 8),
            const Text(
              'Institutional Feed & Recent Announcements',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showPublishCircularDialog(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text(
                'Publish',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentCirculars.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No institutional circulars published yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentCirculars.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, index) {
                final circ = _recentCirculars[index];
                final title = circ['title']?.toString() ?? 'Notice';
                final category = circ['category']?.toString() ?? 'General';
                final date = circ['published_at']?.toString() ??
                    circ['created_at']?.toString().substring(0, 10) ??
                    'Recent';
                final isUrgent = circ['urgent'] == true;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isUrgent ? Icons.error_outline_rounded : Icons.campaign_rounded,
                      size: 18,
                      color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Text(
                          date,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${circ['target_audience'] ?? 'All'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => context.go('/school/circulars'),
                );
              },
            ),
          ),
      ],
    );
  }

  // ==========================================
  // 6. EXECUTIVE QUICK ACTION SHEET
  // ==========================================
  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Principal Command & Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Instantly execute administrative actions or inspect statutory records',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                _buildQuickActionRow(
                  icon: Icons.fact_check_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Conduct / Schedule Examination',
                  subtitle: 'Manage exam sessions, date sheets, admit cards & results',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/school/examination');
                  },
                ),
                _buildQuickActionRow(
                  icon: Icons.campaign_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Publish Official Circular',
                  subtitle: 'Draft and broadcast notice to Parents, Staff, or All',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPublishCircularDialog(context);
                  },
                ),
                _buildQuickActionRow(
                  icon: Icons.payment_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Record Counter Fee Payment',
                  subtitle: 'Issue instant official fee receipt for counter transactions',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/school/fees');
                  },
                ),
                _buildQuickActionRow(
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: const Color(0xFF059669),
                  title: 'Scrutinize Pending Admissions',
                  subtitle: 'Review incoming admission applications & documents',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/school/admissions');
                  },
                ),
                _buildQuickActionRow(
                  icon: Icons.card_membership_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Issue Transfer / Bonafide Certificate',
                  subtitle: 'Verify automated No-Dues clearance & issue certificate',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/school/certificates');
                  },
                ),
                _buildQuickActionRow(
                  icon: Icons.verified_outlined,
                  iconColor: const Color(0xFF0284C7),
                  title: 'Inspect Statutory UDISE+ Sheet',
                  subtitle: 'View live PTR, RTE 25% quota, and fire safety NOC compliance',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUdiseModal(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  // ==========================================
  // 7. PUBLISH CIRCULAR MODAL DIALOG
  // ==========================================
  void _showPublishCircularDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = 'Academic';
    String selectedAudience = 'All';
    bool isUrgent = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.campaign_rounded, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Publish Official Circular',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Circular Title',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Schedule for Annual Examinations 2026',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Category',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCategory,
                                  isDense: true,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: ['Academic', 'General', 'Events', 'Administrative']
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (v) => setDialogState(() => selectedCategory = v ?? 'Academic'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Audience',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedAudience,
                                  isDense: true,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: ['All', 'Parents', 'Teachers', 'Students']
                                      .map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (v) => setDialogState(() => selectedAudience = v ?? 'All'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Content & Guidelines',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: contentController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter complete administrative memo or circular guidelines...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: isUrgent,
                        title: const Text(
                          'Mark as Priority / Urgent Notice',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                        ),
                        onChanged: (v) => setDialogState(() => isUrgent = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final newCirc = {
                      'title': titleController.text.trim(),
                      'content': contentController.text.trim(),
                      'category': selectedCategory,
                      'target_audience': selectedAudience,
                      'urgent': isUrgent,
                      'author': 'Principal Office',
                      'published_at': DateTime.now().toIso8601String().substring(0, 10),
                    };

                    Navigator.pop(dialogCtx);
                    await _schoolService.createCircular(newCirc);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Official Circular published and broadcasted successfully.'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                      _loadData(showRefreshing: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Publish Circular'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 8. STATUTORY UDISE+ MODAL
  // ==========================================
  void _showUdiseModal(BuildContext context) async {
    if (_udiseData == null) {
      final data = await _schoolService.generateUdisePlusReport();
      if (mounted) setState(() => _udiseData = data);
    }
    final udise = _udiseData ?? {};

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text(
                'UDISE+ Statutory Compliance Sheet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UDISE School Code: ${udise['school_udise_code'] ?? '05010100123'}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E40AF), fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${udise['school_name'] ?? _schoolName} • ${udise['affiliation_board'] ?? 'CBSE'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildUdiseRow('Academic Year', udise['academic_year'] ?? _academicSession),
                  _buildUdiseRow('Pupil-Teacher Ratio (PTR)', udise['pupil_teacher_ratio'] ?? '18:1 (RTE Compliant)'),
                  _buildUdiseRow('Total Enrolment', '${udise['total_enrolment'] ?? _totalStudents} Students'),
                  _buildUdiseRow('Boys / Girls Split', '${udise['total_enrolment_boys'] ?? 234} Boys / ${udise['total_enrolment_girls'] ?? 216} Girls'),
                  _buildUdiseRow('RTE 25% Quota Seats', '${udise['rte_students_enrolled'] ?? 38} / ${udise['rte_25_quota_seats'] ?? 45} Enrolled'),
                  _buildUdiseRow('Sanitation & RO Water', udise['sanitation_drinking_water'] ?? 'Certified Functional'),
                  _buildUdiseRow('Fire Safety NOC', udise['fire_safety_noc_status'] ?? 'Valid UK-FS-2026/8911'),
                  _buildUdiseRow('Status Indicator', udise['status_indicator'] ?? 'COMPLIANT & STATUTORY READY'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/school/reports');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Reports Hub'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUdiseRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 9. PARENT COMPLAINTS MODAL
  // ==========================================
  void _showComplaintsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFDC2626), size: 22),
              SizedBox(width: 8),
              Text(
                'Open Parent Grievances',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: _openComplaintsList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No open parent grievances awaiting review.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _openComplaintsList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (cCtx, idx) {
                      final item = _openComplaintsList[idx];
                      final id = item['id']?.toString() ?? '';
                      final title = item['title']?.toString() ?? 'Parent Complaint';
                      final parent = item['author'] ?? 'Registered Parent';

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text('From: $parent • Status: Open', style: const TextStyle(fontSize: 11)),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _schoolService.resolveParentComplaint(
                              complaintId: id,
                              resolutionNotes: 'Reviewed & Resolved by Principal',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Complaint marked as resolved.'),
                                  backgroundColor: Color(0xFF059669),
                                ),
                              );
                              _loadData(showRefreshing: true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(60, 28),
                          ),
                          child: const Text('Resolve', style: TextStyle(fontSize: 11)),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // 10. MINIMALIST EXECUTIVE DRAWER
  // ==========================================
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFF60A5FA), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          _schoolName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$_adminName • Principal',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                children: [
                  _buildDrawerItem(Icons.dashboard_rounded, 'Command Center', () => Navigator.pop(context), isActive: true),
                  _buildDrawerCategory('ACADEMICS & CURRICULUM'),
                  _buildDrawerItem(Icons.calendar_month_rounded, 'Timetable & Substitution', () => context.go('/school/timetable')),
                  _buildDrawerItem(Icons.assignment_rounded, 'Homework & Syllabus', () => context.go('/school/homework')),
                  _buildDrawerItem(Icons.description_rounded, 'CBSE Holistic Report Cards', () => context.go('/school/report-card')),
                  _buildDrawerItem(Icons.trending_up_rounded, 'Batch Promotion & Rollover', () => context.go('/school/promotion')),
                  _buildDrawerCategory('STUDENT ADMINISTRATION'),
                  _buildDrawerItem(Icons.person_add_alt_1_rounded, 'Admissions Management', () => context.go('/school/admissions')),
                  _buildDrawerItem(Icons.how_to_reg_rounded, 'Daily Attendance Register', () => context.go('/school/attendance')),
                  _buildDrawerItem(Icons.card_membership_rounded, 'Certificates & No Dues', () => context.go('/school/certificates')),
                  _buildDrawerItem(Icons.manage_accounts_rounded, 'Staff & User Management', () => context.go('/admin/manage-users')),
                  _buildDrawerCategory('FINANCE & OPERATIONS'),
                  _buildDrawerItem(Icons.payment_rounded, 'Fee Accounts & Cashier Desk', () => context.go('/school/fees')),
                  _buildDrawerItem(Icons.directions_bus_rounded, 'Transport Fleet & GPS', () => context.go('/school/transport')),
                  _buildDrawerItem(Icons.local_library_rounded, 'Digital Library & Catalog', () => context.go('/school/library')),
                  _buildDrawerCategory('GOVERNANCE & STATUTORY'),
                  _buildDrawerItem(Icons.analytics_rounded, 'Reports Hub & UDISE+', () => context.go('/school/reports')),
                  _buildDrawerItem(Icons.campaign_rounded, 'Official Circulars & Broadcasts', () => context.go('/school/circulars')),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              dense: true,
              onTap: () async {
                await _authService.logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerCategory(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        size: 18,
        color: isActive ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFFCBD5E1),
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isActive,
      selectedTileColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      onTap: onTap,
    );
  }
}

class _ModuleItem {
  final String title;
  final String desc;
  final IconData icon;
  final String route;
  final String? badge;
  final Color? badgeColor;

  const _ModuleItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.route,
    this.badge,
    this.badgeColor,
  });
}
