import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../services/school_export_service.dart';

class SchoolParentDashboard extends StatefulWidget {
  const SchoolParentDashboard({super.key});

  @override
  State<SchoolParentDashboard> createState() => _SchoolParentDashboardState();
}

class _SchoolParentDashboardState extends State<SchoolParentDashboard>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  late final TabController _tabController;

  String _parentName = 'Parent';
  bool _isLoading = true;
  String? _errorMessage;

  // Sibling children state
  List<Map<String, dynamic>> _children = [];
  int _selectedChildIndex = 0;

  // Active child state data
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _attendanceData = {};
  Map<String, dynamic> _scholasticData = {};
  Map<String, dynamic> _transportData = {};
  Map<String, dynamic> _feeLedger = {};
  Map<String, dynamic> _timetableData = {};
  Map<String, dynamic> _infirmaryData = {};
  Map<String, dynamic> _cafeteriaData = {};
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _ptmBookings = [];
  List<Map<String, dynamic>> _circulars = [];
  List<Map<String, dynamic>> _gatePasses = [];
  List<Map<String, dynamic>> _homeworkDiary = [];
  Map<String, dynamic> _attendanceTrajectory = {};
  Map<String, dynamic> _examCountdown = {};
  List<Map<String, dynamic>> _liveAlerts = [];
  List<Map<String, dynamic>> _messagesInbox = [];
  int _unreadMessagesCount = 0;

  // Theme constants
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _primary = Color(0xFFDB2777); // Muted Pink Accent
  static const Color _primarySoft = Color(0xFFFDF2F8);
  static const Color _emerald = Color(0xFF059669);
  static const Color _emeraldSoft = Color(0xFFECFDF5);
  static const Color _amber = Color(0xFFD97706);
  static const Color _amberSoft = Color(0xFFFEF3C7);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueSoft = Color(0xFFEFF6FF);
  static const Color _rose = Color(0xFFE11D48);
  static const Color _roseSoft = Color(0xFFFFF1F2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      if (username != null && username.isNotEmpty) {
        _parentName = username;
      }

      final kids = await _schoolService.getParentChildren(username ?? _parentName);
      _children = kids;

      if (_children.isNotEmpty) {
        await _loadSelectedChildDetails(_children[_selectedChildIndex]);
      }

      final circs = await _schoolService.getCirculars();
      _circulars = circs.take(4).map((c) => {
        'title': c['title']?.toString() ?? 'Notice',
        'date': c['published_at']?.toString() ?? 'Recent',
        'category': c['category']?.toString() ?? 'General',
        'content': c['content']?.toString() ?? '',
      }).toList();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to connect to parent student record: $e';
        });
      }
    }
  }

  Future<void> _loadSelectedChildDetails(Map<String, dynamic> child) async {
    final studentId = child['username']?.toString() ?? child['id']?.toString() ?? '';
    final classId = child['class_id']?.toString() ?? '';

    final metrics = await _schoolService.getChildDashboardMetrics(
      studentId: studentId,
      classId: classId,
    );
    final att = await _schoolService.getParentChildAttendanceSummary(studentId);
    final sch = await _schoolService.getParentChildScholasticReport(studentId: studentId, classId: classId);
    final trans = await _schoolService.getParentChildTransportStatus(studentId);
    final ledger = await _schoolService.getParentChildFeeLedger(studentId);
    final timetable = await _schoolService.getParentChildTodayTimetable(classId);
    final infirmary = await _schoolService.getParentChildInfirmaryRecord(studentId);
    final cafeteria = await _schoolService.getParentChildCafeteriaStatus(studentId);
    final teachers = await _schoolService.getParentTeachersDirectory(classId);
    final leaves = await _schoolService.getStudentLeaves(studentId: studentId);
    final ptms = await _schoolService.getPtmBookings(parentUsername: _parentName);
    final gatePasses = await _schoolService.getGatePasses(studentId: studentId);

    final className = child['class_name']?.toString() ?? '';
    final section = child['section']?.toString() ?? '';
    final hwDiary = await _schoolService.getChildHomeworkDiary(
      className: className,
      section: section,
      studentId: studentId,
      classId: classId,
    );
    final attTraj = await _schoolService.getChildAttendanceTrajectory(studentId);
    final examCd = await _schoolService.getChildUpcomingExamCountdown(className: className);
    final alerts = await _schoolService.getParentLiveAlerts(
      parentUsername: _parentName,
      studentId: studentId,
      classId: classId,
      className: className,
    );
    final msgs = await _schoolService.getParentMessagesInbox(
      parentUsername: _parentName,
      childId: studentId,
      classId: classId,
    );

    if (mounted) {
      setState(() {
        _metrics = metrics;
        _attendanceData = att;
        _scholasticData = sch;
        _transportData = trans;
        _feeLedger = ledger;
        _timetableData = timetable;
        _infirmaryData = infirmary;
        _cafeteriaData = cafeteria;
        _teachers = teachers;
        _leaves = leaves;
        _ptmBookings = ptms;
        _gatePasses = gatePasses;
        _homeworkDiary = hwDiary;
        _attendanceTrajectory = attTraj;
        _examCountdown = examCd;
        _liveAlerts = alerts;
        _messagesInbox = msgs;
        _unreadMessagesCount = msgs.where((m) => m['is_read'] != true).length;
      });
    }
  }

  void _onChildChanged(int index) {
    if (index == _selectedChildIndex || index >= _children.length) return;
    setState(() => _selectedChildIndex = index);
    _loadSelectedChildDetails(_children[index]);
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildExecutiveAppBar(),
      drawer: _buildSidebar(),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _children.isEmpty
                  ? _buildNoChildrenLinkedState()
                  : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadInitialData,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      // 1. Sibling Switcher Bar
                      if (_children.length > 1)
                        SliverToBoxAdapter(child: _buildSiblingSwitcherBar()),

                      // 2. Active Child Identity Hero Badge
                      SliverToBoxAdapter(child: _buildChildHeroBadge()),

                      // 3. Morning Transport & Gate Live Status
                      SliverToBoxAdapter(child: _buildSafetyPulseCard()),

                      // 4. Sticky Segmented TabBar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverTabHeaderDelegate(
                          child: Container(
                            color: _bg,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                labelColor: _primary,
                                unselectedLabelColor: _muted,
                                indicatorColor: _primary,
                                indicatorWeight: 3,
                                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                tabs: const [
                                  Tab(icon: Icon(Icons.dashboard_rounded, size: 16), text: '1. Overview & Schedule'),
                                  Tab(icon: Icon(Icons.school_rounded, size: 16), text: '2. CBSE Academics & HPC'),
                                  Tab(icon: Icon(Icons.how_to_reg_rounded, size: 16), text: '3. Attendance & Leaves'),
                                  Tab(icon: Icon(Icons.directions_bus_rounded, size: 16), text: '4. Bus Fleet & Gate Pass'),
                                  Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 16), text: '5. Fee Ledger & Pay'),
                                  Tab(icon: Icon(Icons.people_alt_rounded, size: 16), text: '6. Teachers & PTM'),
                                  Tab(icon: Icon(Icons.health_and_safety_rounded, size: 16), text: '7. Health & Cafeteria'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 5. Active Tab Content
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        sliver: SliverToBoxAdapter(
                          child: AnimatedBuilder(
                            animation: _tabController,
                            builder: (ctx, _) {
                              switch (_tabController.index) {
                                case 0:
                                  return _buildOverviewTab();
                                case 1:
                                  return _buildAcademicsTab();
                                case 2:
                                  return _buildAttendanceTab();
                                case 3:
                                  return _buildTransportTab();
                                case 4:
                                  return _buildFeeLedgerTab();
                                case 5:
                                  return _buildTeachersTab();
                                case 6:
                                  return _buildHealthAndCafeteriaTab();
                                default:
                                  return _buildOverviewTab();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ──────────────────────────────────────────────
  // APP BAR
  // ──────────────────────────────────────────────

  PreferredSizeWidget _buildExecutiveAppBar() {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: _surface,
      foregroundColor: _ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: const Icon(Icons.family_restroom, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome, $_parentName',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Shivalik International School • Parent Portal',
                  style: TextStyle(fontSize: 11, color: _muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified, size: 13, color: _primary),
              SizedBox(width: 4),
              Text(
                'CBSE Affiliated',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Messages & Notices',
          icon: _unreadMessagesCount > 0
              ? Badge.count(
                  count: _unreadMessagesCount,
                  backgroundColor: _primary,
                  child: const Icon(Icons.mail_outline_rounded, size: 20),
                )
              : const Icon(Icons.mail_outline_rounded, size: 20),
          onPressed: _showMessagesInboxModal,
        ),
        IconButton(
          tooltip: 'Refresh Dashboard',
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: _loadInitialData,
        ),
        IconButton(
          tooltip: 'Profile & Settings',
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: _showProfileAndSettingsModal,
        ),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _border, height: 1),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // SIBLING SWITCHER BAR
  // ──────────────────────────────────────────────

  Widget _buildSiblingSwitcherBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_children.length, (idx) {
          final isSelected = idx == _selectedChildIndex;
          final c = _children[idx];
          final name = c['name']?.toString() ?? 'Child';
          final className = c['class_name']?.toString() ?? 'Class';
          final section = c['section']?.toString() ?? 'A';
          final initial = name.isNotEmpty ? name[0] : 'S';

          return Expanded(
            child: InkWell(
              onTap: () => _onChildChanged(idx),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: isSelected ? Colors.white : _primarySoft,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? _primary : _primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$name ($className-$section)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : _ink,
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

  // ──────────────────────────────────────────────
  // CHILD HERO IDENTITY BADGE
  // ──────────────────────────────────────────────

  Widget _buildChildHeroBadge() {
    final child = _currentChild;
    final name = child?['name']?.toString() ?? 'Student';
    final className = child?['class_name']?.toString() ?? 'Class 10';
    final section = child?['section']?.toString() ?? 'A';
    final rollNo = child?['roll_no']?.toString() ?? '01';
    final admissionNo = child?['admission_number']?.toString() ?? (child?['roll_number']?.toString() ?? '--');
    final house = child?['house']?.toString() ?? 'Tagore House (Red)';
    final classTeacher = child?['class_teacher']?.toString() ?? 'Assigned Faculty';
    final bloodGroup = child?['blood_group']?.toString() ?? 'B+';

    final isTagore = house.toLowerCase().contains('tagore');
    final houseColor = isTagore ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primarySoft,
                  border: Border.all(color: houseColor, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0] : 'S',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: houseColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: houseColor.withValues(alpha: 0.30)),
                          ),
                          child: Text(
                            house,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: houseColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$className-$section • Roll No: $rollNo • Adm: $admissionNo',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Class Teacher: $classTeacher',
                      style: const TextStyle(fontSize: 11, color: _ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildIdentityChip(
                icon: Icons.check_circle_rounded,
                label: _attendanceData['today_status']?.toString() ?? 'Not Marked Yet',
                color: _emerald,
                bgColor: _emeraldSoft,
              ),
              _buildIdentityChip(
                icon: Icons.directions_bus_rounded,
                label: (_transportData['assigned'] == true) ? (_transportData['route_name']?.toString() ?? 'School Bus') : 'Self Commute',
                color: _blue,
                bgColor: _blueSoft,
              ),
              _buildIdentityChip(
                icon: Icons.bloodtype_rounded,
                label: 'Blood: $bloodGroup',
                color: _rose,
                bgColor: _roseSoft,
              ),
              _buildIdentityChip(
                icon: Icons.credit_card_rounded,
                label: 'Canteen Wallet: ₹${((_cafeteriaData['wallet_balance'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}',
                color: _amber,
                bgColor: _amberSoft,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // SAFETY & MORNING COMMUTE PULSE CARD
  // ──────────────────────────────────────────────

  Widget _buildSafetyPulseCard() {
    final trans = _transportData;
    if (trans['assigned'] != true) {
      return const SizedBox.shrink();
    }
    final busNo = trans['bus_number']?.toString() ?? 'Assigned Bus';
    final pickup = trans['pickup_actual']?.toString() ?? 'Scheduled';
    final campusDrop = trans['campus_drop_actual']?.toString() ?? 'Recorded at Gate';
    final dropEta = trans['afternoon_drop_estimated']?.toString() ?? 'Afternoon';
    final driverName = trans['driver_name']?.toString() ?? 'Assigned Driver';
    final driverPhone = trans['driver_phone']?.toString() ?? 'Transport Desk';
    final conductorName = trans['conductor_name']?.toString() ?? 'Conductor';
    final conductorPhone = trans['conductor_phone']?.toString() ?? '--';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_rounded, color: _blue, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Transit & Campus Safety Protocol',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _emeraldSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.fiber_manual_record, size: 8, color: _emerald),
                    SizedBox(width: 4),
                    Text('Zero Discrepancy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTransitTimelinePoint(
                  time: '07:28 AM',
                  label: 'Boarded at Stop',
                  detail: pickup,
                  isDone: true,
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: _border),
              Expanded(
                child: _buildTransitTimelinePoint(
                  time: '07:44 AM',
                  label: 'Gate In (Campus)',
                  detail: campusDrop,
                  isDone: true,
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: _border),
              Expanded(
                child: _buildTransitTimelinePoint(
                  time: dropEta,
                  label: 'Afternoon Drop ETA',
                  detail: 'Bus $busNo on schedule',
                  isDone: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(60, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showContactStaffModal(driverName, driverPhone, conductorName, conductorPhone),
                icon: const Icon(Icons.call_rounded, size: 13, color: _primary),
                label: const Text('Call Staff', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(60, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showRequestGatePassModal,
                icon: const Icon(Icons.badge_rounded, size: 13),
                label: const Text('Issue Gate Pass', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransitTimelinePoint({
    required String time,
    required String label,
    required String detail,
    required bool isDone,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: isDone ? _emerald : _muted,
              ),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDone ? _ink : _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
          Text(detail, style: const TextStyle(fontSize: 9, color: _muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: OVERVIEW & SCHEDULE
  // ──────────────────────────────────────────────

  void _showAttendanceDrillDownModal() {
    final att = _attendanceData;
    final attPct = (_attendanceTrajectory['overall_pct'] as num?)?.toDouble() ?? 0.0;
    final isRisk = _attendanceTrajectory['is_cbse_warning_active'] == true;
    final workingDays = (_attendanceTrajectory['days_evaluated'] as num?)?.toInt() ?? 0;
    final present = (_attendanceTrajectory['days_present'] as num?)?.toInt() ?? 0;
    final absent = (_attendanceTrajectory['days_absent'] as num?)?.toInt() ?? 0;
    final lateCount = (_attendanceTrajectory['days_late'] as num?)?.toInt() ?? 0;
    final excused = (_attendanceTrajectory['days_excused'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          maxWidth: 640,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isRisk ? _roseSoft : _emeraldSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRisk ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                      color: isRisk ? _rose : _emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attendance Detail & 30-Day Trajectory',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        Text(
                          'Student: ${_currentChild?['name'] ?? "Student"} (${_currentChild?['class_name'] ?? ""})',
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TODAY\'S STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted)),
                            const SizedBox(height: 3),
                            Text(
                              att['today_status']?.toString() ?? 'Not Marked Yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: (att['today_status']?.toString().contains('Present') ?? false) ? _emerald : _ink,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRisk ? _roseSoft : _emeraldSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${attPct.toStringAsFixed(1)}% OVERALL',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isRisk ? _rose : _emerald),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('30-DAY ATTENDANCE TRAJECTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.remove, color: Color(0xFFDC2626), size: 14),
                      Text(' Red Dashed Line: 75.0% CBSE Statutory Limit', style: TextStyle(fontSize: 10.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: _buildAttendanceTrajectoryChart(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat('Working Days', '$workingDays', _ink, const Color(0xFFF1F5F9))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMiniStat('Present', '$present', _emerald, _emeraldSoft)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMiniStat('Absent', '$absent', _rose, _roseSoft)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMiniStat('Late / Excused', '${lateCount + excused}', _amber, _amberSoft)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/school/attendance');
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Open Full Attendance Register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTrajectoryChart() {
    final points = (_attendanceTrajectory['daily_points'] as List<dynamic>?) ?? [];
    if (points.isEmpty) {
      return Container(
        height: 130,
        alignment: Alignment.center,
        child: const Text('No attendance records logged in the past 30 days', style: TextStyle(color: _muted, fontSize: 12)),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final sc = (points[i]['score'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), sc));
    }

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 110,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) {
              if (v == 75) {
                return const FlLine(color: Color(0xFFDC2626), strokeWidth: 1.5, dashArray: [4, 4]);
              }
              return const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 0.8);
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 25,
                getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 8.5, color: _muted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: (points.length / 5).ceilToDouble().clamp(1, 10),
                getTitlesWidget: (v, m) {
                  final idx = v.toInt();
                  if (idx >= 0 && idx < points.length) {
                    final d = points[idx]['date']?.toString() ?? '';
                    final parts = d.split('-');
                    return Text(parts.length >= 3 ? '${parts[1]}/${parts[2]}' : '', style: const TextStyle(fontSize: 8, color: _muted));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: _emerald,
              barWidth: 2.2,
              dotData: FlDotData(
                show: points.length < 15,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 2.5, color: _emerald, strokeWidth: 1, strokeColor: Colors.white),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _emerald.withValues(alpha: 0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: const Color(0xFF0F172A),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.spotIndex;
                  final pt = (idx >= 0 && idx < points.length) ? points[idx] : null;
                  final date = pt?['date'] ?? '';
                  final status = pt?['status'] ?? '';
                  return LineTooltipItem(
                    '$date\nStatus: ${status.toString().toUpperCase()}',
                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showFeeDrillDownModal() {
    final ledger = _feeLedger;
    final totalAnnual = (ledger['annual_total'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (ledger['total_paid'] as num?)?.toDouble() ?? 0.0;
    final pendingAmount = (ledger['pending_amount'] as num?)?.toDouble() ?? 0.0;
    final heads = (ledger['fee_heads_breakdown'] as List<dynamic>?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          maxWidth: 620,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _amberSoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: _amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fee Ledger & Statutory Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        Text('Student: ${_currentChild?['name'] ?? "Student"} • Due by 5th of every month', style: const TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TOTAL SESSION DUES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted)),
                              const SizedBox(height: 4),
                              Text('₹${totalAnnual.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: _emeraldSoft, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PAID & RECONCILED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald)),
                              const SizedBox(height: 4),
                              Text('₹${totalPaid.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _emerald)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: pendingAmount > 0 ? _amberSoft : _emeraldSoft, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pendingAmount > 0 ? 'PENDING' : 'CLEARED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: pendingAmount > 0 ? _amber : _emerald)),
                              const SizedBox(height: 4),
                              Text('₹${pendingAmount.toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: pendingAmount > 0 ? _amber : _emerald)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('ITEMIZED STATUTORY FEE HEADS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                  const SizedBox(height: 10),
                  ...heads.map((h) {
                    final name = h['head'] ?? 'Fee Head';
                    final ann = (h['annual'] as num?)?.toDouble() ?? 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                          Text('₹${ann.toInt()} / yr', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _ink)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final sId = _currentChild?['username']?.toString() ?? _currentChild?['id']?.toString() ?? '';
                            context.go(sId.isNotEmpty ? '/school/fees?studentId=$sId' : '/school/fees');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            side: const BorderSide(color: _border),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Full Fee Portal'),
                        ),
                      ),
                      if (pendingAmount > 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showPayFeeModal(pendingAmount, 'Session Dues');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Pay Dues Online', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHomeworkDiaryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          maxWidth: 640,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _roseSoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.assignment_rounded, color: _rose, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Homework Diary & Tasks Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        Text('Student: ${_currentChild?['name'] ?? "Student"} (${_currentChild?['class_name'] ?? ""})', style: const TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: _homeworkDiary.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('No homework records assigned for this class cohort yet.', style: TextStyle(color: _muted)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _homeworkDiary.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final hw = _homeworkDiary[i];
                        final title = hw['title']?.toString() ?? 'Assignment';
                        final subj = hw['subject']?.toString() ?? 'General';
                        final due = hw['due_date']?.toString() ?? '';
                        final desc = hw['description']?.toString() ?? '';
                        final status = (hw['status']?.toString() ?? 'pending').toLowerCase();
                        final isSubmitted = status == 'submitted';
                        final isOverdue = status == 'overdue';
                        final teacher = hw['teacher_username']?.toString() ?? 'Faculty';
                        final feedback = hw['teacher_feedback']?.toString();

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _primarySoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(subj, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primary)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSubmitted ? _emeraldSoft : (isOverdue ? _roseSoft : _amberSoft),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isSubmitted ? 'SUBMITTED' : (isOverdue ? 'OVERDUE' : 'PENDING'),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSubmitted ? _emerald : (isOverdue ? _rose : _amber),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(desc, style: const TextStyle(fontSize: 12.5, color: _muted)),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 13, color: _muted),
                                  const SizedBox(width: 4),
                                  Text('Due: $due • Teacher: $teacher', style: const TextStyle(fontSize: 11, color: _muted)),
                                ],
                              ),
                              if (feedback != null && feedback.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.rate_review_outlined, size: 14, color: _emerald),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Teacher Feedback: $feedback',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _ink),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/school/homework');
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open Homework Module'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAlertsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _roseSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: _rose, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Student & Safety Alerts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
              ),
              const Spacer(),
              if (_liveAlerts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _roseSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_liveAlerts.length} Active',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _rose),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_liveAlerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _emeraldSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _emerald.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: _emerald, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All clear: No critical student alerts or attendance flags for ${_currentChild?['name'] ?? "your child"} today.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _emerald),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._liveAlerts.take(3).map((alert) {
              final type = alert['type']?.toString() ?? 'alert';
              final title = alert['title']?.toString() ?? 'Alert';
              final body = alert['body']?.toString() ?? '';
              final route = alert['link_route']?.toString() ?? '';

              Color color;
              Color bg;
              IconData icon;

              if (type == 'absence') {
                color = _rose;
                bg = _roseSoft;
                icon = Icons.person_off_rounded;
              } else if (type == 'fee_due') {
                color = _amber;
                bg = _amberSoft;
                icon = Icons.account_balance_wallet_rounded;
              } else if (type == 'homework') {
                color = _blue;
                bg = _blueSoft;
                icon = Icons.assignment_rounded;
              } else {
                color = _primary;
                bg = _primarySoft;
                icon = Icons.campaign_rounded;
              }

              return InkWell(
                onTap: () {
                  if (route.isNotEmpty) {
                    context.go(route);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: _ink)),
                            const SizedBox(height: 2),
                            Text(body, style: const TextStyle(fontSize: 11, color: _muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOverviewMessagesSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.forum_rounded, color: _primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Messages & Teacher Broadcasts',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showMessagesInboxModal,
                child: const Text('View All Inbox', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_messagesInbox.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No active messages or teacher broadcasts for this class cohort.', style: TextStyle(color: _muted, fontSize: 12)),
              ),
            )
          else
            ..._messagesInbox.take(3).map((m) {
              final sender = m['sender']?.toString() ?? 'Faculty';
              final subj = m['subject']?.toString() ?? 'Notice';
              final body = m['body']?.toString() ?? '';
              final isTeacher = m['type'] == 'teacher_message';
              final isClass = m['type'] == 'class_announcement';

              return InkWell(
                onTap: _showMessagesInboxModal,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isTeacher ? _emeraldSoft : (isClass ? _blueSoft : _primarySoft),
                        child: Icon(
                          isTeacher ? Icons.person_rounded : (isClass ? Icons.campaign_rounded : Icons.article_rounded),
                          size: 14,
                          color: isTeacher ? _emerald : (isClass ? _blue : _primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(sender, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _ink)),
                                Text(
                                  isTeacher ? '1:1 Thread' : (isClass ? 'Class Notice' : 'Circular'),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isTeacher ? _emerald : _muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(subj, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink)),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(body, style: const TextStyle(fontSize: 11, color: _muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showLiveAlertsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          maxWidth: 640,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _roseSoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.notifications_active_rounded, color: _rose, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Student & Safety Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        Text('Real dynamic updates derived from school registers', style: TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: _liveAlerts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('All clear: No critical student alerts or attendance flags.', style: TextStyle(color: _muted)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _liveAlerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final a = _liveAlerts[i];
                        final title = a['title']?.toString() ?? 'Alert';
                        final body = a['body']?.toString() ?? '';
                        final route = a['link_route']?.toString() ?? '';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink)),
                              const SizedBox(height: 4),
                              Text(body, style: const TextStyle(fontSize: 12, color: _muted)),
                              if (route.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      context.go(route);
                                    },
                                    child: const Text('Open Module', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessagesInboxModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.90,
            maxWidth: 680,
          ),
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.forum_rounded, color: _primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Parent Communication Inbox', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                          Text('Student: ${_currentChild?['name'] ?? "Child"} (${_currentChild?['class_name'] ?? ""})', style: const TextStyle(fontSize: 12, color: _muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: _primary,
                unselectedLabelColor: _muted,
                indicatorColor: _primary,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(icon: Icon(Icons.campaign_outlined, size: 16), text: 'Broadcasts & Notices'),
                  Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 16), text: '1:1 Teacher Threads'),
                ],
              ),
              const Divider(height: 1, color: _border),
              Flexible(
                child: TabBarView(
                  children: [
                    // Tab 1: Broadcasts & Notices
                    _messagesInbox.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('No announcements or circulars received yet.', style: TextStyle(color: _muted)),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _messagesInbox.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (c, i) {
                              final m = _messagesInbox[i];
                              final sender = m['sender']?.toString() ?? 'Faculty';
                              final subj = m['subject']?.toString() ?? 'Notice';
                              final body = m['body']?.toString() ?? '';
                              final src = m['source']?.toString() ?? 'School';
                              final dt = m['created_at']?.toString() ?? '';

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(6)),
                                          child: Text(src, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _primary)),
                                        ),
                                        if (dt.isNotEmpty)
                                          Text(dt.contains('T') ? dt.split('T')[0] : dt, style: const TextStyle(fontSize: 11, color: _muted)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(subj, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _ink)),
                                    const SizedBox(height: 4),
                                    Text(body, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    Text('From: $sender', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _muted)),
                                  ],
                                ),
                              );
                            },
                          ),

                    // Tab 2: 1:1 Teacher Thread & Compose
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _primarySoft,
                                  child: Icon(Icons.school_rounded, color: _primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentChild?['class_teacher'] ?? 'Class Teacher',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink),
                                      ),
                                      Text(
                                        'Class Mentor • ${_currentChild?['class_name'] ?? ""} ${_currentChild?['section'] ?? ""}',
                                        style: const TextStyle(fontSize: 11, color: _muted),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showComposeTeacherMessageModal();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.send_rounded, size: 14),
                                  label: const Text('Send Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: _schoolService.getParentTeacherThread(
                                parentUsername: _parentName,
                                studentId: _currentChild?['username']?.toString() ?? _currentChild?['id']?.toString() ?? '',
                                teacherId: _currentChild?['class_teacher_id']?.toString() ?? 'classteacher',
                              ),
                              builder: (c, snap) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final threads = snap.data ?? [];
                                if (threads.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.mark_chat_unread_outlined, size: 40, color: _muted.withValues(alpha: 0.4)),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No direct messages exchanged with ${_currentChild?['class_teacher'] ?? "the teacher"} yet.',
                                          style: const TextStyle(color: _muted, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Tap "Send Message" above to initiate a direct query.',
                                          style: TextStyle(color: _muted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: threads.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (c, idx) {
                                    final th = threads[idx];
                                    final isParent = th['sender_role'] == 'parent';
                                    final b = th['body']?.toString() ?? '';
                                    final sub = th['subject']?.toString() ?? '';
                                    final time = th['created_at']?.toString() ?? '';

                                    return Align(
                                      alignment: isParent ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 320),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isParent ? _primarySoft : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: isParent ? _primary.withValues(alpha: 0.25) : _border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (sub.isNotEmpty)
                                              Text(sub, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isParent ? _primary : _ink)),
                                            Text(b, style: const TextStyle(fontSize: 12.5, color: _ink)),
                                            const SizedBox(height: 4),
                                            Text(
                                              time.contains('T') ? time.split('T')[0] : time,
                                              style: TextStyle(fontSize: 9.5, color: isParent ? _primary.withValues(alpha: 0.7) : _muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
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

  void _showComposeTeacherMessageModal() {
    final subCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final teacherName = _currentChild?['class_teacher'] ?? 'Class Teacher';
    final teacherId = _currentChild?['class_teacher_id']?.toString() ?? 'classteacher';
    final studentId = _currentChild?['username']?.toString() ?? _currentChild?['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.mail_outline_rounded, color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Direct Message to Teacher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                  Text('Recipient: $teacherName', style: const TextStyle(fontSize: 12, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SUBJECT / TOPIC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)),
            const SizedBox(height: 6),
            TextField(
              controller: subCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Query regarding Science Project',
                hintStyle: const TextStyle(fontSize: 13, color: _muted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            const Text('MESSAGE BODY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)),
            const SizedBox(height: 6),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your message to the class faculty...',
                hintStyle: const TextStyle(fontSize: 13, color: _muted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final sub = subCtrl.text.trim();
              final body = bodyCtrl.text.trim();
              if (body.isEmpty) return;

              Navigator.pop(ctx);
              final ok = await _schoolService.sendMessageToTeacher(
                parentUsername: _parentName,
                studentId: studentId,
                teacherId: teacherId,
                teacherName: teacherName,
                subject: sub.isNotEmpty ? sub : 'Parent Query',
                body: body,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Message delivered to $teacherName.' : 'Message dispatched.'),
                    backgroundColor: _primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                // Refresh data
                final child = _currentChild;
                if (child != null) {
                  _loadSelectedChildDetails(child);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final attPct = (_metrics['attendance'] as num?)?.toDouble() ?? 0.0;
    final feesPending = _metrics['pendingFeesDisplay']?.toString() ?? '₹0';
    final hwCount = (_metrics['pendingHomework'] as num?)?.toInt() ?? 0;
    final lastResult = _metrics['lastResult']?.toString() ?? 'No record';

    final isCbseWarning = _attendanceTrajectory['is_cbse_warning_active'] == true;
    final shortageDays = (_attendanceTrajectory['cbse_shortage_days'] as num?)?.toInt() ?? 0;

    final periods = (_timetableData['periods'] as List<dynamic>?) ?? [];
    final activeSubject = _timetableData['active_subject']?.toString() ?? 'Classes Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PN4: CBSE Statutory < 75% Attendance Warning Banner
        if (isCbseWarning)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'CBSE Statutory Attendance Warning',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '${attPct.toStringAsFixed(1)}% < 75%',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your child has an attendance of ${attPct.toStringAsFixed(1)}%, which is below the statutory 75.0% board minimum ($shortageDays days short). Regular attendance is strictly mandatory for board examination hall-ticket eligibility.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showAttendanceDrillDownModal,
                        child: const Text(
                          'View Attendance Trajectory & Excused Leaves →',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // PN2: Real Live Student & Safety Alerts Card
        _buildLiveAlertsCard(),

        // 2. PN12: Upcoming Exam Countdown & Datesheet Banner
        if (_examCountdown['has_upcoming'] == true)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_note_rounded, color: _primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _examCountdown['title']?.toString() ?? 'Upcoming Term Examination',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                      ),
                      Text(
                        _examCountdown['countdown_text']?.toString() ?? 'CBSE Assessment Cycle',
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/school/timetable'),
                  icon: const Icon(Icons.calendar_today_rounded, size: 13),
                  label: const Text('Datesheet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

        // 3. PM9: 4 Master KPI Tiles with Deep Drill-downs
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Attendance',
                value: '${attPct.toStringAsFixed(1)}%',
                subtitle: attPct > 0 ? '${attPct.toStringAsFixed(1)}% Present' : 'Attendance unrecorded',
                icon: Icons.how_to_reg_rounded,
                color: isCbseWarning ? _rose : _emerald,
                bgColor: isCbseWarning ? _roseSoft : _emeraldSoft,
                onTap: _showAttendanceDrillDownModal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Term Fee Dues',
                value: feesPending,
                subtitle: feesPending == '₹0' ? 'No outstanding dues' : 'Academic session dues',
                icon: Icons.account_balance_wallet_rounded,
                color: feesPending != '₹0' ? _amber : _emerald,
                bgColor: feesPending != '₹0' ? _amberSoft : _emeraldSoft,
                onTap: _showFeeDrillDownModal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Pending Homework',
                value: '$hwCount Active',
                subtitle: hwCount > 0 ? '$hwCount tasks due' : 'All assignments submitted',
                icon: Icons.assignment_rounded,
                color: hwCount > 0 ? _rose : _emerald,
                bgColor: hwCount > 0 ? _roseSoft : _emeraldSoft,
                onTap: _showHomeworkDiaryModal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Summative Grade',
                value: lastResult,
                subtitle: lastResult.contains('(') ? 'CBSE Scale Assessment' : 'Term evaluation pending',
                icon: Icons.workspace_premium_rounded,
                color: _primary,
                bgColor: _primarySoft,
                onTap: () => _showOfficialHpcModal(_scholasticData),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. PN3: Today's Homework Diary Section
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _roseSoft, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.menu_book_rounded, color: _rose, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Homework Diary & Daily Tasks',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _showHomeworkDiaryModal,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                    child: const Text('View All Diary →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_homeworkDiary.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 36, color: _muted),
                      SizedBox(height: 8),
                      Text('No Active Homework Assigned', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _ink)),
                      Text('All assignments for this cohort are up to date.', style: TextStyle(fontSize: 11.5, color: _muted)),
                    ],
                  ),
                )
              else
                ..._homeworkDiary.take(3).map((hw) {
                  final title = hw['title']?.toString() ?? 'Task';
                  final subj = hw['subject']?.toString() ?? 'General';
                  final due = hw['due_date']?.toString() ?? 'Upcoming';
                  final status = (hw['status']?.toString() ?? 'pending').toLowerCase();
                  final isSubmitted = status == 'submitted';
                  final isOverdue = status == 'overdue';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSubmitted ? _emerald : (isOverdue ? _rose : _amber),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ink)),
                              const SizedBox(height: 2),
                              Text('$subj • Due: $due', style: const TextStyle(fontSize: 11, color: _muted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSubmitted ? _emeraldSoft : (isOverdue ? _roseSoft : _amberSoft),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSubmitted ? 'SUBMITTED' : (isOverdue ? 'OVERDUE' : 'PENDING'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSubmitted ? _emerald : (isOverdue ? _rose : _amber),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),

        // PN1 & PM11: Messages & Teacher Broadcasts Section
        _buildOverviewMessagesSection(),

        // Today's Live Class Timetable Tracker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.schedule_rounded, color: _primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Period Schedule (Live Tracker)",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _emeraldSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _emerald.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: _emerald, size: 8),
                        const SizedBox(width: 4),
                        Text(
                          'Now: $activeSubject',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (periods.isEmpty)
                const Center(child: Text('No timetable entries found for today.', style: TextStyle(color: _muted, fontSize: 12)))
              else
                ...periods.map((p) {
                  final isLive = p['is_live'] == true;
                  final periodNo = p['period']?.toString() ?? '1';
                  final time = p['time']?.toString() ?? '';
                  final sub = p['subject']?.toString() ?? '';
                  final room = p['room']?.toString() ?? '';
                  final teacher = p['teacher']?.toString() ?? '';
                  final topic = p['topic']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLive ? _primarySoft : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLive ? _primary : _border,
                        width: isLive ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isLive ? _primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isLive ? _primary : _border),
                          ),
                          child: Center(
                            child: Text(
                              'P$periodNo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isLive ? Colors.white : _ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    sub,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isLive ? _primary : _ink,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('• $room', style: const TextStyle(fontSize: 11, color: _muted)),
                                  if (isLive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'LIVE',
                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '$time • $teacher (${topic.isNotEmpty ? topic : "Regular Class"})',
                                style: const TextStyle(fontSize: 10, color: _muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Recent Teacher Commendation Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _amberSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star_rounded, color: _amber, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Teacher Commendation & Diary Note',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scholasticData['class_teacher_remarks']?.toString() ?? 'No pastoral observations submitted by subject faculty for today.',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: _ink),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '— ${_currentChild?['class_teacher'] ?? 'Class Teacher'} • Academic Observation',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // PN5: My Reports Hub & 14 Official Excel Exports
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _emeraldSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: _emerald, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'My Reports Hub (14 Official Excel Packs)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _showParentReportsHubModal,
                    icon: const Icon(Icons.download_rounded, size: 14, color: _emerald),
                    label: const Text('Open Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _emerald)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Generate authentic per-child Excel (.xlsx) dossiers: Attendance Velocity (PAR-R01), CBSE Statutory 75% Audit (PAR-R03), Subject Progress (PAR-R05), Fee Ledgers (PAR-R08), and Monthly Progress Pack (PAR-R14).',
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showParentReportsHubModal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.assessment_rounded, size: 16, color: _emerald),
                  label: const Text('Browse All 14 Per-Child Reports', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        // Official Circulars
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: _primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'School Circulars & Event Notices',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/school/circulars'),
                    child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_circulars.isEmpty)
                const Center(child: Text('No notices published today.', style: TextStyle(color: _muted, fontSize: 12)))
              else
                ..._circulars.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.campaign_outlined, color: _primary, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['title'] ?? 'Notice',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
                                ),
                                Text(
                                  c['date'] ?? 'Recent',
                                  style: const TextStyle(fontSize: 10, color: _muted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _blueSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c['category'] ?? 'General',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _blue),
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.2),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: _muted)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: CBSE ACADEMICS & HPC
  // ──────────────────────────────────────────────

  Widget _buildAcademicsTab() {
    final sch = _scholasticData;
    final pct = (sch['overall_percentage'] as num?)?.toDouble() ?? 0.0;
    final grade = sch['overall_grade']?.toString() ?? 'N/A';
    final rank = sch['cbse_rank']?.toString() ?? 'N/A';
    final remarks = sch['class_teacher_remarks']?.toString() ?? '';
    final subjects = (sch['scholastic_subjects'] as List<dynamic>?) ?? [];
    final coScholastic = (sch['co_scholastic_activities'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Performance Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFC7D2FE)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primary,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    grade,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${pct.toStringAsFixed(1)}% Aggregate',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _emeraldSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rank,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'CBSE 8-Point Holistic Progress Card (HPC) Assessment',
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showOfficialHpcModal(sch),
                icon: const Icon(Icons.print_rounded, size: 14),
                label: const Text('Print HPC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Subject Breakdown Matrix
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: _primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Subject-wise Scholastic Evaluation',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...subjects.map((s) {
                final sub = s['subject']?.toString() ?? '';
                final obtained = (s['obtained'] as num?)?.toInt() ?? 0;
                final total = (s['total_marks'] as num?)?.toInt() ?? 100;
                final sGrade = s['grade']?.toString() ?? 'A1';
                final percentile = s['percentile']?.toString() ?? '95th';
                final teacher = s['teacher']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            sGrade,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: _primary, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                            Text('Taught by: $teacher', style: const TextStyle(fontSize: 10, color: _muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$obtained / $total',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink),
                          ),
                          Text(
                            'Percentile: $percentile',
                            style: const TextStyle(fontSize: 10, color: _emerald, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Co-Scholastic & Life Skills
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.palette_rounded, color: _primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Co-Scholastic & Life Skills (5-Point Scale)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...coScholastic.map((c) {
                final act = c['activity']?.toString() ?? '';
                final gr = c['grade']?.toString() ?? 'A';
                final desc = c['description']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _emeraldSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(gr, style: const TextStyle(fontWeight: FontWeight.w900, color: _emerald, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(act, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                            Text(desc, style: const TextStyle(fontSize: 10, color: _muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Teacher Remarks
        if (remarks.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote_rounded, color: _primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Class Teacher Holistic Reflection',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  remarks,
                  style: const TextStyle(fontSize: 12, color: _ink, height: 1.4),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // TAB 3: ATTENDANCE & LEAVES
  // ──────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    final att = _attendanceData;
    final pct = (att['attendance_pct'] as num?)?.toDouble() ?? 0.0;
    final totalDays = (att['total_working_days'] as num?)?.toInt() ?? 0;
    final present = (att['days_present'] as num?)?.toInt() ?? 0;
    final absent = (att['days_absent'] as num?)?.toInt() ?? 0;
    final medical = (att['medical_leaves'] as num?)?.toInt() ?? 0;
    final logs = (att['recent_scan_logs'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attendance Stats Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _emeraldSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: _emerald, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CBSE Statutory Attendance Rate',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _emerald),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: _emerald,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatPill('Total Days', '$totalDays', _muted),
                  _buildStatPill('Present', '$present', _emerald),
                  _buildStatPill('Absent', '$absent', _rose),
                  _buildStatPill('Medical', '$medical', _amber),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Biometric Turnstile Logs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fingerprint_rounded, color: _primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Biometric Gate Turnstile Logs (Recent)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...logs.map((l) {
                final date = l['date']?.toString() ?? '';
                final inTime = l['entry_time']?.toString() ?? '';
                final outTime = l['exit_time']?.toString() ?? '';
                final st = l['status']?.toString() ?? '';
                final gate = l['gate']?.toString() ?? '';

                final isLate = st.toLowerCase().contains('late');
                final isMed = st.toLowerCase().contains('medical');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isLate
                              ? _amberSoft
                              : isMed
                                  ? _blueSoft
                                  : _emeraldSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isLate
                              ? Icons.alarm
                              : isMed
                                  ? Icons.medical_services_rounded
                                  : Icons.login_rounded,
                          color: isLate
                              ? _amber
                              : isMed
                                  ? _blue
                                  : _emerald,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$date • $gate', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                            Text('In: $inTime  |  Out: $outTime', style: const TextStyle(fontSize: 11, color: _muted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLate
                              ? _amberSoft
                              : isMed
                                  ? _blueSoft
                                  : _emeraldSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          st,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isLate
                                ? _amber
                                : isMed
                                    ? _blue
                                    : _emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Leave Requests History & Action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.event_note_rounded, color: _primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Student Leave History',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showApplyLeaveModal,
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Apply Leave', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_leaves.isEmpty)
                const Center(child: Text('No leave applications filed for this child.', style: TextStyle(color: _muted, fontSize: 12)))
              else
                ..._leaves.map((l) {
                  final st = l['status']?.toString() ?? 'Pending';
                  final isApp = st.toLowerCase().contains('approved');
                  final isRej = st.toLowerCase().contains('rejected');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isApp ? _emeraldSoft : isRej ? _roseSoft : _amberSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isApp ? Icons.check_circle : isRej ? Icons.cancel : Icons.hourglass_top,
                            color: isApp ? _emerald : isRej ? _rose : _amber,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l['type']} (${l['start_date']} to ${l['end_date']})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                              ),
                              Text('Reason: ${l['reason']}', style: const TextStyle(fontSize: 11, color: _muted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isApp ? _emeraldSoft : isRej ? _roseSoft : _amberSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            st,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isApp ? _emerald : isRej ? _rose : _amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // TAB 4: BUS FLEET & GATE PASS
  // ──────────────────────────────────────────────

  Widget _buildTransportTab() {
    final trans = _transportData;
    if (trans['assigned'] != true) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: const Column(
          children: [
            Icon(Icons.directions_bus_outlined, size: 48, color: _muted),
            SizedBox(height: 12),
            Text(
              'No Bus Route Assigned',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
            ),
            SizedBox(height: 6),
            Text(
              'This child is registered for self-commute / parent drop-off. If you require campus bus transit, please contact the school transport department.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
      );
    }
    final busNo = trans['bus_number']?.toString() ?? 'Assigned Bus';
    final route = trans['route_name']?.toString() ?? 'Campus Bus Route';
    final stop = trans['stop_name']?.toString() ?? 'Designated Stop';
    final driverName = trans['driver_name']?.toString() ?? 'Assigned Driver';
    final driverPhone = trans['driver_phone']?.toString() ?? 'Transport Desk';
    final conductorName = trans['conductor_name']?.toString() ?? 'Conductor';
    final conductorPhone = trans['conductor_phone']?.toString() ?? '--';
    final cctv = trans['cctv_status']?.toString() ?? '2 Cameras Active';
    final gps = trans['gps_status']?.toString() ?? 'AIS-140 Compliant';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bus Info Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _blueSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: _blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fleet Bus: $busNo',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        Text(route, style: const TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _emeraldSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Route Scheduled', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: _rose),
                  const SizedBox(width: 6),
                  const Text('Designated Stop: ', style: TextStyle(fontSize: 12, color: _muted)),
                  Text(stop, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.videocam_rounded, size: 16, color: _primary),
                  const SizedBox(width: 6),
                  Text('Security: $cctv • $gps', style: const TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Staff Contacts
        Row(
          children: [
            Expanded(
              child: _buildStaffContactCard(
                role: 'Driver',
                name: driverName,
                phone: driverPhone,
                icon: Icons.person_rounded,
                color: _blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStaffContactCard(
                role: 'Bus Conductor',
                name: conductorName,
                phone: conductorPhone,
                icon: Icons.support_agent_rounded,
                color: _emerald,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Emergency Gate Pass Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.badge_rounded, color: _primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Campus Early Gate Passes',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showRequestGatePassModal,
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Issue Pass', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_gatePasses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Center(
                    child: Text(
                      'No emergency gate passes issued. Tap "Issue Pass" if you need to authorize early pickup.',
                      style: TextStyle(color: _muted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ..._gatePasses.map((gp) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _emeraldSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: _emerald, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pass #${gp['pass_no']} • Exit: ${gp['exit_time']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                                ),
                                Text(
                                  'Pickup: ${gp['pickup_person']} • ${gp['reason']}',
                                  style: const TextStyle(fontSize: 11, color: _muted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _emeraldSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Security Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald)),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffContactCard({
    required String role,
    required String name,
    required String phone,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(role, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 2),
          Text(phone, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 5: FEE LEDGER & 1-CLICK PAY
  // ──────────────────────────────────────────────

  Widget _buildFeeLedgerTab() {
    final ledger = _feeLedger;
    final totalAnnual = (ledger['annual_total'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (ledger['total_paid'] as num?)?.toDouble() ?? 0.0;
    final pendingAmount = (ledger['pending_amount'] as num?)?.toDouble() ?? 0.0;
    final nextDue = ledger['next_due_date']?.toString() ?? 'Fully Cleared';
    final nextInst = ledger['next_installment_name']?.toString() ?? 'Academic Dues';
    final heads = (ledger['fee_heads_breakdown'] as List<dynamic>?) ?? [];
    final receipts = (ledger['receipts'] as List<dynamic>?) ?? [];

    final isAllCleared = pendingAmount <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fee Ledger Overview Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isAllCleared ? _emerald : _amber),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isAllCleared
                  ? [const Color(0xFFECFDF5), Colors.white]
                  : [const Color(0xFFFEF3C7), Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isAllCleared ? _emeraldSoft : _amberSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isAllCleared ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                          color: isAllCleared ? _emerald : _amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAllCleared ? 'No Dues Pending' : 'Upcoming Installment: $nextInst',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isAllCleared ? _emerald : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isAllCleared ? '₹0 Pending' : '₹${pendingAmount.toInt()} Due',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isAllCleared ? _emerald : _amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isAllCleared
                    ? 'All academic quarters for the current session are fully cleared.'
                    : 'Payment Due Date: $nextDue • Late fine applicable after due date.',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Annual Total: ₹${totalAnnual.toInt()}', style: const TextStyle(fontSize: 11, color: _muted)),
                        Text('Paid: ₹${totalPaid.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _emerald)),
                      ],
                    ),
                  ),
                  if (!isAllCleared)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showPayFeeModal(pendingAmount, nextInst),
                      icon: const Icon(Icons.payment_rounded, size: 15),
                      label: const Text('Pay Online Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Fee Heads Breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: _primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Fee Heads Schedule (Itemized Statutory Breakdown)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...heads.map((h) {
                final head = h['head']?.toString() ?? '';
                final qtr = (h['quarterly'] as num?)?.toDouble() ?? 0.0;
                final ann = (h['annual'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(head, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${qtr.toInt()} / qtr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                          Text('Annual: ₹${ann.toInt()}', style: const TextStyle(fontSize: 10, color: _muted)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Paid Invoices & Receipts History
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_edu_rounded, color: _primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Paid Receipts & Reconciled Invoices',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...receipts.map((r) {
                final recNo = r['receipt_no']?.toString() ?? '';
                final qtr = r['quarter']?.toString() ?? '';
                final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
                final date = r['paid_date']?.toString() ?? '';
                final mode = r['payment_mode']?.toString() ?? 'Online';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _emeraldSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: _emerald, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(qtr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                            Text('$recNo • Paid on: $date ($mode)', style: const TextStyle(fontSize: 10, color: _muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${amt.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _emerald)),
                          InkWell(
                            onTap: () => _showReceiptModal(r),
                            child: const Text('View PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // TAB 6: TEACHERS & PTM
  // ──────────────────────────────────────────────

  Widget _buildTeachersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Buttons Row (PN9: 1:1 Direct Teacher Message, PTM, Grievance)
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => _showComposeTeacherMessageModal(),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Message Class Teacher (${_currentChild?['class_teacher'] ?? "Faculty"})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showBookPtmModal,
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Schedule PTM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _rose,
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showGrievancesDeskModal,
                    icon: const Icon(Icons.report_problem_outlined, size: 16),
                    label: const Text('Principal Grievance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Scheduled PTM Appointments
        if (_ptmBookings.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_available_rounded, color: _emerald, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Confirmed PTM Appointments',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._ptmBookings.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _emeraldSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _emerald.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.video_call_rounded, color: _emerald, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'With ${p['teacher']} • ${p['date']} (${p['time_slot']})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
                                ),
                                Text('Agenda: ${p['agenda']}', style: const TextStyle(fontSize: 11, color: _muted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _emerald,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Confirmed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 18, color: _rose),
                            tooltip: 'Cancel Appointment',
                            onPressed: () async {
                              final bId = p['id']?.toString() ?? '';
                              if (bId.isEmpty) return;
                              final ok = await _schoolService.cancelPtmBooking(bookingId: bId);
                              if (ok && mounted) {
                                final child = _currentChild;
                                if (child != null) _loadSelectedChildDetails(child);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('PTM Appointment cancelled.'), backgroundColor: _rose),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Subject Teachers Directory
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: _primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Subject Teachers Directory',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._teachers.map((t) {
                final name = t['name']?.toString() ?? '';
                final sub = t['subject']?.toString() ?? '';
                final desig = t['designation']?.toString() ?? '';
                final email = t['email']?.toString() ?? '';
                final room = t['room']?.toString() ?? '';
                final color = Color(t['avatar_color'] as int? ?? 0xFF2563EB);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0] : 'T',
                          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                            Text('$sub • $desig', style: const TextStyle(fontSize: 11, color: _muted)),
                            Text('$room • $email', style: const TextStyle(fontSize: 10, color: _muted)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: const BorderSide(color: Color(0xFFC7D2FE)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(50, 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _prefillPtmTeacher(name),
                        child: const Text('Book PTM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // TAB 7: HEALTH & CAFETERIA
  // ──────────────────────────────────────────────

  Widget _buildHealthAndCafeteriaTab() {
    final inf = _infirmaryData;
    final blood = inf['blood_group']?.toString() ?? 'B+';
    final bmi = inf['bmi']?.toString() ?? '19.8 (Normal)';
    final allergies = inf['known_allergies']?.toString() ?? 'Dust, Peanuts (Mild)';
    final visits = (inf['clinic_visits'] as List<dynamic>?) ?? [];

    final cafe = _cafeteriaData;
    final balance = (cafe['wallet_balance'] as num?)?.toDouble() ?? 450.0;
    final spendLimit = (cafe['daily_spend_limit'] as num?)?.toDouble() ?? 150.0;
    final lunchMenu = cafe['today_lunch_menu'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Health Profile Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _roseSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: _rose, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Infirmary & Medical Health',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        Text('Campus Medical Officer: Dr. R. K. Singhal', style: TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _roseSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Blood $blood', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _rose)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatPill('Height', '168 cm', _ink),
                  _buildStatPill('Weight', '56.5 kg', _ink),
                  _buildStatPill('BMI Index', bmi, _emerald),
                  _buildStatPill('Vision', '6/6 (L/R)', _blue),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: _rose),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Documented Allergies: $allergies',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Recent Infirmary Visits:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 6),
              ...visits.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${v['date']} (${v['time']})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
                            Text(v['attended_by'] ?? '', style: const TextStyle(fontSize: 10, color: _muted)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Symptoms: ${v['symptoms']}', style: const TextStyle(fontSize: 10, color: _rose)),
                        Text('Treatment: ${v['treatment']}', style: const TextStyle(fontSize: 10, color: _muted)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Smart Cafeteria Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _amberSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: _amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Canteen RFID Wallet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        Text('Balance: ₹${balance.toInt()} • Limit: ₹${spendLimit.toInt()}/day', style: const TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showRechargeCanteenModal(balance),
                    child: const Text('Top Up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),

              // Today's Lunch Menu
              const Text("Today's FSSAI Pure Veg Nutrition Menu:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lunchMenu['title']?.toString() ?? 'Nutritious Shivalik Thali',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _emerald),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lunchMenu['items']?.toString() ?? '',
                      style: const TextStyle(fontSize: 11, color: _ink),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('⚡ ${lunchMenu['calories']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _amber)),
                        const SizedBox(width: 12),
                        Text('🥩 ${lunchMenu['protein']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _blue)),
                        const SizedBox(width: 12),
                        const Text('🌱 Pure Vegetarian', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _emerald)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // MODALS & DIALOGS
  // ──────────────────────────────────────────────

  void _showOfficialHpcModal(Map<String, dynamic> sch) {
    final child = _currentChild;
    final name = child?['name']?.toString() ?? 'Student';
    final className = child?['class_name']?.toString() ?? 'Class 10';
    final section = child?['section']?.toString() ?? 'A';
    final rollNo = child?['roll_no']?.toString() ?? '01';
    final admNo = child?['admission_number']?.toString() ?? 'SCH2024-1001';
    final subjects = (sch['scholastic_subjects'] as List<dynamic>?) ?? [];
    final pct = (sch['overall_percentage'] as num?)?.toDouble() ?? 0.0;
    final grade = sch['overall_grade']?.toString() ?? 'N/A';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.school, size: 36, color: _primary),
                      const SizedBox(height: 6),
                      const Text(
                        'SHIVALIK INTERNATIONAL SCHOOL',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink),
                      ),
                      const Text(
                        'Affiliated to CBSE, New Delhi (Affiliation No: 3530124)',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                      const Text(
                        'HOLISTIC PROGRESS CARD (HPC) • SESSION 2025-26',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Student: $name', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                    Text('Class & Sec: $className-$section', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                    Text('Roll No: $rollNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                    Text('Adm: $admNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                  ],
                ),
                const SizedBox(height: 14),
                Table(
                  border: TableBorder.all(color: _border),
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: [
                        Padding(padding: EdgeInsets.all(8), child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Max', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Obt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                    ),
                    ...subjects.map((s) => TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(s['subject'] ?? '', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${s['total_marks']}', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${s['obtained']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(s['grade'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primary))),
                          ],
                        )),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Aggregate: ${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _emerald)),
                    Text('Final Grade: $grade', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _primary)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Container(height: 1, width: 120, color: _muted),
                        const SizedBox(height: 4),
                        const Text('Class Teacher Signature', style: TextStyle(fontSize: 10, color: _muted)),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: _primary),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('SEAL VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _primary)),
                        ),
                        const SizedBox(height: 4),
                        const Text('Principal Seal', style: TextStyle(fontSize: 10, color: _muted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPayFeeModal(double amount, String quarter) {
    final child = _currentChild;
    final name = child?['name']?.toString() ?? 'Student';
    final studentId = child?['username']?.toString() ?? child?['id']?.toString() ?? '';

    String selectedMode = 'UPI (GPay / PhonePe / Paytm)';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.payment_rounded, color: _primary),
              const SizedBox(width: 8),
              const Text('Pay School Fees Online', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Installment: $quarter', style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Payable:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('₹${amount.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _primary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Select Payment Gateway / Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedMode,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: const [
                  DropdownMenuItem(value: 'UPI (GPay / PhonePe / Paytm)', child: Text('UPI (GPay / PhonePe / Paytm)')),
                  DropdownMenuItem(value: 'Net Banking (HDFC / SBI / ICICI)', child: Text('Net Banking (HDFC / SBI / ICICI)')),
                  DropdownMenuItem(value: 'Credit / Debit Card', child: Text('Credit / Debit Card')),
                ],
                onChanged: (v) => setDlgState(() => selectedMode = v ?? selectedMode),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _schoolService.payChildFeeInstallment(
                  studentId: studentId,
                  studentName: name,
                  quarter: quarter,
                  amount: amount,
                  paymentMode: selectedMode,
                );
                await _loadSelectedChildDetails(child!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment Successful! Receipt #${res['receipt_no']} issued.'),
                      backgroundColor: _emerald,
                    ),
                  );
                }
              },
              child: const Text('Confirm & Pay'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptModal(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Official Fee Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt Number: ${r['receipt_no']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Quarter: ${r['quarter']}'),
            Text('Amount Paid: ₹${(r['amount'] as num?)?.toInt()}'),
            Text('Date: ${r['paid_date']}'),
            Text('Mode: ${r['payment_mode']}'),
            Text('Transaction ID: ${r['transaction_id']}'),
            const SizedBox(height: 12),
            const Text('Status: 🟢 Bank Verified & Reconciled', style: TextStyle(color: _emerald, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showBookPtmModal() {
    final child = _currentChild;
    final studentName = child?['name']?.toString() ?? 'Student';

    String selectedTeacher = _teachers.isNotEmpty ? _teachers.first['name'] : 'Class Teacher';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 2));
    String timeSlot = '02:30 PM - 02:45 PM';
    final agendaCtrl = TextEditingController(text: 'Review Summative Assessment & STEM performance');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Book Parent-Teacher Meeting (PTM)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: $studentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Select Teacher:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                DropdownButtonFormField<String>(
                  initialValue: selectedTeacher,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: _teachers
                      .map((t) => DropdownMenuItem(value: t['name']?.toString() ?? '', child: Text(t['name']?.toString() ?? '')))
                      .toList(),
                  onChanged: (v) => setDlgState(() => selectedTeacher = v ?? selectedTeacher),
                ),
                const SizedBox(height: 12),
                const Text('Appointment Date:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setDlgState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Time Slot:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                DropdownButtonFormField<String>(
                  initialValue: timeSlot,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: '02:30 PM - 02:45 PM', child: Text('02:30 PM - 02:45 PM')),
                    DropdownMenuItem(value: '02:45 PM - 03:00 PM', child: Text('02:45 PM - 03:00 PM')),
                    DropdownMenuItem(value: '03:00 PM - 03:15 PM', child: Text('03:00 PM - 03:15 PM')),
                    DropdownMenuItem(value: '03:15 PM - 03:30 PM', child: Text('03:15 PM - 03:30 PM')),
                  ],
                  onChanged: (v) => setDlgState(() => timeSlot = v ?? timeSlot),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: agendaCtrl,
                  decoration: const InputDecoration(labelText: 'Meeting Agenda / Focus', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _schoolService.bookPtmSlot(
                  parentUsername: _parentName,
                  studentName: studentName,
                  teacherName: selectedTeacher,
                  date: selectedDate.toIso8601String().split('T')[0],
                  timeSlot: timeSlot,
                  agenda: agendaCtrl.text.trim(),
                );
                await _loadSelectedChildDetails(child!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PTM slot booked with $selectedTeacher!'), backgroundColor: _emerald),
                  );
                }
              },
              child: const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }

  void _prefillPtmTeacher(String teacherName) {
    _tabController.animateTo(5);
    _showBookPtmModal();
  }

  void _showApplyLeaveModal() {
    final child = _currentChild;
    final studentId = child?['username']?.toString() ?? child?['id']?.toString() ?? '';
    final studentName = child?['name']?.toString() ?? 'Student';
    final classId = child?['class_id']?.toString() ?? '';

    String leaveType = 'Medical Leave';
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Apply Leave: $studentName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: leaveType,
                  decoration: const InputDecoration(labelText: 'Leave Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Medical Leave', child: Text('Medical Leave')),
                    DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
                    DropdownMenuItem(value: 'Family Function', child: Text('Family Function')),
                    DropdownMenuItem(value: 'Emergency Leave', child: Text('Emergency Leave')),
                  ],
                  onChanged: (v) => setDlgState(() => leaveType = v ?? leaveType),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text('From: ${startDate.toIso8601String().split('T')[0]}'),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (p != null) setDlgState(() => startDate = p);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text('To: ${endDate.toIso8601String().split('T')[0]}'),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (p != null) setDlgState(() => endDate = p);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Doctor Advice',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _schoolService.applyStudentLeave(
                  studentId: studentId,
                  studentName: studentName,
                  classId: classId,
                  leaveType: leaveType,
                  startDate: startDate.toIso8601String().split('T')[0],
                  endDate: endDate.toIso8601String().split('T')[0],
                  reason: reasonCtrl.text.trim(),
                  appliedBy: _parentName,
                );
                await _loadSelectedChildDetails(child!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Leave filed and sent to Class Teacher.'), backgroundColor: _emerald),
                  );
                }
              },
              child: const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestGatePassModal() {
    final child = _currentChild;
    final studentId = child?['username']?.toString() ?? child?['id']?.toString() ?? '';
    final studentName = child?['name']?.toString() ?? 'Student';
    final className = child?['class_name']?.toString() ?? 'Class 10';

    final personCtrl = TextEditingController(text: _parentName);
    final relationCtrl = TextEditingController(text: 'Father');
    final phoneCtrl = TextEditingController(text: '+91 98970-11223');
    final reasonCtrl = TextEditingController(text: 'Scheduled Dental Checkup');
    String exitTime = '12:30 PM';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Issue Campus Early Gate Pass', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: $studentName ($className)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: personCtrl,
                decoration: const InputDecoration(labelText: 'Authorized Pickup Person Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: relationCtrl,
                decoration: const InputDecoration(labelText: 'Relationship to Child', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Contact Phone Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Early Departure', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _schoolService.requestGatePass(
                studentId: studentId,
                studentName: studentName,
                className: className,
                reason: reasonCtrl.text.trim(),
                expectedExitTime: exitTime,
                pickupPersonName: personCtrl.text.trim(),
                pickupPersonRelation: relationCtrl.text.trim(),
                pickupPersonPhone: phoneCtrl.text.trim(),
                isAuthorizedOnRecord: true,
              );
              await _loadSelectedChildDetails(child!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gate Pass authorized and sent to Main Gate Security!'), backgroundColor: _emerald),
                );
              }
            },
            child: const Text('Authorize Gate Pass'),
          ),
        ],
      ),
    );
  }

  void _showParentReportsHubModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final child = _currentChild;
          final sName = child?['name']?.toString() ?? 'Student';
          final cName = child?['class_name']?.toString() ?? 'Class';
          final attPct = (_attendanceTrajectory['overall_pct'] as num?)?.toDouble() ?? (_metrics['attendance'] as num?)?.toDouble() ?? 0.0;
          final dailyPoints = (_attendanceTrajectory['daily_points'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? <Map<String, dynamic>>[];
          final workingDays = (_attendanceTrajectory['days_evaluated'] as num?)?.toInt() ?? 0;
          final present = (_attendanceTrajectory['days_present'] as num?)?.toInt() ?? 0;
          final absent = (_attendanceTrajectory['days_absent'] as num?)?.toInt() ?? 0;
          final lateCount = (_attendanceTrajectory['days_late'] as num?)?.toInt() ?? 0;
          final excused = (_attendanceTrajectory['days_excused'] as num?)?.toInt() ?? 0;
          final shortage = (_attendanceTrajectory['cbse_shortage_days'] as num?)?.toInt() ?? 0;

          final subs = (_scholasticData['subjects'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? <Map<String, dynamic>>[];
          final hwList = _homeworkDiary;
          final ledger = _feeLedger;
          final leavesList = _leaves;
          final ptmList = _ptmBookings;
          final transport = _transportData;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.90,
              maxWidth: 720,
            ),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _emeraldSoft, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.table_chart_rounded, color: _emerald, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Official Per-Child Reports Hub', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                            Text('Active Student: $sName ($cName) • Dual-Sheet Excel (.xlsx) Standards', style: const TextStyle(fontSize: 12, color: _muted)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _border),

                // Multi-child switcher inside reports hub (PM14)
                if (_children.length > 1)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: List.generate(_children.length, (idx) {
                        final isSel = idx == _selectedChildIndex;
                        final k = _children[idx];
                        final name = k['name']?.toString() ?? 'Child';
                        final cls = k['class_name']?.toString() ?? '';
                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              _onChildChanged(idx);
                              setSheetState(() {});
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: isSel ? _primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$name ($cls)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : _muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // PAR-R01
                      _buildReportItem(
                        code: 'PAR-R01',
                        title: 'Attendance Trend (30-Day Velocity)',
                        desc: 'Line chart trajectory with red dashed 75% CBSE statutory threshold. Daily rows + monthly summary.',
                        hasChart: true,
                        onChart: () => _showAttendanceDrillDownModal(),
                        onDownload: () => SchoolExportService.exportParentAttendanceTrendExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          attendancePct: attPct,
                          dailyPoints: dailyPoints,
                        ),
                      ),

                      // PAR-R02
                      _buildReportItem(
                        code: 'PAR-R02',
                        title: 'Attendance Register (Date-Wise Log)',
                        desc: 'Complete register rows of Present, Absent, Late, and Excused entries with summary totals.',
                        hasChart: false,
                        onDownload: () => SchoolExportService.exportParentAttendanceRegisterExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          totalDays: workingDays,
                          presentDays: present,
                          absentDays: absent,
                          lateDays: lateCount,
                          excusedDays: excused,
                          records: dailyPoints,
                        ),
                      ),

                      // PAR-R03
                      _buildReportItem(
                        code: 'PAR-R03',
                        title: 'CBSE Statutory 75% Attendance Warning Audit',
                        desc: 'Board exam hall ticket eligibility evaluation. Monthly rows, shortage recovery days, and condonation flags.',
                        hasChart: true,
                        onChart: () => _showAttendanceDrillDownModal(),
                        onDownload: () => SchoolExportService.exportParentAttendanceWarningExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          attendancePct: attPct,
                          totalWorkingDays: workingDays,
                          shortageDays: shortage,
                        ),
                      ),

                      // PAR-R04
                      _buildReportItem(
                        code: 'PAR-R04',
                        title: 'Marks Trend (Exam-to-Exam Progression)',
                        desc: 'Exam-wise progression line across Half Yearly and Final terms with CBSE 9-point scale grading.',
                        hasChart: true,
                        onChart: () => _showOfficialHpcModal(_scholasticData),
                        onDownload: () => SchoolExportService.exportParentMarksTrendExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          subjectRows: subs,
                        ),
                      ),

                      // PAR-R05
                      _buildReportItem(
                        code: 'PAR-R05',
                        title: 'Subject-Wise Performance & Focus Breakdown',
                        desc: 'Bar chart averages per subject, max marks vs marks obtained, percentage, and teacher feedback.',
                        hasChart: true,
                        onChart: () => _showOfficialHpcModal(_scholasticData),
                        onDownload: () => SchoolExportService.exportParentSubjectPerformanceExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          subjects: subs,
                        ),
                      ),

                      // PAR-R06
                      _buildReportItem(
                        code: 'PAR-R06',
                        title: 'CBSE Holistic Progress Card (HPC) Summary',
                        desc: 'Comprehensive scholastic and co-scholastic domain scores, rank in cohort, and Principal validation remarks.',
                        hasChart: false,
                        onDownload: () => SchoolExportService.exportParentReportCardSummaryExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          scholasticData: _scholasticData,
                        ),
                      ),

                      // PAR-R07
                      _buildReportItem(
                        code: 'PAR-R07',
                        title: 'Homework Completion & Task Register',
                        desc: 'Task-by-task submission ledger: title, subject, due date, submission timestamp, and faculty grading remarks.',
                        hasChart: true,
                        onChart: () => _showHomeworkDiaryModal(),
                        onDownload: () => SchoolExportService.exportParentHomeworkCompletionExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          homeworkDiary: hwList,
                        ),
                      ),

                      // PAR-R08
                      _buildReportItem(
                        code: 'PAR-R08',
                        title: 'Statutory Fee Statement & Ledger Breakdown',
                        desc: '12-Month schedule (April-March), itemized fee heads (Tuition, IT, Lab, Sports), paid vs due, and late fines.',
                        hasChart: true,
                        onChart: () => _showFeeDrillDownModal(),
                        onDownload: () => SchoolExportService.exportParentFeeStatementExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          feeLedger: ledger,
                        ),
                      ),

                      // PAR-R09
                      _buildReportItem(
                        code: 'PAR-R09',
                        title: 'Fee Receipts & Reconciled Payments History',
                        desc: 'Chronological payment receipts register: official receipt no, amount, payment mode, bank transaction ID.',
                        hasChart: false,
                        onDownload: () async {
                          final receipts = await _schoolService.getStudentReceipts(child?['username']?.toString() ?? child?['id']?.toString() ?? '');
                          if (ctx.mounted) {
                            SchoolExportService.exportParentFeeReceiptsExcel(
                              context: context,
                              parentUsername: _parentName,
                              studentName: sName,
                              className: cName,
                              receipts: receipts,
                            );
                          }
                        },
                      ),

                      // PAR-R10
                      _buildReportItem(
                        code: 'PAR-R10',
                        title: 'Student Leave Applications & Medical Decisions',
                        desc: 'Dossier of student leave requests: category (Medical, Casual), start date, end date, days count, and decision status.',
                        hasChart: false,
                        onDownload: () => SchoolExportService.exportParentLeaveHistoryExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          leaves: leavesList,
                        ),
                      ),

                      // PAR-R11
                      _buildReportItem(
                        code: 'PAR-R11',
                        title: 'Parent-Teacher Meeting (PTM) Appointment Register',
                        desc: 'History of booked appointments: faculty member, date, time slot, discussion agenda, and status.',
                        hasChart: false,
                        onDownload: () => SchoolExportService.exportParentPtmHistoryExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          ptmBookings: ptmList,
                        ),
                      ),

                      // PAR-R12
                      _buildReportItem(
                        code: 'PAR-R12',
                        title: 'Parent Grievance Dossier & Resolution Audit',
                        desc: 'Statutory escalation log: ticket no, domain category, description, and school leadership response remarks.',
                        hasChart: false,
                        onDownload: () async {
                          final grievances = await _schoolService.getParentComplaints(parentUsername: _parentName);
                          if (ctx.mounted) {
                            SchoolExportService.exportParentGrievanceHistoryExcel(
                              context: context,
                              parentUsername: _parentName,
                              studentName: sName,
                              className: cName,
                              grievances: grievances,
                            );
                          }
                        },
                      ),

                      // PAR-R13
                      _buildReportItem(
                        code: 'PAR-R13',
                        title: 'Transport Attendance & Commute Safety Telematics',
                        desc: 'RFID stop verification logs: morning home pickup, campus gate in-sensor scan, and afternoon drop ETA.',
                        hasChart: false,
                        onDownload: () => SchoolExportService.exportParentTransportAttendanceExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          transportData: transport,
                        ),
                      ),

                      // PAR-R14
                      _buildReportItem(
                        code: 'PAR-R14',
                        title: 'Monthly Progress Pack (Multi-Sheet Comprehensive Dossier)',
                        desc: 'The master dossier: 5 specialized sheets covering Executive Summary, Attendance Velocity, Academics, Tasks, and Fees.',
                        hasChart: true,
                        isPrimary: true,
                        onChart: () => _showOfficialHpcModal(_scholasticData),
                        onDownload: () => SchoolExportService.exportParentMonthlyProgressPackExcel(
                          context: context,
                          parentUsername: _parentName,
                          studentName: sName,
                          className: cName,
                          attendancePct: attPct,
                          scholasticData: _scholasticData,
                          homeworkDiary: hwList,
                          feeLedger: ledger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportItem({
    required String code,
    required String title,
    required String desc,
    required VoidCallback onDownload,
    bool hasChart = false,
    VoidCallback? onChart,
    bool isPrimary = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary ? _primarySoft : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isPrimary ? _primary.withValues(alpha: 0.3) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPrimary ? _primary : _ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _emeraldSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('MASTER PACK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _ink)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11.5, color: _muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasChart && onChart != null) ...[
                OutlinedButton.icon(
                  onPressed: onChart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.show_chart_rounded, size: 14),
                  label: const Text('Chart View', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPrimary ? _primary : _emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: Text(
                    isPrimary ? 'Download Master Pack (.xlsx)' : 'Download Excel (.xlsx)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGrievancesDeskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.90,
            maxWidth: 680,
          ),
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _roseSoft, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.report_problem_outlined, color: _rose, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Parent Grievance & Complaint Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                          Text('Statutory escalation tracker with School Leadership', style: TextStyle(fontSize: 12, color: _muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showFileComplaintModal();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('File New Grievance to Principal', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _schoolService.getParentComplaints(parentUsername: _parentName),
                  builder: (c, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
                    }
                    final complaints = snap.data ?? [];
                    if (complaints.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text('No complaints or grievances filed yet.', style: TextStyle(color: _muted)),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: complaints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (c, i) {
                        final g = complaints[i];
                        final tNo = g['ticket_no']?.toString() ?? 'TKT';
                        final sub = g['subject']?.toString() ?? 'Grievance';
                        final cat = g['category']?.toString() ?? 'General';
                        final desc = g['description']?.toString() ?? '';
                        final status = (g['status']?.toString() ?? 'Submitted').toLowerCase();
                        final dt = g['created_at']?.toString() ?? '';
                        final adminReply = g['admin_reply']?.toString() ?? '';

                        final isResolved = status.contains('resolved');
                        final isInReview = status.contains('review');

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
                                    child: Text(tNo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ink)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isResolved ? _emeraldSoft : (isInReview ? _blueSoft : _amberSoft),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isResolved ? 'RESOLVED' : (isInReview ? 'IN REVIEW' : 'SUBMITTED'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isResolved ? _emerald : (isInReview ? _blue : _amber),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(sub, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _ink)),
                              const SizedBox(height: 3),
                              Text('$cat • Logged: ${dt.contains("T") ? dt.split("T")[0] : dt}', style: const TextStyle(fontSize: 11, color: _muted)),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                              ],
                              if (adminReply.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _emeraldSoft,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _emerald.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: _emerald, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Leadership Response: $adminReply',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (isResolved) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      final ok = await _schoolService.reopenParentComplaint(complaintId: g['id']?.toString() ?? '');
                                      if (ok) {
                                        setSheetState(() {});
                                      }
                                    },
                                    icon: const Icon(Icons.replay_rounded, size: 14, color: _rose),
                                    label: const Text('Reopen Ticket', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _rose)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
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
  }

  void _showFileComplaintModal() {
    final child = _currentChild;
    final studentName = child?['name']?.toString() ?? 'Student';

    String category = 'Academic Curriculum';
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Principal Grievance Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Complaint Domain', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Academic Curriculum', child: Text('Academic Curriculum')),
                    DropdownMenuItem(value: 'Transport Fleet & Route', child: Text('Transport Fleet & Route')),
                    DropdownMenuItem(value: 'Fee & Accounts', child: Text('Fee & Accounts')),
                    DropdownMenuItem(value: 'Hygiene & Campus Canteen', child: Text('Hygiene & Campus Canteen')),
                    DropdownMenuItem(value: 'Safety & Anti-Bullying', child: Text('Safety & Anti-Bullying')),
                  ],
                  onChanged: (v) => setDlgState(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject Line', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Detailed Observation', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _rose, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _schoolService.fileParentComplaint(
                  parentUsername: _parentName,
                  studentName: studentName,
                  category: category,
                  subject: subjectCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Grievance registered under Ticket #${res['ticket_no']}. Principal notified.'), backgroundColor: _emerald),
                  );
                }
              },
              child: const Text('Submit to Principal'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRechargeCanteenModal(double currentBalance) {
    final child = _currentChild;
    final studentId = child?['username']?.toString() ?? child?['id']?.toString() ?? '';
    double topUp = 500.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Top Up Canteen RFID Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Wallet Balance: ₹${currentBalance.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Select Top Up Amount:', style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ChoiceChip(label: const Text('+₹200'), selected: topUp == 200, onSelected: (_) => setDlgState(() => topUp = 200)),
                  ChoiceChip(label: const Text('+₹500'), selected: topUp == 500, onSelected: (_) => setDlgState(() => topUp = 500)),
                  ChoiceChip(label: const Text('+₹1000'), selected: topUp == 1000, onSelected: (_) => setDlgState(() => topUp = 1000)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _schoolService.rechargeCafeteriaWallet(studentId: studentId, amount: topUp);
                await _loadSelectedChildDetails(child!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Canteen wallet recharged with ₹${topUp.toInt()}!'), backgroundColor: _emerald),
                  );
                }
              },
              child: const Text('Confirm Top Up'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactStaffModal(String driverName, String driverPhone, String condName, String condPhone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Transport Staff Direct Line', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: _blueSoft, child: Icon(Icons.person, color: _blue)),
              title: Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('Bus Driver • $driverPhone'),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: _emeraldSoft, child: Icon(Icons.support_agent, color: _emerald)),
              title: Text(condName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('Bus Conductor • $condPhone'),
            ),
            const Divider(),
            const Text('Transport Manager: +91 135-2749921 (School Helpline)', style: TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showMaterialsSheet(String classId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          maxWidth: 640,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.folder_shared_rounded, color: _primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LMS Study Materials & Worksheets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        Text('Digital courseware published by subject faculty', style: TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _schoolService.getStudyMaterials(classId: classId),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _primary)));
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 48, color: _muted),
                            SizedBox(height: 12),
                            Text('No Course Materials Uploaded', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
                            SizedBox(height: 6),
                            Text('Subject teachers have not uploaded downloadable worksheets for this class cohort yet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: _muted)),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = list[i];
                      final title = item['title']?.toString() ?? 'Study Material';
                      final subj = item['subject']?.toString() ?? 'General';
                      final author = item['uploaded_by']?.toString() ?? 'Faculty';
                      final url = item['file_url']?.toString();

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: _primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _ink)),
                                  const SizedBox(height: 3),
                                  Text('$subj • Uploaded by $author', style: const TextStyle(fontSize: 11.5, color: _muted)),
                                ],
                              ),
                            ),
                            if (url != null && url.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: _primary),
                                tooltip: 'Download',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Downloading $title...'), backgroundColor: _emerald),
                                  );
                                },
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: const Text('Reference Only', style: TextStyle(fontSize: 10, color: _muted)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyChildrenModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          maxWidth: 620,
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.people_alt_rounded, color: _primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Children Registry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        Text('Officially linked students under your guardianship', style: TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: _children.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No student records currently linked.', style: TextStyle(color: _muted)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _children.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final child = _children[i];
                        final name = child['name']?.toString() ?? 'Student';
                        final className = child['class_name']?.toString() ?? 'Class';
                        final section = child['section']?.toString() ?? '';
                        final roll = child['roll_number']?.toString() ?? child['roll_no']?.toString() ?? '--';
                        final adm = child['admission_number']?.toString() ?? '--';
                        final rel = child['relation']?.toString() ?? 'Child';
                        final isSelected = i == _selectedChildIndex;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? _primarySoft : _surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isSelected ? _primary : _border, width: isSelected ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isSelected ? _primary : const Color(0xFFF1F5F9),
                                child: Text(
                                  name.isNotEmpty ? name[0] : 'S',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: isSelected ? Colors.white : _ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
                                        if (isSelected) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)),
                                            child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text('$className${section.isNotEmpty ? "-$section" : ""} • Roll #$roll • Adm: $adm', style: const TextStyle(fontSize: 12, color: _muted)),
                                    const SizedBox(height: 2),
                                    Text('Linked as: $rel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primary)),
                                  ],
                                ),
                              ),
                              if (!isSelected)
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _onChildChanged(i);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _primary,
                                    side: const BorderSide(color: _primary),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 36),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showLinkChildRequestDialog();
                  },
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text('+ Link Another Child'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileAndSettingsModal() {
    bool alertAbsence = true;
    bool alertHomework = true;
    bool alertFees = true;
    bool alertPtm = true;
    bool alertCirculars = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            maxWidth: 620,
          ),
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.manage_accounts_rounded, color: _primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profile & Parent Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                          Text('Notification preferences & account oversight', style: TextStyle(fontSize: 12, color: _muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Profile Header Tile
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _primary,
                            child: Text(
                              _parentName.isNotEmpty ? _parentName[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_parentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink)),
                                const SizedBox(height: 2),
                                const Text('Shivalik International School • Parent Portal', style: TextStyle(fontSize: 12, color: _muted)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: _emeraldSoft, borderRadius: BorderRadius.circular(6)),
                                      child: const Text('VERIFIED GUARDIAN', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _emerald)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('${_children.length} Students Linked', style: const TextStyle(fontSize: 11, color: _muted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notification Preferences Section
                    const Text('INSTANT NOTIFICATION PREFERENCES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: _primary,
                            title: const Text('Absence & Late Arrival Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('Immediate in-app and SMS alert if student is marked absent', style: TextStyle(fontSize: 11, color: _muted)),
                            value: alertAbsence,
                            onChanged: (v) => setSheetState(() => alertAbsence = v),
                          ),
                          const Divider(height: 1, color: _border),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: _primary,
                            title: const Text('Homework & Assignment Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('Daily digest when subject faculty assign new homework', style: TextStyle(fontSize: 11, color: _muted)),
                            value: alertHomework,
                            onChanged: (v) => setSheetState(() => alertHomework = v),
                          ),
                          const Divider(height: 1, color: _border),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: _primary,
                            title: const Text('Fee Dues & Payment Receipts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('5th of month due date reminder and payment confirmation', style: TextStyle(fontSize: 11, color: _muted)),
                            value: alertFees,
                            onChanged: (v) => setSheetState(() => alertFees = v),
                          ),
                          const Divider(height: 1, color: _border),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: _primary,
                            title: const Text('PTM Schedule & Meeting Confirmations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('Appointment reminders for booked parent-teacher conferences', style: TextStyle(fontSize: 11, color: _muted)),
                            value: alertPtm,
                            onChanged: (v) => setSheetState(() => alertPtm = v),
                          ),
                          const Divider(height: 1, color: _border),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: _primary,
                            title: const Text('Emergency Circulars & Weather Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                            subtitle: const Text('Official statutory updates and campus weather holidays', style: TextStyle(fontSize: 11, color: _muted)),
                            value: alertCirculars,
                            onChanged: (v) => setSheetState(() => alertCirculars = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Security & Privacy Action
                    const Text('DATA PRIVACY & CHILD SAFETY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showReportWrongLinkDialog();
                      },
                      icon: const Icon(Icons.shield_outlined, size: 16, color: _rose),
                      label: const Text('Report Incorrect Child Linkage'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _rose,
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Parent notification preferences saved successfully.'),
                            backgroundColor: _emerald,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
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

  void _showReportWrongLinkDialog() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Report Incorrect Student Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If any student profile linked to your portal does not belong to your family, report it immediately to lock access and alert school administration.',
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter student name or roll number and explain discrepancy...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Discrepancy report filed. The administrative security desk will review this within 4 hours.'),
                  backgroundColor: _rose,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _rose, foregroundColor: Colors.white),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // DRAWER
  // ──────────────────────────────────────────────

  Widget _buildSidebar() {
    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: const Center(
                      child: Icon(Icons.family_restroom_rounded, color: _primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_parentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_children.length} Linked ${_children.length == 1 ? "Child" : "Children"}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('CBSE K-12', style: TextStyle(fontSize: 10, color: _muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                children: [
                  _buildDrawerSectionHeader('CORE & COMMUNICATION'),
                  _buildDrawerTile(Icons.dashboard_rounded, 'Dashboard Home', () => Navigator.pop(context), isActive: true),
                  _buildDrawerTile(Icons.event_note_rounded, 'Academic Calendar & Milestones', () {
                    Navigator.pop(context);
                    context.push('/school/calendar');
                  }),
                  _buildDrawerTile(Icons.chat_bubble_outline_rounded, 'Messages & Teacher Inbox', () {
                    Navigator.pop(context);
                    _showMessagesInboxModal();
                  }, badgeCount: _unreadMessagesCount),
                  _buildDrawerTile(Icons.notifications_active_outlined, 'Live Safety Alerts', () {
                    Navigator.pop(context);
                    _showLiveAlertsModal();
                  }, badgeCount: _liveAlerts.length),
                  _buildDrawerTile(Icons.badge_outlined, 'My Children Registry', () {
                    Navigator.pop(context);
                    _showMyChildrenModal();
                  }),

                  _buildDrawerSectionHeader('DAILY OPERATIONS & ACADEMICS'),
                  _buildDrawerTile(Icons.how_to_reg_rounded, 'Daily Attendance & Logs', () {
                    Navigator.pop(context);
                    context.go('/school/attendance');
                  }),
                  _buildDrawerTile(Icons.menu_book_rounded, 'Homework Diary', () {
                    Navigator.pop(context);
                    context.go('/school/homework');
                  }),
                  _buildDrawerTile(Icons.account_balance_wallet_outlined, 'Fees & Receipts Statement', () {
                    Navigator.pop(context);
                    final sId = _currentChild?['username']?.toString() ?? _currentChild?['id']?.toString() ?? '';
                    context.go(sId.isNotEmpty ? '/school/fees?studentId=$sId' : '/school/fees');
                  }),
                  _buildDrawerTile(Icons.bar_chart_rounded, 'My Reports & Analytics', () {
                    Navigator.pop(context);
                    _showParentReportsHubModal();
                  }),
                  _buildDrawerTile(Icons.handshake_outlined, 'PTM Meeting Bookings', () {
                    Navigator.pop(context);
                    _showBookPtmModal();
                  }),
                  _buildDrawerTile(Icons.report_problem_outlined, 'Parent Grievance Desk', () {
                    Navigator.pop(context);
                    _showGrievancesDeskModal();
                  }),
                  _buildDrawerTile(Icons.campaign_outlined, 'Official School Circulars', () {
                    Navigator.pop(context);
                    context.go('/school/circulars');
                  }),
                  _buildDrawerTile(Icons.directions_bus_outlined, 'Bus Fleet & Commute', () {
                    Navigator.pop(context);
                    context.go('/school/transport');
                  }),
                  _buildDrawerTile(Icons.description_outlined, 'CBSE Report Cards & HPC', () {
                    Navigator.pop(context);
                    context.go('/school/report-card');
                  }),
                  _buildDrawerTile(Icons.calendar_month_outlined, 'Weekly Timetable Schedule', () {
                    Navigator.pop(context);
                    context.go('/school/timetable');
                  }),
                  _buildDrawerTile(Icons.local_library_outlined, 'Campus Library Catalog', () {
                    Navigator.pop(context);
                    context.go('/school/library');
                  }),
                  _buildDrawerTile(Icons.card_membership_outlined, 'Certificates & No Dues', () {
                    Navigator.pop(context);
                    context.go('/school/certificates');
                  }),
                  _buildDrawerTile(Icons.folder_shared_outlined, 'LMS Study Materials', () {
                    Navigator.pop(context);
                    final child = _currentChild;
                    _showMaterialsSheet(child?['class_id']?.toString() ?? '');
                  }),

                  _buildDrawerSectionHeader('ACCOUNT & SETTINGS'),
                  _buildDrawerTile(Icons.settings_outlined, 'Profile & Settings', () {
                    Navigator.pop(context);
                    _showProfileAndSettingsModal();
                  }),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: _rose, size: 20),
                title: const Text('Sign Out', style: TextStyle(color: _rose, fontWeight: FontWeight.w700, fontSize: 13)),
                minLeadingWidth: 24,
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () async {
                  await _authService.logout();
                  if (mounted) context.go('/login');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String label, VoidCallback onTap, {bool isActive = false, int badgeCount = 0}) {
    return ListTile(
      leading: Icon(icon, color: isActive ? _primary : _muted, size: 19),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? _primary : _ink,
        ),
      ),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: onTap,
      dense: true,
      selected: isActive,
      selectedTileColor: _primarySoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ──────────────────────────────────────────────
  // STATES
  // ──────────────────────────────────────────────

  Widget _buildNoChildrenLinkedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF2F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.family_restroom_rounded, size: 36, color: Color(0xFFDB2777)),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Student Profile Linked',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Your parent account "$_parentName" currently has no linked student records in the active academic registry. To view your child\'s live attendance, grades, and fee ledger, request a linking below or contact administration.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted, height: 1.45),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => _showLinkChildRequestDialog(),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Request Child Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDB2777),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkChildRequestDialog() {
    final admCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Submit Child Linking Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your child\'s official school admission number and date of birth for automated registry verification.',
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: admCtrl,
              decoration: const InputDecoration(
                labelText: 'Admission Number (e.g. SCH2024-1001)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dobCtrl,
              decoration: const InputDecoration(
                labelText: 'Date of Birth (YYYY-MM-DD)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Linking request submitted to School Administration. Verification pending within 24 hours.'),
                  backgroundColor: Color(0xFF059669),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB2777), foregroundColor: Colors.white),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Switcher Bar Skeleton
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(width: 32, height: 32, decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Container(width: 120, height: 14, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                const Spacer(),
                Container(width: 32, height: 32, decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Container(width: 100, height: 14, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 12),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Child Hero Badge Skeleton
          Container(
            height: 130,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 160, height: 18, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 10),
                      Container(width: 220, height: 12, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 10),
                      Container(width: 140, height: 12, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4 KPI Cards Grid Skeleton
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 94,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 70, height: 11, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 50, height: 20, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: 90, height: 10, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 94,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 70, height: 11, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 60, height: 20, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: 90, height: 10, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 94,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 80, height: 11, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 45, height: 20, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: 95, height: 10, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 94,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 80, height: 11, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 65, height: 20, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: 100, height: 10, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Schedule Card Skeleton
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 180, height: 16, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                Container(width: double.infinity, height: 38, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 10),
                Container(width: double.infinity, height: 38, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 10),
                Container(width: double.infinity, height: 38, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10))),
              ],
            ),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: _rose),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverTabHeaderDelegate({required this.child});

  @override
  double get minExtent => 64.0;
  @override
  double get maxExtent => 64.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SliverTabHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
