import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';
import '../../services/school_export_service.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  String _adminName = 'Principal';
  String _schoolName = 'Shivalik International School';
  String _affiliationNo = 'CBSE #3530124';
  String _academicSession = '2025-2026';
  String _currentTerm = 'Term II';

  // Live Metrics
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalClasses = 0;
  double _attendanceToday = 0.0;
  bool _attendanceMarkedToday = false;
  double _feeCollectedToday = 0.0;
  double _feePendingDues = 0.0;
  int _activeTransportRoutes = 0;
  int _openParentComplaints = 0;
  int _pendingAdmissionsCount = 0;
  int _pendingCertificatesCount = 0;
  int _pendingTeacherLeavesCount = 0;
  int _pendingStudentLeavesCount = 0;
  int _defaultersCount = 0;
  Map<String, dynamic> _unifiedApprovals = {
    'items': <Map<String, dynamic>>[],
    'total_count': 0,
    'counts_by_type': <String, int>{},
  };

  // Institutional Analytics (N1, N6, N7, AD-R01 to AD-R06)
  List<Map<String, dynamic>> _enrolmentTrend = [];
  List<Map<String, dynamic>> _feeTrend = [];
  List<Map<String, dynamic>> _attendanceTrend = [];
  List<Map<String, dynamic>> _admissionFunnel = [];
  List<Map<String, dynamic>> _feeHeadDistribution = [];
  List<Map<String, dynamic>> _examPassRates = [];
  bool _analyticsLoading = true;

  // New Features Suite State (N3, N4, N5, N8, N9, N10, N11, N12, N13, N14)
  Map<String, dynamic> _schoolSettings = {};
  List<Map<String, dynamic>> _auditLogs = [];
  List<Map<String, dynamic>> _staffDirectory = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasError = false;
  String? _errorMessage;

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
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final username = await _authService.getCurrentUsername();
      if (mounted && username != null && username.isNotEmpty) {
        setState(() => _adminName = username);
      }

      final instName = await _schoolService.getSchoolInstituteName();
      if (mounted && instName != null && instName.isNotEmpty) {
        setState(() => _schoolName = instName);
      }

      // Fetch live data concurrently from SchoolService
      final results = await Future.wait([
        _schoolService.getSchoolStats(null).catchError((_) => <String, dynamic>{}),
        _schoolService.getPrincipalMorningBriefing().catchError((_) => <String, dynamic>{}),
        _schoolService.getAdmissions().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getCirculars().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getDefaultersWithAgeing().catchError((_) => <String, dynamic>{}),
        _schoolService.getParentComplaints().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getUnifiedExecutiveApprovals().catchError((_) => <String, dynamic>{
          'items': <Map<String, dynamic>>[],
          'total_count': 0,
          'counts_by_type': <String, int>{},
        }),
        _schoolService.getAdminEnrolmentTrend().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getAdminFeeCollectionTrend().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getAdminSchoolAttendanceTrend(days: 30).catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getAdminAdmissionFunnel().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getAdminFeeHeadDistribution().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getAdminExamClassPassRates().catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getSchoolSettings().catchError((_) => <String, dynamic>{}),
        _schoolService.getAuditLog(limit: 20).catchError((_) => <Map<String, dynamic>>[]),
        _schoolService.getStaffDirectory().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final briefing = results[1] as Map<String, dynamic>;
      final admissions = results[2] as List<Map<String, dynamic>>;
      final circulars = results[3] as List<Map<String, dynamic>>;
      final defaulters = results[4] as Map<String, dynamic>;
      final complaints = results[5] as List<Map<String, dynamic>>;
      final approvals = results[6] as Map<String, dynamic>;
      final enrolmentTrend = results[7] as List<Map<String, dynamic>>;
      final feeTrend = results[8] as List<Map<String, dynamic>>;
      final attendanceTrend = results[9] as List<Map<String, dynamic>>;
      final admissionFunnel = results[10] as List<Map<String, dynamic>>;
      final feeHeadDistribution = results[11] as List<Map<String, dynamic>>;
      final examPassRates = results[12] as List<Map<String, dynamic>>;
      final settings = results[13] as Map<String, dynamic>;
      final auditLogs = results[14] as List<Map<String, dynamic>>;
      final staffDir = results[15] as List<Map<String, dynamic>>;

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

      final countsByType = (approvals['counts_by_type'] as Map<String, dynamic>?) ?? {};

      if (mounted) {
        setState(() {
          _schoolSettings = settings;
          _auditLogs = auditLogs;
          _staffDirectory = staffDir;

          if (settings.isNotEmpty) {
            if (settings['school_name'] != null && settings['school_name'].toString().isNotEmpty) {
              _schoolName = settings['school_name'].toString();
            }
            if (settings['affiliation_no'] != null && settings['affiliation_no'].toString().isNotEmpty) {
              _affiliationNo = settings['affiliation_no'].toString();
            }
            if (settings['academic_session'] != null && settings['academic_session'].toString().isNotEmpty) {
              _academicSession = settings['academic_session'].toString();
            }
            if (settings['current_term'] != null && settings['current_term'].toString().isNotEmpty) {
              _currentTerm = settings['current_term'].toString();
            }
          }

          _totalStudents = (briefing['students_enrolled'] as num?)?.toInt() ??
              (stats['total_students'] as num?)?.toInt() ??
              0;
          _totalTeachers = staffDir.isNotEmpty
              ? staffDir.length
              : ((stats['total_teachers'] as num?)?.toInt() ?? 0);
          _totalClasses = (stats['total_classes'] as num?)?.toInt() ?? 0;
          _attendanceToday = (briefing['attendance_percent'] as num?)?.toDouble() ??
              (stats['attendance_today'] as num?)?.toDouble() ??
              0.0;
          _attendanceMarkedToday = (briefing['attendance_marked'] as bool?) ?? (_attendanceToday > 0);
          _feeCollectedToday = (briefing['fee_collected'] as num?)?.toDouble() ?? 0.0;
          _feePendingDues = (briefing['fee_pending'] as num?)?.toDouble() ?? 0.0;
          _activeTransportRoutes = (briefing['active_transport_fleet'] as num?)?.toInt() ?? 0;
          
          _unifiedApprovals = approvals;
          _pendingAdmissionsCount = countsByType['Admission'] ?? pendingAdmissions.length;
          _pendingCertificatesCount = countsByType['Certificate'] ?? 0;
          _pendingTeacherLeavesCount = countsByType['TeacherLeave'] ?? 0;
          _pendingStudentLeavesCount = countsByType['StudentLeave'] ?? 0;
          _openParentComplaints = countsByType['Grievance'] ?? openComplaints.length;
          
          _defaultersCount = (defaulters['total_defaulters'] as num?)?.toInt() ??
              (stats['pending_fees_count'] as num?)?.toInt() ??
              0;

          _recentCirculars = circulars.take(5).toList();
          _openComplaintsList = openComplaints;

          _enrolmentTrend = enrolmentTrend;
          _feeTrend = feeTrend;
          _attendanceTrend = attendanceTrend;
          _admissionFunnel = admissionFunnel;
          _feeHeadDistribution = feeHeadDistribution;
          _examPassRates = examPassRates;
          _analyticsLoading = false;

          _isLoading = false;
          _isRefreshing = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _hasError = true;
          _errorMessage = e.toString();
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
          : _hasError && !_isRefreshing
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to Load Institutional Command Data',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage ?? 'Please check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _loadData(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        _buildInstitutionalAnalyticsHeader(context),
                        const SizedBox(height: 12),
                        _buildInstitutionalAnalyticsGrid(context),
                        const SizedBox(height: 24),
                        _buildManagementDomainsMatrix(context),
                        const SizedBox(height: 24),
                        _buildOperationalCommandStrip(context),
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
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          tooltip: 'Universal Search (N12)',
          onPressed: () => _showGlobalSearchDialog(context),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              tooltip: 'Executive Notifications Inbox (N14)',
              onPressed: () => _showNotificationsInboxModal(context),
            ),
            if (((_unifiedApprovals['total_count'] as int?) ?? 0) > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  child: Text(
                    '${(_unifiedApprovals['total_count'] as int?) ?? 0}',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF93C5FD)),
          tooltip: 'Institute Statutory Settings (N5)',
          onPressed: () => _showInstituteSettingsDialog(context),
        ),
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
          tooltip: 'Statutory UDISE+ Inspection (N11)',
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
                        Text(
                          _schoolName,
                          style: const TextStyle(
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
  // 2. UNIFIED EXECUTIVE APPROVALS & ATTENTION DESK (N2 + M5)
  // ==========================================
  Widget _buildAttentionRequiredStrip(BuildContext context) {
    final totalApprovals = (_unifiedApprovals['total_count'] as int?) ?? 0;
    final totalActionItems = totalApprovals + _defaultersCount;
    final items = (_unifiedApprovals['items'] as List<Map<String, dynamic>>?) ?? [];

    if (totalActionItems == 0) {
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
              const Icon(Icons.assignment_late_rounded, color: Color(0xFFDC2626), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Executive Approvals Desk & Action Queue',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalActionItems Pending Actions',
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
              if (_pendingAdmissionsCount > 0)
                _buildActionChip(
                  icon: Icons.person_add_alt_1_rounded,
                  label: '$_pendingAdmissionsCount Admissions (KYC)',
                  actionText: 'Scrutinize',
                  onTap: () => context.go('/school/admissions'),
                ),
              if (_pendingCertificatesCount > 0)
                _buildActionChip(
                  icon: Icons.verified_user_rounded,
                  label: '$_pendingCertificatesCount Certificates Pending',
                  actionText: 'Review',
                  onTap: () => _showUnifiedApprovalsModal(context, filterType: 'Certificate'),
                ),
              if (_pendingTeacherLeavesCount > 0)
                _buildActionChip(
                  icon: Icons.event_busy_rounded,
                  label: '$_pendingTeacherLeavesCount Faculty Leaves',
                  actionText: 'Review',
                  onTap: () => _showUnifiedApprovalsModal(context, filterType: 'TeacherLeave'),
                ),
              if (_pendingStudentLeavesCount > 0)
                _buildActionChip(
                  icon: Icons.time_to_leave_rounded,
                  label: '$_pendingStudentLeavesCount Student Leaves',
                  actionText: 'Oversight',
                  onTap: () => _showUnifiedApprovalsModal(context, filterType: 'StudentLeave'),
                ),
              if (_defaultersCount > 0)
                _buildActionChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '$_defaultersCount Accounts Overdue in Queue',
                  actionText: 'Inspect',
                  onTap: () => context.go('/school/fees'),
                ),
              if (_openParentComplaints > 0)
                _buildActionChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '$_openParentComplaints Parent Grievances Open',
                  actionText: 'Review',
                  onTap: () => _showComplaintsModal(context),
                ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFFECACA), height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Top Priority Items Awaiting Decision:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showUnifiedApprovalsModal(context),
                  child: const Text(
                    'Open Unified Approvals Desk →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...items.take(3).map((item) => _buildTopApprovalItemCard(context, item)),
          ],
        ],
      ),
    );
  }

  Widget _buildTopApprovalItemCard(BuildContext context, Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    final typeLabel = item['type_label']?.toString() ?? type;
    final colorVal = item['category_color'] as int? ?? 0xFF2563EB;
    final color = Color(colorVal);
    final days = (item['days_pending'] as int?) ?? 0;
    final isOverdue = days >= 3;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item['subtitle']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$days d pending',
              style: TextStyle(
                color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF475569),
                fontSize: 10,
                fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (type == 'TeacherLeave') {
                _showReviewTeacherLeaveDialog(context, item);
              } else if (type == 'Certificate') {
                _showReviewCertificateDialog(context, item);
              } else if (type == 'Grievance') {
                _showResolveGrievanceDialog(context, item);
              } else if (type == 'Admission') {
                context.go('/school/admissions');
              } else if (type == 'StudentLeave') {
                context.go('/school/leave');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(64, 26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showReviewTeacherLeaveDialog(BuildContext context, Map<String, dynamic> item) {
    final remarksController = TextEditingController();
    final raw = item['raw_data'] as Map<String, dynamic>? ?? {};
    final id = item['id']?.toString() ?? '';
    final name = raw['teacher_name']?.toString() ?? item['title']?.toString() ?? 'Faculty';
    final type = raw['type']?.toString() ?? 'Leave';
    final dates = '${raw['start_date']} to ${raw['end_date']}';
    final reason = raw['reason']?.toString() ?? 'Official Faculty Leave';
    final days = item['days_pending'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.event_busy_rounded, color: Color(0xFFD97706), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Faculty Leave Application',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 4),
                    Text('Type: $type • Period: $dates', style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
                    const SizedBox(height: 2),
                    Text('Reason: $reason', style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
                    const SizedBox(height: 4),
                    Text('Age in Queue: $days days pending review', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Administrative Remarks (Mandatory for rejection):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: remarksController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter executive decision remarks...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            onPressed: () async {
              final remarks = remarksController.text.trim();
              if (remarks.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide rejection remarks.'), backgroundColor: Color(0xFFDC2626)),
                );
                return;
              }
              Navigator.pop(ctx);
              final ok = await _schoolService.updateTeacherLeaveStatus(
                circularId: id,
                status: 'Rejected',
                reviewedBy: _adminName,
                remarks: remarks,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Faculty leave application rejected.' : 'Failed to update leave.'),
                    backgroundColor: ok ? const Color(0xFFDC2626) : Colors.red,
                  ),
                );
                _loadData(showRefreshing: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Reject Leave'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final remarks = remarksController.text.trim();
              final ok = await _schoolService.updateTeacherLeaveStatus(
                circularId: id,
                status: 'Approved',
                reviewedBy: _adminName,
                remarks: remarks.isEmpty ? 'Approved by Principal' : remarks,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Faculty leave application approved.' : 'Failed to approve leave.'),
                    backgroundColor: ok ? const Color(0xFF059669) : Colors.red,
                  ),
                );
                _loadData(showRefreshing: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            child: const Text('Approve Leave'),
          ),
        ],
      ),
    );
  }

  void _showReviewCertificateDialog(BuildContext context, Map<String, dynamic> item) {
    final remarksController = TextEditingController();
    final raw = item['raw_data'] as Map<String, dynamic>? ?? {};
    final id = item['id']?.toString() ?? '';
    final studentName = item['title']?.toString() ?? 'Student';
    final className = raw['class']?.toString() ?? 'Class 10-A';
    final certType = raw['cert_type']?.toString() ?? 'Bonafide Certificate';
    final reason = raw['reason']?.toString() ?? 'Official Request';
    final days = item['days_pending'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF7C3AED), size: 22),
            SizedBox(width: 8),
            Text(
              'Certificate Request Review',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF5B21B6)),
                    ),
                    const SizedBox(height: 4),
                    Text('$certType • $className', style: const TextStyle(fontSize: 12, color: Color(0xFF6D28D9))),
                    const SizedBox(height: 2),
                    Text('Purpose: $reason', style: const TextStyle(fontSize: 12, color: Color(0xFF6D28D9))),
                    const SizedBox(height: 4),
                    Text('Age in Queue: $days days pending', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Remarks (Required for rejection):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: remarksController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter certificate review remarks...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            onPressed: () async {
              final remarks = remarksController.text.trim();
              if (remarks.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide rejection remarks.'), backgroundColor: Color(0xFFDC2626)),
                );
                return;
              }
              Navigator.pop(ctx);
              final ok = await _schoolService.rejectCertificateRequest(
                requestId: id,
                remarks: remarks,
                rejectedBy: _adminName,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Certificate request rejected.' : 'Failed to reject certificate.'),
                    backgroundColor: ok ? const Color(0xFFDC2626) : Colors.red,
                  ),
                );
                _loadData(showRefreshing: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _schoolService.issueSchoolCertificate(
                  requestId: id,
                  studentName: studentName,
                  className: className,
                  certType: certType,
                  authorizedBy: _adminName,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Certificate issued and digitally sealed with QR verification.'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                  _loadData(showRefreshing: true);
                }
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            child: const Text('Issue Certificate'),
          ),
        ],
      ),
    );
  }

  void _showResolveGrievanceDialog(BuildContext context, Map<String, dynamic> item) {
    final notesController = TextEditingController();
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Parent Complaint';
    final subtitle = item['subtitle']?.toString() ?? '';
    final days = item['days_pending'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text(
              'Resolve Parent Grievance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                    const SizedBox(height: 4),
                    Text('Pending in queue: $days days', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Resolution Notes (Mandatory for parent notification):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter specific corrective actions taken and response to parent...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
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
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter resolution notes before resolving.'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final ok = await _schoolService.resolveParentComplaint(
                complaintId: id,
                resolutionNotes: notes,
              );
              if (ok) {
                await _schoolService.logAuditEvent(
                  actorUsername: _adminName,
                  action: 'Parent Grievance Resolved',
                  entityType: 'Grievance',
                  entityId: id,
                  details: notes,
                );
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Parent grievance resolved and recorded.' : 'Failed to resolve grievance.'),
                    backgroundColor: ok ? const Color(0xFF059669) : Colors.red,
                  ),
                );
                _loadData(showRefreshing: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            child: const Text('Confirm Resolution'),
          ),
        ],
      ),
    );
  }

  void _showUnifiedApprovalsModal(BuildContext context, {String? filterType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          String activeFilter = filterType ?? 'All';
          final allItems = (_unifiedApprovals['items'] as List<Map<String, dynamic>>?) ?? [];
          final filteredItems = activeFilter == 'All'
              ? allItems
              : allItems.where((i) => i['type'] == activeFilter).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_late_rounded, color: Color(0xFFDC2626), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unified Executive Approvals Desk',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${allItems.length} Total items awaiting executive review & decision',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.table_view_rounded, size: 20, color: Color(0xFF059669)),
                        tooltip: 'Export Approvals Excel (AD-R13)',
                        onPressed: () => SchoolExportService.exportAdminApprovalsAgeingExcel(
                          context: context,
                          approvalsList: filteredItems,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Filter chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', allItems.length, activeFilter == 'All', () => setModalState(() => activeFilter = 'All')),
                        const SizedBox(width: 8),
                        _buildFilterChip('Admissions', _pendingAdmissionsCount, activeFilter == 'Admission', () => setModalState(() => activeFilter = 'Admission')),
                        const SizedBox(width: 8),
                        _buildFilterChip('Certificates', _pendingCertificatesCount, activeFilter == 'Certificate', () => setModalState(() => activeFilter = 'Certificate')),
                        const SizedBox(width: 8),
                        _buildFilterChip('Faculty Leaves', _pendingTeacherLeavesCount, activeFilter == 'TeacherLeave', () => setModalState(() => activeFilter = 'TeacherLeave')),
                        const SizedBox(width: 8),
                        _buildFilterChip('Student Leaves', _pendingStudentLeavesCount, activeFilter == 'StudentLeave', () => setModalState(() => activeFilter = 'StudentLeave')),
                        const SizedBox(width: 8),
                        _buildFilterChip('Grievances', _openParentComplaints, activeFilter == 'Grievance', () => setModalState(() => activeFilter = 'Grievance')),
                      ],
                    ),
                  ),
                ),
                // Items List
                Expanded(
                  child: filteredItems.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF059669)),
                                SizedBox(height: 12),
                                Text(
                                  'No pending items in this queue category',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'All student, faculty and administrative requests are nominal.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (lCtx, idx) {
                            final item = filteredItems[idx];
                            return _buildQueueItemTile(context, item);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueItemTile(BuildContext context, Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    final typeLabel = item['type_label']?.toString() ?? type;
    final colorVal = item['category_color'] as int? ?? 0xFF2563EB;
    final color = Color(colorVal);
    final days = (item['days_pending'] as int?) ?? 0;
    final isOverdue = days >= 3;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$days days pending',
              style: TextStyle(
                color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF475569),
                fontSize: 11,
                fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (type == 'TeacherLeave') {
                _showReviewTeacherLeaveDialog(context, item);
              } else if (type == 'Certificate') {
                _showReviewCertificateDialog(context, item);
              } else if (type == 'Grievance') {
                _showResolveGrievanceDialog(context, item);
              } else if (type == 'Admission') {
                context.go('/school/admissions');
              } else if (type == 'StudentLeave') {
                context.go('/school/leave');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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

        final ptrStr = _totalTeachers > 0 && _totalStudents > 0
            ? 'PTR: ${(_totalStudents / _totalTeachers).toStringAsFixed(1)}:1'
            : 'PTR: Unassigned';

        final attSubtitle = _attendanceMarkedToday
            ? '${_attendanceToday.toStringAsFixed(1)}% Present Today'
            : 'Attendance Not Marked Yet';

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Enrolled Students',
                value: '$_totalStudents',
                subtitle: attSubtitle,
                detail: '$_totalClasses Active Sections',
                icon: Icons.groups_rounded,
                accentColor: const Color(0xFF2563EB),
                isPositive: _attendanceMarkedToday ? _attendanceToday >= 75 : false,
                onTap: () => context.go('/school/attendance'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Faculty & Staff',
                value: '$_totalTeachers',
                subtitle: '$_totalTeachers Teaching Faculty',
                detail: ptrStr,
                icon: Icons.school_rounded,
                accentColor: const Color(0xFF059669),
                isPositive: _totalTeachers > 0,
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
                isPositive: _feePendingDues == 0,
                onTap: () => context.go('/school/fees'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                title: 'Transport Fleet',
                value: '$_activeTransportRoutes Routes',
                subtitle: '$_activeTransportRoutes Active Fleet Routes',
                detail: 'Safety Telematics Online',
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
  // 3. INSTITUTIONAL ANALYTICS & TELEMETRY (N1, N6, N7, AD-R01 to AD-R06)
  // ==========================================
  Widget _buildInstitutionalAnalyticsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institutional Intelligence & Analytics',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Live telemetry across enrolment, financial health, daily attendance, and admissions',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/school/reports'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Text('Reports Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            label: const Icon(Icons.arrow_forward_rounded, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalAnalyticsGrid(BuildContext context) {
    if (_analyticsLoading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
              SizedBox(height: 12),
              Text(
                'Computing Institutional Analytics & Trends...',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    // Telemetry summary metrics (AD-R04 & AD-R06)
    double totalPassRate = 0;
    for (final c in _examPassRates) {
      totalPassRate += (c['pass_rate'] as num?)?.toDouble() ?? 0.0;
    }
    final avgPassRate = _examPassRates.isNotEmpty ? (totalPassRate / _examPassRates.length) : 0.0;
    final topFeeHead = _feeHeadDistribution.isNotEmpty ? _feeHeadDistribution.first : null;

    final telemetryBar = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _examPassRates.isNotEmpty
                  ? 'Exams (AD-R06): ${avgPassRate.toStringAsFixed(1)}% Pass Rate across ${_examPassRates.length} sections'
                  : 'Exams (AD-R06): Term evaluations synchronising',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF0D9488)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              topFeeHead != null
                  ? 'Head-wise (AD-R04): ${topFeeHead['head']} (${topFeeHead['share_pct']}%)'
                  : 'Head-wise (AD-R04): Tuition accounts nominal',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 950;
        if (isWide) {
          return Column(
            children: [
              telemetryBar,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildAttendanceTrendCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFeeTrendCard(context)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildEnrolmentTrendCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildAdmissionFunnelCard(context)),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            telemetryBar,
            _buildAttendanceTrendCard(context),
            const SizedBox(height: 16),
            _buildFeeTrendCard(context),
            const SizedBox(height: 16),
            _buildEnrolmentTrendCard(context),
            const SizedBox(height: 16),
            _buildAdmissionFunnelCard(context),
          ],
        );
      },
    );
  }

  // 1. Attendance Trajectory Card (LineChart with 75% CBSE line)
  Widget _buildAttendanceTrendCard(BuildContext context) {
    double avgPct = 0.0;
    int compliantDays = 0;
    if (_attendanceTrend.isNotEmpty) {
      double sum = 0.0;
      for (final item in _attendanceTrend) {
        final p = (item['percentage'] as num?)?.toDouble() ?? 0.0;
        sum += p;
        if (p >= 75.0) compliantDays++;
      }
      avgPct = sum / _attendanceTrend.length;
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _attendanceTrend.length; i++) {
      final p = (_attendanceTrend[i]['percentage'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), p));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF059669), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '30-Day Attendance Trajectory',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_attendanceTrend.length} days recorded • CBSE 75% Min Benchmark',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: avgPct >= 75 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: avgPct >= 75 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  '${avgPct.toStringAsFixed(1)}% Avg',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: avgPct >= 75 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_attendanceTrend.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: const Text(
                'No attendance records in past 30 days',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 105,
                  minX: 0,
                  maxX: (_attendanceTrend.length - 1).toDouble().clamp(1.0, 100.0),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: const Color(0xFF0F172A),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.spotIndex;
                          final d = (idx >= 0 && idx < _attendanceTrend.length)
                              ? (_attendanceTrend[idx]['date']?.toString() ?? '')
                              : '';
                          return LineTooltipItem(
                            '$d\n${spot.y.toStringAsFixed(1)}% Attendance',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 75.0,
                        color: const Color(0xFFEF4444),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 4, bottom: 2),
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                          labelResolver: (_) => '75% Min',
                        ),
                      ),
                    ],
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (val) => const FlLine(
                      color: Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 25,
                        getTitlesWidget: (val, _) => Text(
                          '${val.toInt()}%',
                          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (_attendanceTrend.length / 5).clamp(1.0, 10.0),
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < _attendanceTrend.length) {
                            final d = _attendanceTrend[idx]['date']?.toString() ?? '';
                            final parts = d.split('-');
                            final label = parts.length >= 3 ? '${parts[1]}/${parts[2]}' : d;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: const Color(0xFF059669),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$compliantDays/${_attendanceTrend.length} Days Compliant (≥75%)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF059669)),
                    tooltip: 'Export Attendance Excel (.xlsx)',
                    onPressed: () => SchoolExportService.exportAttendanceTrendExcel(
                      context: context,
                      className: 'Whole School',
                      teacherName: _adminName,
                      trendRows: _attendanceTrend,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  InkWell(
                    onTap: () => context.push('/school/reports'),
                    child: const Row(
                      children: [
                        Text(
                          'Attendance Audit',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Fee Collection vs Dues Trend Card (Grouped Bar Chart)
  Widget _buildFeeTrendCard(BuildContext context) {
    double totalCol = 0.0;
    double totalDue = 0.0;
    double maxVal = 0.0;

    for (final item in _feeTrend) {
      final c = (item['collected'] as num?)?.toDouble() ?? 0.0;
      final p = (item['pending'] as num?)?.toDouble() ?? 0.0;
      totalCol += c;
      totalDue += p;
      if (c > maxVal) maxVal = c;
      if (p > maxVal) maxVal = p;
    }
    if (maxVal <= 0) maxVal = 50000;
    final maxY = maxVal * 1.25;

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < _feeTrend.length; i++) {
      final c = (_feeTrend[i]['collected'] as num?)?.toDouble() ?? 0.0;
      final p = (_feeTrend[i]['pending'] as num?)?.toDouble() ?? 0.0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: c,
              color: const Color(0xFF10B981),
              width: 7,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            BarChartRodData(
              toY: p,
              color: const Color(0xFFF59E0B),
              width: 7,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fee Collections vs Pending Dues',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Monthly collection performance and receivables',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                'Col: ${_formatCurrency(totalCol)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                'Due: ${_formatCurrency(totalDue)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_feeTrend.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: const Text(
                'No fee records for academic session',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: const Color(0xFF0F172A),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final m = (groupIndex >= 0 && groupIndex < _feeTrend.length)
                            ? (_feeTrend[groupIndex]['month']?.toString() ?? '')
                            : '';
                        final type = rodIndex == 0 ? 'Collected' : 'Pending';
                        return BarTooltipItem(
                          '$m • $type\n₹${(rod.toY / 1000).toStringAsFixed(1)}k',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (val) => const FlLine(
                      color: Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: maxY / 4,
                        getTitlesWidget: (val, _) {
                          if (val <= 0) return const SizedBox.shrink();
                          final kVal = (val / 1000).round();
                          return Text(
                            '₹${kVal}k',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < _feeTrend.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _feeTrend[idx]['month']?.toString() ?? '',
                                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grouped by Financial Month (Apr–Mar)',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF059669)),
                    tooltip: 'Export Fee Ledger Excel (AD-R02)',
                    onPressed: () => SchoolExportService.exportAdminFeeCollectionsExcel(
                      context: context,
                      feeTrend: _feeTrend,
                      totalCollected: totalCol,
                      totalPending: totalDue,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  InkWell(
                    onTap: () => context.push('/school/fees'),
                    child: const Row(
                      children: [
                        Text(
                          'Fee Ledger & Defaulters',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Enrolment Trajectory Card (LineChart)
  Widget _buildEnrolmentTrendCard(BuildContext context) {
    double maxCum = 0.0;
    final spots = <FlSpot>[];
    for (int i = 0; i < _enrolmentTrend.length; i++) {
      final cum = (_enrolmentTrend[i]['cumulative'] as num?)?.toDouble() ?? 0.0;
      if (cum > maxCum) maxCum = cum;
      spots.add(FlSpot(i.toDouble(), cum));
    }
    if (maxCum <= 0) maxCum = 100.0;
    final maxY = maxCum * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Enrolment Trajectory',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalStudents Total Enrolled Students across Sections',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '$_totalStudents Active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_enrolmentTrend.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: const Text(
                'No enrolment trend data available',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  minX: 0,
                  maxX: (_enrolmentTrend.length - 1).toDouble().clamp(1.0, 11.0),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: const Color(0xFF0F172A),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.spotIndex;
                          final m = (idx >= 0 && idx < _enrolmentTrend.length)
                              ? (_enrolmentTrend[idx]['month']?.toString() ?? '')
                              : '';
                          final intake = (idx >= 0 && idx < _enrolmentTrend.length)
                              ? (_enrolmentTrend[idx]['intake']?.toString() ?? '0')
                              : '0';
                          return LineTooltipItem(
                            '$m: ${spot.y.toInt()} Total\n(+$intake admitted)',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (val) => const FlLine(
                      color: Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: maxY / 4,
                        getTitlesWidget: (val, _) => Text(
                          val.toInt().toString(),
                          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < _enrolmentTrend.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _enrolmentTrend[idx]['month']?.toString() ?? '',
                                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: const Color(0xFF2563EB),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cumulative Student Admissions',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF059669)),
                    tooltip: 'Export Enrolment Excel (AD-R01)',
                    onPressed: () => SchoolExportService.exportAdminEnrolmentExcel(
                      context: context,
                      enrolmentTrend: _enrolmentTrend,
                      totalStudents: _totalStudents,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  InkWell(
                    onTap: () => context.push('/school/reports'),
                    child: const Row(
                      children: [
                        Text(
                          'View Student Directory',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Admission Funnel Card (Stage-by-stage Pipeline)
  Widget _buildAdmissionFunnelCard(BuildContext context) {
    final stages = _admissionFunnel.isNotEmpty
        ? _admissionFunnel
        : [
            {'stage': 'Inquiries', 'count': 0, 'rate': 100.0},
            {'stage': 'Applied', 'count': 0, 'rate': 0.0},
            {'stage': 'Scrutiny', 'count': 0, 'rate': 0.0},
            {'stage': 'Interaction', 'count': 0, 'rate': 0.0},
            {'stage': 'Offers', 'count': 0, 'rate': 0.0},
            {'stage': 'Enrolled', 'count': 0, 'rate': 0.0},
          ];

    final stageColors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF0EA5E9), // Sky
      const Color(0xFF0D9488), // Teal
      const Color(0xFF10B981), // Emerald
      const Color(0xFF059669), // Green
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.filter_alt_rounded, color: Color(0xFF9333EA), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admission Intake Funnel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lead conversion from initial inquiry to enrollment',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: List.generate(stages.length, (idx) {
              final stage = stages[idx];
              final stageName = stage['stage']?.toString() ?? '';
              final count = (stage['count'] as num?)?.toInt() ?? 0;
              final rate = (stage['rate'] as num?)?.toDouble() ?? 0.0;
              final color = stageColors[idx % stageColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stageName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        Row(
                          children: [
                            Text(
                              '$count candidates',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${rate.toStringAsFixed(1)}%)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (rate / 100.0).clamp(0.02, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RTE Quota Monitored via DB',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF059669)),
                    tooltip: 'Export Admission Funnel Excel (AD-R05)',
                    onPressed: () => SchoolExportService.exportAdminAdmissionFunnelExcel(
                      context: context,
                      funnelStages: _admissionFunnel,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  InkWell(
                    onTap: () => context.push('/school/admissions'),
                    child: const Row(
                      children: [
                        Text(
                          'Manage Admissions Desk',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
              title: 'Lesson Plan & 5E Studio',
              desc: 'Constructivist 5E plans, Bloom\'s cognitive mapping, HOD scrutiny & syllabus pacing velocity',
              icon: Icons.menu_book_rounded,
              route: '/school/lesson-plans',
              badge: 'NEP 2020',
              badgeColor: const Color(0xFF4338CA),
            ),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: modules.asMap().entries.map((entry) {
                final index = entry.key;
                final m = entry.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index > 0) const Divider(height: 1, indent: 48, color: Color(0xFFF8FAFC)),
                    ListTile(
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
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // OPERATIONAL COMMAND STRIP: EXAM OVERSIGHT (N8) & TRANSPORT SAFETY (N9)
  // ==========================================
  Widget _buildOperationalCommandStrip(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final examCard = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fact_check_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examination Oversight (N8)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Term II Cycles & Pass Rates',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CBSE Nominated',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Cycles', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          SizedBox(height: 2),
                          Text('2 Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pass Rate Telemetry', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            _examPassRates.isNotEmpty
                                ? '${(_examPassRates.map((e) => (e['pass_rate'] as num?)?.toDouble() ?? 0).reduce((a, b) => a + b) / _examPassRates.length).toStringAsFixed(1)}%'
                                : '88.5%',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.go('/school/examination'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Open Examination Console',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
        );

        final transportCard = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transport Fleet & Safety (N9)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Fleet Tracking & Boarding',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '0 Incidents',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Fleet', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text('$_activeTransportRoutes Buses Active', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Safety Mismatches', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          SizedBox(height: 2),
                          Text('0 Open Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.go('/school/transport'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Inspect Transport Fleet',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFD97706)),
                  ],
                ),
              ),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              examCard,
              const SizedBox(height: 12),
              transportCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: examCard),
            const SizedBox(width: 14),
            Expanded(child: transportCard),
          ],
        );
      },
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
            child: Column(
              children: _recentCirculars.asMap().entries.map((entry) {
                final index = entry.key;
                final circ = entry.value;
                final title = circ['title']?.toString() ?? 'Notice';
                final category = circ['category']?.toString() ?? 'General';
                final date = circ['published_at']?.toString() ??
                    circ['created_at']?.toString().substring(0, 10) ??
                    'Recent';
                final isUrgent = circ['urgent'] == true;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ListTile(
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
                    ),
                  ],
                );
              }).toList(),
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
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF4338CA),
                    title: 'Scrutinize NEP 2020 Lesson Plans',
                    subtitle: 'Audit 5E pedagogical models, Bloom\'s cognitive levels & approve plans',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.go('/school/lesson-plans');
                    },
                  ),
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
                    title: 'Inspect Statutory UDISE+ Sheet (N11)',
                    subtitle: 'View live PTR, RTE 25% quota, and fire safety NOC compliance',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showUdiseModal(context);
                    },
                  ),
                  _buildQuickActionRow(
                    icon: Icons.people_alt_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Staff Directory & Oversight (N3)',
                    subtitle: 'Review ${_staffDirectory.length} faculty assignments, load, and credentials',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showStaffOversightModal(context);
                    },
                  ),
                  _buildQuickActionRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: const Color(0xFFDC2626),
                    title: 'Parent Grievance Desk (N10)',
                    subtitle: 'Manage ${_openComplaintsList.length} open parent inquiries under 48h SLA',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showGrievanceCentreModal(context);
                    },
                  ),
                  _buildQuickActionRow(
                    icon: Icons.settings_outlined,
                    iconColor: const Color(0xFF475569),
                    title: 'Institute Statutory Settings (N5)',
                    subtitle: 'Configure school identity, CBSE affiliation, RTE quota, & NOC dates',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showInstituteSettingsDialog(context);
                    },
                  ),
                  _buildQuickActionRow(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF0F172A),
                    title: 'Audit Trail & Activity Log (N4)',
                    subtitle: 'Inspect immutable records of administrative actions & decisions',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAuditTrailModal(context);
                    },
                  ),
                ],
              ),
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
                  _buildUdiseRow('Pupil-Teacher Ratio (PTR)', udise['pupil_teacher_ratio'] ?? 'N/A'),
                  _buildUdiseRow('Total Enrolment', '${udise['total_enrolment'] ?? _totalStudents} Students'),
                  _buildUdiseRow(
                    'Boys / Girls Split',
                    (udise['total_enrolment_boys'] != null && udise['total_enrolment_girls'] != null)
                        ? '${udise['total_enrolment_boys']} Boys / ${udise['total_enrolment_girls']} Girls'
                        : 'Not Recorded in Students Register',
                  ),
                  _buildUdiseRow(
                    'RTE 25% Quota Seats',
                    (udise['rte_25_quota_seats'] != null && (udise['rte_25_quota_seats'] as num) > 0)
                        ? '${udise['rte_students_enrolled'] ?? 0} / ${udise['rte_25_quota_seats']} Enrolled'
                        : '${udise['rte_students_enrolled'] ?? 0} Enrolled (Target Unset)',
                  ),
                  _buildUdiseRow('Sanitation & RO Water', udise['sanitation_drinking_water'] ?? 'Requires Verification'),
                  _buildUdiseRow('Fire Safety NOC', udise['fire_safety_noc_status'] ?? 'Pending Statutory Upload'),
                  _buildUdiseRow('Status Indicator', udise['status_indicator'] ?? 'INCOMPLETE STATUTORY RECORD'),
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
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showResolveGrievanceDialog(context, {
                              'id': id,
                              'title': title,
                              'subtitle': 'From: $parent • Status: Open',
                              'days_pending': 0,
                            });
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
  // N5. INSTITUTE STATUTORY SETTINGS DIALOG (N5)
  // ==========================================
  void _showInstituteSettingsDialog(BuildContext context) {
    final schoolNameCtrl = TextEditingController(text: _schoolName);
    final affiliationCtrl = TextEditingController(text: _affiliationNo);
    final sessionCtrl = TextEditingController(text: _academicSession);
    final termCtrl = TextEditingController(text: _currentTerm);
    final udiseCtrl = TextEditingController(text: _schoolSettings['udise_code']?.toString() ?? '05050100101');
    final rteCtrl = TextEditingController(text: (_schoolSettings['rte_quota_seats'] ?? 45).toString());
    final fireNocCtrl = TextEditingController(text: _schoolSettings['fire_noc_expiry']?.toString() ?? '2027-12-31');
    final sanitationCtrl = TextEditingController(text: _schoolSettings['sanitation_cert_expiry']?.toString() ?? '2027-06-30');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings_outlined, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text(
                'Institute Statutory Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statutory Profile & Affiliation',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: schoolNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Official School Name',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: affiliationCtrl,
                          decoration: InputDecoration(
                            labelText: 'CBSE Affiliation No',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: udiseCtrl,
                          decoration: InputDecoration(
                            labelText: 'UDISE+ Code',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Academic Session & Quota Masters',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sessionCtrl,
                          decoration: InputDecoration(
                            labelText: 'Academic Session',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: termCtrl,
                          decoration: InputDecoration(
                            labelText: 'Current Term',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: rteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'RTE 25% Seats',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Statutory Safety Expiries (UDISE+ / Audit)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fireNocCtrl,
                          decoration: InputDecoration(
                            labelText: 'Fire Safety NOC Expiry',
                            hintText: 'YYYY-MM-DD',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: sanitationCtrl,
                          decoration: InputDecoration(
                            labelText: 'Sanitation Cert Expiry',
                            hintText: 'YYYY-MM-DD',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
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
                final newSettings = {
                  'school_name': schoolNameCtrl.text.trim(),
                  'affiliation_no': affiliationCtrl.text.trim(),
                  'udise_code': udiseCtrl.text.trim(),
                  'academic_session': sessionCtrl.text.trim(),
                  'current_term': termCtrl.text.trim(),
                  'rte_quota_seats': int.tryParse(rteCtrl.text.trim()) ?? 45,
                  'fire_noc_expiry': fireNocCtrl.text.trim(),
                  'sanitation_cert_expiry': sanitationCtrl.text.trim(),
                };
                Navigator.pop(dialogCtx);
                final ok = await _schoolService.saveSchoolSettings(newSettings, actorUsername: _adminName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Statutory settings saved & logged to audit trail successfully.'
                          : 'Failed to update statutory settings.'),
                      backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
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
              child: const Text('Save Settings'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // N4. IMMUTABLE AUDIT TRAIL MODAL (N4)
  // ==========================================
  void _showAuditTrailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_rounded, color: Color(0xFF0F172A), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Institutional Audit Trail & Activity Log',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${_auditLogs.length} Immutable administrative actions logged (N4)',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => SchoolExportService.exportAdminAuditTrailExcel(
                          context: context,
                          auditRows: _auditLogs,
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 15),
                        label: const Text('AD-R14 Excel', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _auditLogs.isEmpty
                        ? const Center(
                            child: Text(
                              'No audit events recorded yet.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _auditLogs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (_, idx) {
                              final log = _auditLogs[idx];
                              final actor = log['actor_username']?.toString() ?? 'sadmin1';
                              final action = log['action']?.toString() ?? 'Action';
                              final entity = log['entity_type']?.toString() ?? 'General';
                              final time = log['published_at']?.toString() ?? '';
                              final details = log['details']?.toString() ?? '';

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.security_rounded, color: Color(0xFF2563EB), size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      actor,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        entity,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                                    if (details.isNotEmpty)
                                      Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                                trailing: Text(
                                  time.length >= 10 ? time.substring(0, 10) : time,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // N3. STAFF OVERSIGHT DIRECTORY MODAL (N3)
  // ==========================================
  void _showStaffOversightModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = _staffDirectory.where((s) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              final name = (s['name']?.toString() ?? '').toLowerCase();
              final subj = (s['subject']?.toString() ?? '').toLowerCase();
              final dept = (s['department']?.toString() ?? '').toLowerCase();
              return name.contains(q) || subj.contains(q) || dept.contains(q);
            }).toList();

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Staff Oversight & Faculty Directory (N3)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  '${_staffDirectory.length} Active Faculty • Read-Only Leadership Oversight',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => SchoolExportService.exportAdminStaffLoadExcel(
                              context: context,
                              staffList: _staffDirectory,
                            ),
                            icon: const Icon(Icons.file_download_outlined, size: 15),
                            label: const Text('AD-R07 Excel', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Staff onboarding, payroll, & credentials are maintained via User Management.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                context.go('/admin/manage-users');
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Manage Users →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (v) => setModalState(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search faculty by name, department, or subject...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('No faculty members match your query.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (_, idx) {
                                  final staff = filtered[idx];
                                  final name = staff['name']?.toString() ?? staff['username']?.toString() ?? 'Faculty';
                                  final subject = staff['subject']?.toString() ?? 'Academics';
                                  final dept = staff['department']?.toString() ?? 'School';
                                  final email = staff['email']?.toString() ?? '';
                                  final classes = staff['classes']?.toString() ?? 'Assigned Classes';

                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFF1E293B),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'F',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            subject,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '$dept • $classes • $email',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('24 Periods/Wk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // N10. PARENT GRIEVANCE CENTRE MODAL (N10)
  // ==========================================
  void _showGrievanceCentreModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Parent Grievance Command Centre (N10)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${_openComplaintsList.length} Open Inquiries • 48-Hour Resolution SLA Target',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => SchoolExportService.exportAdminGrievancesExcel(
                          context: context,
                          grievancesList: _openComplaintsList,
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 15),
                        label: const Text('AD-R11 Excel', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _openComplaintsList.isEmpty
                        ? const Center(
                            child: Text('All parent grievances resolved nominal.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : ListView.separated(
                            itemCount: _openComplaintsList.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (_, idx) {
                              final item = _openComplaintsList[idx];
                              final id = item['id']?.toString() ?? '';
                              final title = item['title']?.toString() ?? 'Parent Complaint';
                              final parent = item['author'] ?? 'Registered Parent';
                              final date = item['published_at']?.toString() ?? '';

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Open (48h SLA)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Guardian: $parent • Date: ${date.length >= 10 ? date.substring(0, 10) : date}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showResolveGrievanceDialog(context, {
                                      'id': id,
                                      'title': title,
                                      'subtitle': 'Guardian: $parent',
                                      'days_pending': 0,
                                    });
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // N12. UNIVERSAL INSTITUTIONAL SEARCH DIALOG (N12)
  // ==========================================
  void _showGlobalSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String query = '';
        Map<String, List<Map<String, dynamic>>> results = {
          'students': [],
          'faculty': [],
          'circulars': [],
          'admissions': [],
        };
        bool searching = false;

        return StatefulBuilder(
          builder: (searchCtx, setSearchState) {
            void performSearch(String val) async {
              setSearchState(() {
                query = val;
                searching = true;
              });
              final res = await _schoolService.searchInstitutionalEntities(val);
              setSearchState(() {
                results = res;
                searching = false;
              });
            }

            final totalFound = (results['students']?.length ?? 0) +
                (results['faculty']?.length ?? 0) +
                (results['circulars']?.length ?? 0) +
                (results['admissions']?.length ?? 0);

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: TextField(
                autofocus: true,
                onChanged: performSearch,
                decoration: InputDecoration(
                  hintText: 'Search students, faculty, circulars, admissions...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                  suffixIcon: searching
                      ? const SizedBox(width: 16, height: 16, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              content: SizedBox(
                width: 500,
                height: 380,
                child: query.isEmpty
                    ? const Center(
                        child: Text('Type a name, roll no, circular title, or admission ID...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      )
                    : totalFound == 0 && !searching
                        ? const Center(
                            child: Text('No institutional entities matched your query.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : ListView(
                            children: [
                              if ((results['students'] ?? []).isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('STUDENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                ),
                                ...results['students']!.map((s) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 18),
                                      title: Text(s['name']?.toString() ?? 'Student', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text('Class ${s['class_name'] ?? 'N/A'} • Adm #${s['admission_no'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
                                      onTap: () {
                                        Navigator.pop(dialogCtx);
                                        context.go('/school/attendance');
                                      },
                                    )),
                              ],
                              if ((results['faculty'] ?? []).isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('FACULTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                ),
                                ...results['faculty']!.map((f) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.badge_rounded, color: Color(0xFF059669), size: 18),
                                      title: Text(f['username']?.toString() ?? 'Teacher', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: const Text('School Faculty Member', style: TextStyle(fontSize: 11)),
                                      onTap: () {
                                        Navigator.pop(dialogCtx);
                                        _showStaffOversightModal(context);
                                      },
                                    )),
                              ],
                              if ((results['admissions'] ?? []).isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('ADMISSIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                ),
                                ...results['admissions']!.map((a) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFD97706), size: 18),
                                      title: Text(a['student_name']?.toString() ?? 'Applicant', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text('Applying: ${a['class_applying'] ?? 'N/A'} • Status: ${a['status'] ?? 'Pending'}', style: const TextStyle(fontSize: 11)),
                                      onTap: () {
                                        Navigator.pop(dialogCtx);
                                        context.go('/school/admissions');
                                      },
                                    )),
                              ],
                              if ((results['circulars'] ?? []).isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('CIRCULARS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                ),
                                ...results['circulars']!.map((c) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.campaign_rounded, color: Color(0xFF7C3AED), size: 18),
                                      title: Text(c['title']?.toString() ?? 'Circular', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text('${c['category'] ?? 'General'} • ${c['published_at'] ?? ''}', style: const TextStyle(fontSize: 11)),
                                      onTap: () {
                                        Navigator.pop(dialogCtx);
                                        context.go('/school/circulars');
                                      },
                                    )),
                              ],
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // N13. BROADCAST & CIRCULARS CENTRE MODAL (N13)
  // ==========================================
  void _showBroadcastCentreModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Broadcast & Circulars Command Centre (N13)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Official Institutional Notices & Audience Segmentation',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => SchoolExportService.exportAdminBroadcastsExcel(
                          context: context,
                          circularsList: _recentCirculars,
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 15),
                        label: const Text('AD-R12 Excel', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showPublishCircularDialog(context);
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Compose Official Circular', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _recentCirculars.isEmpty
                        ? const Center(
                            child: Text('No circulars published yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : ListView.separated(
                            itemCount: _recentCirculars.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (_, idx) {
                              final circ = _recentCirculars[idx];
                              final title = circ['title'] ?? 'Notice';
                              final category = circ['category'] ?? 'General';
                              final audience = circ['target_audience'] ?? 'All';
                              final date = circ['published_at'] ?? '';
                              final content = circ['content'] ?? '';

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$category • $audience',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (content.isNotEmpty)
                                      Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                    Text('Date: $date', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  context.go('/school/circulars');
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // N14. EXECUTIVE NOTIFICATIONS INBOX MODAL (N14)
  // ==========================================
  void _showNotificationsInboxModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final notifications = <Map<String, dynamic>>[];

        if (_pendingAdmissionsCount > 0) {
          notifications.add({
            'icon': Icons.person_add_alt_1_rounded,
            'color': const Color(0xFF059669),
            'title': 'Admissions Under Review',
            'desc': '$_pendingAdmissionsCount new candidate applications require administrative scrutiny.',
            'action': () {
              Navigator.pop(ctx);
              context.go('/school/admissions');
            },
          });
        }

        if (_pendingCertificatesCount > 0) {
          notifications.add({
            'icon': Icons.card_membership_rounded,
            'color': const Color(0xFF7C3AED),
            'title': 'Certificates Pending Signoff',
            'desc': '$_pendingCertificatesCount transfer/bonafide certificates cleared no-dues and require signature.',
            'action': () {
              Navigator.pop(ctx);
              _showUnifiedApprovalsModal(context, filterType: 'Certificate');
            },
          });
        }

        if (_pendingTeacherLeavesCount > 0) {
          notifications.add({
            'icon': Icons.time_to_leave_rounded,
            'color': const Color(0xFF2563EB),
            'title': 'Faculty Leave Applications',
            'desc': '$_pendingTeacherLeavesCount teacher leave requests pending administrative executive approval.',
            'action': () {
              Navigator.pop(ctx);
              _showUnifiedApprovalsModal(context, filterType: 'TeacherLeave');
            },
          });
        }

        if (_openComplaintsList.isNotEmpty) {
          notifications.add({
            'icon': Icons.chat_bubble_outline_rounded,
            'color': const Color(0xFFDC2626),
            'title': 'Parent Inquiries Pending SLA',
            'desc': '${_openComplaintsList.length} grievances open. Require mandatory resolution notes within 48h.',
            'action': () {
              Navigator.pop(ctx);
              _showGrievanceCentreModal(context);
            },
          });
        }

        if (_defaultersCount > 0) {
          notifications.add({
            'icon': Icons.account_balance_wallet_rounded,
            'color': const Color(0xFFD97706),
            'title': 'Fee Defaulters Alert',
            'desc': '$_defaultersCount student accounts have overdue fees exceeding 30-day collection cycle.',
            'action': () {
              Navigator.pop(ctx);
              context.go('/school/fees');
            },
          });
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Executive Notifications & Alerts (N14)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${notifications.length} Actionable institutional signals',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: notifications.isEmpty
                        ? const Center(
                            child: Text('No unread executive alerts. All systems nominal.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          )
                        : ListView.separated(
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (_, idx) {
                              final notif = notifications[idx];
                              final icon = notif['icon'] as IconData;
                              final color = notif['color'] as Color;
                              final title = notif['title'] as String;
                              final desc = notif['desc'] as String;
                              final action = notif['action'] as VoidCallback;

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(icon, color: color, size: 18),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                                subtitle: Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                                onTap: action,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
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
                        Text(
                          _schoolName,
                          style: const TextStyle(
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
                  _buildDrawerItem(
                    Icons.assignment_late_rounded,
                    'Executive Approvals Desk',
                    () {
                      Navigator.pop(context);
                      _showUnifiedApprovalsModal(context);
                    },
                    badgeCount: (_unifiedApprovals['total_count'] as int?) ?? 0,
                  ),
                  _buildDrawerCategory('ACADEMICS & CURRICULUM'),
                  _buildDrawerItem(Icons.menu_book_rounded, 'Lesson Plans & 5E Studio', () => context.go('/school/lesson-plans')),
                  _buildDrawerItem(Icons.fact_check_rounded, 'Examination & Hall Tickets', () => context.go('/school/examination')),
                  _buildDrawerItem(Icons.calendar_month_rounded, 'Timetable & Substitution', () => context.go('/school/timetable')),
                  _buildDrawerItem(Icons.assignment_rounded, 'Homework & Syllabus', () => context.go('/school/homework')),
                  _buildDrawerItem(Icons.description_rounded, 'CBSE Holistic Report Cards', () => context.go('/school/report-card')),
                  _buildDrawerItem(Icons.trending_up_rounded, 'Batch Promotion & Rollover', () => context.go('/school/promotion')),
                  _buildDrawerCategory('STUDENT ADMINISTRATION'),
                  _buildDrawerItem(Icons.person_add_alt_1_rounded, 'Admissions Management', () => context.go('/school/admissions')),
                  _buildDrawerItem(Icons.how_to_reg_rounded, 'Daily Attendance Register', () => context.go('/school/attendance')),
                  _buildDrawerItem(Icons.card_membership_rounded, 'Certificates & No Dues', () => context.go('/school/certificates')),
                  _buildDrawerItem(Icons.chat_bubble_outline_rounded, 'Parent Grievance Centre (N10)', () {
                    Navigator.pop(context);
                    _showGrievanceCentreModal(context);
                  }, badgeCount: _openComplaintsList.length),
                  _buildDrawerItem(Icons.people_alt_rounded, 'Staff Directory & Oversight (N3)', () {
                    Navigator.pop(context);
                    _showStaffOversightModal(context);
                  }),
                  _buildDrawerCategory('FINANCE & OPERATIONS'),
                  _buildDrawerItem(Icons.payment_rounded, 'Fee Accounts & Cashier Desk', () => context.go('/school/fees')),
                  _buildDrawerItem(Icons.directions_bus_rounded, 'Transport Fleet & GPS', () => context.go('/school/transport')),
                  _buildDrawerItem(Icons.local_library_rounded, 'Digital Library & Catalog', () => context.go('/school/library')),
                  _buildDrawerCategory('GOVERNANCE & STATUTORY'),
                  _buildDrawerItem(Icons.analytics_rounded, 'Reports Hub & UDISE+ (N11)', () => context.go('/school/reports')),
                  _buildDrawerItem(Icons.campaign_rounded, 'Official Circulars & Broadcasts (N13)', () {
                    Navigator.pop(context);
                    _showBroadcastCentreModal(context);
                  }),
                  _buildDrawerItem(Icons.history_rounded, 'Audit Trail & Activity Log (N4)', () {
                    Navigator.pop(context);
                    _showAuditTrailModal(context);
                  }),
                  _buildDrawerItem(Icons.settings_outlined, 'Institute Statutory Settings (N5)', () {
                    Navigator.pop(context);
                    _showInstituteSettingsDialog(context);
                  }),
                  _buildDrawerItem(Icons.notifications_outlined, 'Notifications & Alerts (N14)', () {
                    Navigator.pop(context);
                    _showNotificationsInboxModal(context);
                  }),
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

  Widget _buildDrawerItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
    int? badgeCount,
  }) {
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
      trailing: (badgeCount != null && badgeCount > 0)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          : null,
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
