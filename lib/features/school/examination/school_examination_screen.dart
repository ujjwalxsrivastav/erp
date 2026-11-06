import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class SchoolExaminationScreen extends StatefulWidget {
  const SchoolExaminationScreen({super.key});

  @override
  State<SchoolExaminationScreen> createState() =>
      _SchoolExaminationScreenState();
}

class _SchoolExaminationScreenState extends State<SchoolExaminationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _schoolService = SchoolService();

  bool _isLoading = true;
  String? _errorMessage;

  // Data
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _dateSheet = [];
  List<Map<String, dynamic>> _admitCandidates = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _evaluationProgress = [];

  // Active filters
  String _selectedSessionId = 'sess-midterm-2026';
  String _selectedClassId = 'Class 10-A';
  String _searchCandidateQuery = '';

  final List<String> _classList = [
    'Class 10-A',
    'Class 10-B',
    'Class 9-A',
    'Class 9-B',
    'Class 11-Science',
    'Class 11-Commerce',
    'Class 12-Science',
    'Class 12-Commerce',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      final sessions = await _schoolService.getSchoolExamSessions();
      final sessionId =
          sessions.any((s) => s['id']?.toString() == _selectedSessionId)
              ? _selectedSessionId
              : (sessions.isNotEmpty
                  ? sessions.first['id'].toString()
                  : _selectedSessionId);
      final dateSheet = await _schoolService.getExamDateSheet(
        sessionId: sessionId,
        classId: _selectedClassId,
      );
      final candidates = await _schoolService.getExamAdmitCardCandidates(
        sessionId: sessionId,
        classId: _selectedClassId,
      );
      final rooms = await _schoolService.getExamRooms();
      final eval = await _schoolService.getExamEvaluationProgress(
        sessionId: sessionId,
      );

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _selectedSessionId = sessionId;
        _dateSheet = dateSheet;
        _admitCandidates = candidates;
        _rooms = rooms;
        _evaluationProgress = eval;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load examination master data: $e';
      });
    }
  }

  Map<String, dynamic>? get _currentSession {
    try {
      return _sessions.firstWhere((s) => s['id'] == _selectedSessionId);
    } catch (_) {
      return _sessions.isNotEmpty ? _sessions.first : null;
    }
  }

  List<Map<String, dynamic>> get _filteredCandidates {
    if (_searchCandidateQuery.trim().isEmpty) return _admitCandidates;
    final q = _searchCandidateQuery.toLowerCase().trim();
    return _admitCandidates.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final roll = (c['roll_number'] ?? '').toString().toLowerCase();
      final examRoll = (c['exam_roll_no'] ?? '').toString().toLowerCase();
      final adm = (c['admission_no'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          roll.contains(q) ||
          examRoll.contains(q) ||
          adm.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF2563EB)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 12),
                const Text('Could Not Load Examination System',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(hasTabs: true),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsTab(),
          _buildDateSheetTab(),
          _buildAdmitCardsTab(),
          _buildRoomsTab(),
          _buildEvaluationTab(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({bool hasTabs = false}) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F172A),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Examination Controller',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          Text(
            'CBSE Session 2026-27 • Scheduling, Date Sheets, Admit Cards & Evaluation',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh Master Data',
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: _loadData,
        ),
        IconButton(
          tooltip: 'Exam Instructions & SOP',
          icon: const Icon(Icons.help_outline_rounded, size: 20),
          onPressed: _showCbseGuidelinesModal,
        ),
        const SizedBox(width: 8),
      ],
      bottom: hasTabs
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: const [
                    Tab(
                        icon: Icon(Icons.calendar_month_rounded, size: 16),
                        text: '1. Exam Sessions'),
                    Tab(
                        icon: Icon(Icons.table_chart_rounded, size: 16),
                        text: '2. Class Date Sheet'),
                    Tab(
                        icon: Icon(Icons.badge_rounded, size: 16),
                        text: '3. Admit Cards'),
                    Tab(
                        icon: Icon(Icons.meeting_room_rounded, size: 16),
                        text: '4. Halls & Seating'),
                    Tab(
                        icon: Icon(Icons.fact_check_rounded, size: 16),
                        text: '5. Marks & Results'),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // ============================================================================
  // TAB 1: EXAM SESSIONS & LIFECYCLE
  // ============================================================================
  Widget _buildSessionsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildMetricRow(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Academic Examination Sessions',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage session conduct lifecycle from Draft -> Scheduled -> Ongoing -> Evaluation -> Published',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddEditSessionDialog(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create Exam Session',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._sessions.map(_buildSessionCard),
      ],
    );
  }

  Widget _buildMetricRow() {
    final ongoing = _sessions.where((s) => s['status'] == 'Ongoing').length;
    final scheduled = _sessions.where((s) => s['status'] == 'Scheduled').length;
    final published = _sessions
        .where((s) => s['is_published'] == true || s['status'] == 'Published')
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
              'Total Sessions',
              '${_sessions.length}',
              'Annual Academic Calendar',
              Icons.event_note_rounded,
              const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
              'Ongoing Exams',
              '$ongoing',
              'Currently in progress',
              Icons.play_circle_fill_rounded,
              const Color(0xFFD97706)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
              'Scheduled Ahead',
              '$scheduled',
              'Upcoming papers',
              Icons.schedule_rounded,
              const Color(0xFF0284C7)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
              'Results Published',
              '$published',
              'Archived & on Report Cards',
              Icons.verified_rounded,
              const Color(0xFF059669)),
        ),
      ],
    );
  }

  Widget _buildStatTile(
      String label, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> s) {
    final status = s['status']?.toString() ?? 'Draft';
    final isPublished = s['is_published'] == true || status == 'Published';

    Color statusColor;
    Color statusBg;
    if (status == 'Ongoing') {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
    } else if (status == 'Scheduled') {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFDBEAFE);
    } else if (status == 'Published') {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFD1FAE5);
    } else if (status == 'Evaluation') {
      statusColor = const Color(0xFF7C3AED);
      statusBg = const Color(0xFFEDE9FE);
    } else {
      statusColor = const Color(0xFF64748B);
      statusBg = const Color(0xFFF1F5F9);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${s['term']} • ${s['academic_year']}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569)),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 18, color: Color(0xFF64748B)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditSessionDialog(existing: s);
                    } else if (val == 'delete') {
                      _deleteSession(s['id']);
                    } else {
                      _updateSessionStatus(s['id'], val);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                        value: 'Draft', child: Text('Mark as Draft')),
                    const PopupMenuItem(
                        value: 'Scheduled', child: Text('Mark as Scheduled')),
                    const PopupMenuItem(
                        value: 'Ongoing',
                        child: Text('Mark as Ongoing (Start Exam)')),
                    const PopupMenuItem(
                        value: 'Evaluation', child: Text('Move to Evaluation')),
                    const PopupMenuItem(
                        value: 'Published',
                        child: Text('Publish Results to Portal')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit Session Details')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Session',
                            style: TextStyle(color: Color(0xFFDC2626)))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              s['title'] ?? '',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _buildInfoPill(Icons.date_range_rounded,
                    '${s['start_date']} to ${s['end_date']}'),
                _buildInfoPill(Icons.assignment_rounded,
                    '${s['total_papers'] ?? 6} Scheduled Papers'),
                _buildInfoPill(Icons.groups_rounded,
                    '${s['classes_count'] ?? 12} Participating Classes'),
                _buildInfoPill(Icons.check_circle_outline_rounded,
                    '${s['passing_percentage'] ?? 33.0}% Pass Criterion'),
              ],
            ),
            if (s['instructions'] != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s['instructions'],
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSessionId = s['id'];
                    });
                    _tabController.animateTo(1);
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 14),
                  label: const Text('View Class Date Sheet',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSessionId = s['id'];
                    });
                    _tabController.animateTo(2);
                  },
                  icon: const Icon(Icons.badge_rounded, size: 14),
                  label: const Text('Admit Cards',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                const Spacer(),
                if (!isPublished)
                  ElevatedButton.icon(
                    onPressed: () => _confirmPublishSession(s),
                    icon: const Icon(Icons.publish_rounded, size: 14),
                    label: const Text('Publish Results',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text('Results Live on Portal',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669))),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ============================================================================
  // TAB 2: CLASS DATE SHEET & TIMETABLE
  // ============================================================================
  Widget _buildDateSheetTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Selector bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSessionId,
                  decoration: const InputDecoration(
                    labelText: 'Exam Session',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _sessions.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['id']?.toString(),
                      child: Text(s['title']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSessionId = val);
                      _refreshDateSheet();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Filter Class',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _classList.map((c) {
                    return DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedClassId = val);
                      _refreshDateSheet();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showAddEditPaperDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Paper',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Date Sheet: $_selectedClassId • ${_currentSession?['title'] ?? ''}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _showPrintDateSheetDialog,
                  icon: const Icon(Icons.print_rounded, size: 14),
                  label: const Text('Print Date Sheet PDF',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _broadcastDateSheetNotice,
                  icon: const Icon(Icons.campaign_rounded, size: 14),
                  label: const Text('Broadcast Notice to Parents',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_dateSheet.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.event_busy_rounded,
                      size: 40, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 10),
                  const Text('No papers scheduled for this class yet.',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _showAddEditPaperDialog(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white),
                    child: const Text('Schedule First Paper'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._dateSheet.map(_buildPaperCard),
      ],
    );
  }

  Widget _buildPaperCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date box
            Container(
              width: 90,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Text(
                    p['day'] ?? 'Monday',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p['date'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p['duration'] ?? '3.0 Hours',
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Subject & details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        p['subject'] ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p['class_name'] ?? _selectedClassId,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      _buildInfoPill(Icons.access_time_rounded,
                          '${p['start_time']} - ${p['end_time']}'),
                      _buildInfoPill(Icons.score_rounded,
                          'Theory: ${p['max_theory']} | Practical/Internal: ${p['max_practical']} (Total: ${(p['max_theory'] ?? 80) + (p['max_practical'] ?? 20)})'),
                      _buildInfoPill(Icons.meeting_room_rounded,
                          'Hall: ${p['hall_name']} (${p['room_no']})'),
                      _buildInfoPill(Icons.person_outline_rounded,
                          'Invigilator: ${p['invigilator']}'),
                    ],
                  ),
                ],
              ),
            ),

            // Edit / delete
            IconButton(
              tooltip: 'Edit Paper',
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: Color(0xFF64748B)),
              onPressed: () => _showAddEditPaperDialog(existing: p),
            ),
            IconButton(
              tooltip: 'Delete Paper',
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Color(0xFFDC2626)),
              onPressed: () => _deletePaper(p['id']),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 3: ADMIT CARDS & HALL TICKETS
  // ============================================================================
  Widget _buildAdmitCardsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Controls row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _classList
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedClassId = val);
                      _loadAdmitCandidates();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Candidate (Name, Roll, Exam Roll)',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchCandidateQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _batchIssueAdmitCards,
                icon: const Icon(Icons.all_inclusive_rounded, size: 16),
                label: const Text('Batch Issue All',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Eligibility alert note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: const [
              Icon(Icons.rule_rounded, size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CBSE Statutory Norm: Minimum 75% cumulative attendance required for admit card clearance. Fee dues can be cleared or condoned by Principal authorization.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E40AF),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ..._filteredCandidates.map(_buildCandidateCard),
      ],
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> c) {
    final bool attEligible = c['attendance_eligible'] == true;
    final bool feeCleared = c['fee_cleared'] == true;
    final double attPct =
        (c['attendance_percentage'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEFF6FF),
              child: Text(
                c['roll_number'] ?? '01',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('Exam Roll: ${c['exam_roll_no']}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Class: ${c['class_name']} • Adm No: ${c['admission_no']} • Parent: ${c['father_name']}',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    children: [
                      // Attendance badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: attEligible
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: attEligible
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          'Attendance: $attPct% • ${attEligible ? "Eligible" : "Below 75%"}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: attEligible
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626)),
                        ),
                      ),
                      // Fee clearance badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: feeCleared
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: feeCleared
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          c['fee_status'] ?? '',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: feeCleared
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showAdmitCardModal(c),
              icon: const Icon(Icons.visibility_rounded, size: 14),
              label: const Text('View Admit Card',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 4: ROOMS & SEATING ARRANGEMENT
  // ============================================================================
  Widget _buildRoomsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Exam Halls & Seating Arrangement',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                SizedBox(height: 2),
                Text(
                    'Single-desk spacing, CCTV monitored seating layout and invigilation duty rosters',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddRoomDialog(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Exam Room',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._rooms.map(_buildRoomCard),
      ],
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.meeting_room_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['room_name'] ?? '',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A))),
                      Text(r['block'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    r['status'] ?? 'Ready',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          'Seating Capacity: ${r['capacity']} Desks (${r['allocated_count']} Allocated)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF0F172A))),
                      Text(r['bench_type'] ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ((r['allocated_count'] as num?)?.toDouble() ?? 0) /
                        ((r['capacity'] as num?)?.toDouble() ?? 1),
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF2563EB),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded,
                          size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Allocated: ${r['allocated_classes']}',
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Chief Invigilator: ${r['chief_invigilator']}',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A)),
                        ),
                      ),
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

  // ============================================================================
  // TAB 5: MARKS & EVALUATION DASHBOARD
  // ============================================================================
  Widget _buildEvaluationTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Master Publishing Action Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Exam Result Publishing Console',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Once teacher evaluation is locked, publish results to render on Student Portals and CBSE Holistic Report Cards.',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _confirmPublishSession(_currentSession ?? {}),
                icon: const Icon(Icons.publish_rounded, size: 16),
                label: const Text('Publish All Results',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Subject-wise Teacher Marks Evaluation Progress',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Monitor real-time teacher submissions and lock marks entries to prevent alterations',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        ..._evaluationProgress.map(_buildEvaluationProgressCard),
      ],
    );
  }

  Widget _buildEvaluationProgressCard(Map<String, dynamic> e) {
    final int uploaded = (e['uploaded_marks'] as num?)?.toInt() ?? 0;
    final int total = (e['total_students'] as num?)?.toInt() ?? 28;
    final double pct = total > 0 ? uploaded / total : 0;
    final bool isLocked = e['is_locked'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(e['subject'] ?? '',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(e['class_name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          'Faculty In-Charge: ${e['teacher_name']} • Class Average: ${e['avg_score']}%',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 12,
                          color: isLocked
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(isLocked ? 'Locked' : 'Open for Entry',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isLocked
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: isLocked ? 'Unlock for edits' : 'Lock marks',
                  icon: Icon(
                      isLocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      size: 18),
                  onPressed: () async {
                    final ok = await _schoolService.setExamMarksLock(
                      examId: e['exam_id']?.toString() ?? _selectedSessionId,
                      classId: e['class_id']?.toString() ??
                          e['class_name']?.toString() ??
                          '',
                      subject: e['subject']?.toString() ?? '',
                      isLocked: !isLocked,
                    );
                    if (!mounted) return;
                    if (ok) {
                      await _loadData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${e['subject']} marks ${!isLocked ? "locked" : "unlocked"} successfully.')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Could not update the marks lock. Please confirm your admin permission.'),
                          backgroundColor: Color(0xFFDC2626),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    '$uploaded of $total evaluations completed (${(pct * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569))),
                Text(e['status'] ?? '',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: pct >= 1.0
                            ? const Color(0xFF059669)
                            : const Color(0xFF2563EB))),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFE2E8F0),
              color: pct >= 1.0
                  ? const Color(0xFF059669)
                  : const Color(0xFF2563EB),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS & ACTIONS
  // ============================================================================

  void _showAddEditSessionDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final termCtrl = TextEditingController(text: existing?['term'] ?? 'Term 1');
    final yearCtrl =
        TextEditingController(text: existing?['academic_year'] ?? '2026-2027');
    final startCtrl =
        TextEditingController(text: existing?['start_date'] ?? '2026-09-15');
    final endCtrl =
        TextEditingController(text: existing?['end_date'] ?? '2026-09-28');
    final passCtrl = TextEditingController(
        text: (existing?['passing_percentage'] ?? 33.0).toString());
    final instCtrl = TextEditingController(
        text: existing?['instructions'] ??
            'Admit card mandatory. Non-programmable calculators allowed for 11th/12th Physics only.');
    String status = existing?['status'] ?? 'Scheduled';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(
              isEdit ? 'Edit Exam Session' : 'Create Academic Exam Session',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Exam Session Title *',
                          hintText: 'e.g. Half Yearly Examination 2026-27')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: termCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Term (e.g. Term 1)'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: yearCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Academic Year'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: startCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Start Date (YYYY-MM-DD)'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: endCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'End Date (YYYY-MM-DD)'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: passCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Min Pass %', suffixText: '%'))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Draft', child: Text('Draft')),
                            DropdownMenuItem(
                                value: 'Scheduled', child: Text('Scheduled')),
                            DropdownMenuItem(
                                value: 'Ongoing', child: Text('Ongoing')),
                            DropdownMenuItem(
                                value: 'Evaluation', child: Text('Evaluation')),
                            DropdownMenuItem(
                                value: 'Published', child: Text('Published')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDState(() => status = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: instCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Candidate SOP & Guidelines')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;

                final payload = {
                  if (isEdit) 'id': existing['id'],
                  'title': title,
                  'term': termCtrl.text.trim(),
                  'academic_year': yearCtrl.text.trim(),
                  'start_date': startCtrl.text.trim(),
                  'end_date': endCtrl.text.trim(),
                  'passing_percentage': double.tryParse(passCtrl.text) ?? 33.0,
                  'status': status,
                  'instructions': instCtrl.text.trim(),
                  'total_papers': existing?['total_papers'] ?? 6,
                  'classes_count': existing?['classes_count'] ?? 12,
                };
                await _schoolService.saveExamSession(payload);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Session'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditPaperDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final subjectCtrl = TextEditingController(text: existing?['subject'] ?? '');
    final dateCtrl =
        TextEditingController(text: existing?['date'] ?? '2026-09-15');
    final dayCtrl = TextEditingController(text: existing?['day'] ?? 'Monday');
    final startCtrl =
        TextEditingController(text: existing?['start_time'] ?? '09:30 AM');
    final endCtrl =
        TextEditingController(text: existing?['end_time'] ?? '12:30 PM');
    final theoryCtrl =
        TextEditingController(text: (existing?['max_theory'] ?? 80).toString());
    final pracCtrl = TextEditingController(
        text: (existing?['max_practical'] ?? 20).toString());
    final hallCtrl =
        TextEditingController(text: existing?['hall_name'] ?? 'Exam Hall A');
    final roomCtrl =
        TextEditingController(text: existing?['room_no'] ?? 'Room 101');
    final invigCtrl = TextEditingController(
        text: existing?['invigilator'] ?? 'Mrs. Sunita Sharma');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Paper Schedule' : 'Schedule New Paper',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Subject Name & Code *',
                        hintText: 'e.g. Mathematics Standard (041)')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: dateCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Exam Date (YYYY-MM-DD)'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: dayCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Day (e.g. Monday)'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: startCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Start Time'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: endCtrl,
                            decoration:
                                const InputDecoration(labelText: 'End Time'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: theoryCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Theory Max Marks'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: pracCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Practical / Internal'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: hallCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Hall Name'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: roomCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Room No.'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: invigCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Assigned Chief Invigilator')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white),
            onPressed: () async {
              final sub = subjectCtrl.text.trim();
              if (sub.isEmpty) return;

              final payload = {
                if (isEdit) 'id': existing['id'],
                'session_id': _selectedSessionId,
                'class_id': _selectedClassId,
                'class_name': _selectedClassId,
                'subject': sub,
                'date': dateCtrl.text.trim(),
                'day': dayCtrl.text.trim(),
                'start_time': startCtrl.text.trim(),
                'end_time': endCtrl.text.trim(),
                'duration': '3.0 Hours',
                'max_theory': int.tryParse(theoryCtrl.text) ?? 80,
                'max_practical': int.tryParse(pracCtrl.text) ?? 20,
                'pass_marks': 33,
                'hall_name': hallCtrl.text.trim(),
                'room_no': roomCtrl.text.trim(),
                'invigilator': invigCtrl.text.trim(),
                'status': 'Scheduled',
              };
              await _schoolService.saveExamPaper(payload);
              if (ctx.mounted) Navigator.pop(ctx);
              _refreshDateSheet();
            },
            child: Text(isEdit ? 'Save Paper' : 'Add Paper'),
          ),
        ],
      ),
    );
  }

  void _showAddRoomDialog() {
    final nameCtrl = TextEditingController();
    final blockCtrl = TextEditingController(text: 'Block B, 1st Floor');
    final capCtrl = TextEditingController(text: '30');
    final classCtrl = TextEditingController(text: 'Class 10-A');
    final invigCtrl = TextEditingController(text: 'Mrs. Sunita Sharma');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Examination Room / Hall',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Room Name / Number *',
                      hintText: 'e.g. Examination Room 104')),
              const SizedBox(height: 10),
              TextField(
                  controller: blockCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Wing / Block Location')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: capCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Bench Capacity'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: classCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Assigned Classes'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: invigCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Chief Teacher Invigilator')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await _schoolService.saveExamRoom({
                'room_name': nameCtrl.text.trim(),
                'block': blockCtrl.text.trim(),
                'capacity': int.tryParse(capCtrl.text) ?? 30,
                'allocated_count': int.tryParse(capCtrl.text) ?? 30,
                'allocated_classes': classCtrl.text.trim(),
                'chief_invigilator': invigCtrl.text.trim(),
                'bench_type': 'Single Desk Spaced 1.5m',
                'status': 'Sanitized & Ready',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Add Room'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ADMIT CARD PREVIEW MODAL
  // ============================================================================
  void _showAdmitCardModal(Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('SIS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('SHIVALIK INTERNATIONAL SCHOOL',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF0F172A))),
                        Text(
                            'Affiliated to CBSE, New Delhi (Affiliation No: 3530124)',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                        Text('OFFICIAL EXAMINATION ADMIT CARD / HALL TICKET',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: const Text('CBSE VERIFIED',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669))),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),

              // Bio Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAdmitRow('Candidate Name:', c['name'] ?? ''),
                          _buildAdmitRow(
                              'Exam Roll No:', c['exam_roll_no'] ?? ''),
                          _buildAdmitRow(
                              'Admission No:', c['admission_no'] ?? ''),
                          _buildAdmitRow(
                              'Class & Section:', c['class_name'] ?? ''),
                          _buildAdmitRow(
                              "Father's Name:", c['father_name'] ?? ''),
                          _buildAdmitRow('Center & Room:',
                              '${c['exam_center']} • ${c['room_no']} (Seat: ${c['seat_no']})'),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Center(
                              child: Icon(Icons.person,
                                  size: 40, color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Candidate Photo',
                              style: TextStyle(
                                  fontSize: 9, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Mini Timetable table
              const Text('Permitted Examination Subjects & Shifts:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(6)),
                child: Table(
                  border: TableBorder.symmetric(
                      inside: const BorderSide(color: Color(0xFFE2E8F0))),
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(2.5),
                    2: FlexColumnWidth(1.8),
                    3: FlexColumnWidth(1.2),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: const [
                        Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('Date',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700))),
                        Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('Subject',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700))),
                        Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('Timing',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700))),
                        Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('Sign',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                    ..._dateSheet.take(4).map((p) => TableRow(
                          children: [
                            Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(p['date'] ?? '',
                                    style: const TextStyle(fontSize: 10))),
                            Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(p['subject'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600))),
                            Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                    '${p['start_time']} - ${p['end_time']}',
                                    style: const TextStyle(fontSize: 10))),
                            const Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('_______',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFCBD5E1)))),
                          ],
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Signatures
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Candidate Signature',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF64748B))),
                      SizedBox(height: 16),
                      Text('____________________',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFFCBD5E1))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('Controller of Examinations',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),
                      SizedBox(height: 4),
                      Text('[OFFICIAL SEAL]',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB))),
                      Text('Shivalik International School',
                          style:
                              TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Dialog Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Admit Card for ${c['name']} sent to system print queue.')),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Hall Ticket'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdmitRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  // ============================================================================
  // OTHER ACTIONS
  // ============================================================================
  void _confirmPublishSession(Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish Examination Results?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'This will publish ${s['title'] ?? 'this session'} to the live Student and Parent portals and update the CBSE Holistic Report Card archive.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _schoolService.updateExamSessionStatus(
                  s['id'] ?? _selectedSessionId, 'Published');
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Results published successfully! Live on Student & Parent Dashboards.'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              }
            },
            child: const Text('Confirm & Publish'),
          ),
        ],
      ),
    );
  }

  void _updateSessionStatus(String id, String status) async {
    await _schoolService.updateExamSessionStatus(id, status);
    _loadData();
  }

  void _deleteSession(String id) async {
    await _schoolService.deleteExamSession(id);
    _loadData();
  }

  void _deletePaper(String id) async {
    await _schoolService.deleteExamPaper(id);
    _refreshDateSheet();
  }

  Future<void> _refreshDateSheet() async {
    final ds = await _schoolService.getExamDateSheet(
      sessionId: _selectedSessionId,
      classId: _selectedClassId,
    );
    setState(() => _dateSheet = ds);
  }

  Future<void> _loadAdmitCandidates() async {
    final list = await _schoolService.getExamAdmitCardCandidates(
      sessionId: _selectedSessionId,
      classId: _selectedClassId,
    );
    setState(() => _admitCandidates = list);
  }

  void _batchIssueAdmitCards() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Issued all ${_filteredCandidates.length} Admit Cards for $_selectedClassId successfully.'),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  void _showPrintDateSheetDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Print preview generated for $_selectedClassId Date Sheet.')),
    );
  }

  void _broadcastDateSheetNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Broadcasted exam date sheet notification to all parents of $_selectedClassId.'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  void _showCbseGuidelinesModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CBSE Examination Standard Operating Procedure',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: minAxisSize,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                  '1. Entry into Examination Hall closes 15 minutes before reading time commences (09:45 AM for 10:00 AM papers).',
                  style: TextStyle(fontSize: 12.5)),
              SizedBox(height: 6),
              Text(
                  '2. 15 minutes dedicated question paper reading time is mandatory as per CBSE guidelines.',
                  style: TextStyle(fontSize: 12.5)),
              SizedBox(height: 6),
              Text(
                  '3. Seating spacing must maintain at least 1.5 meters between candidate benches with alternate question paper code distributions.',
                  style: TextStyle(fontSize: 12.5)),
              SizedBox(height: 6),
              Text(
                  '4. No mobile phones, smartwatches, or unauthorized stationery items permitted.',
                  style: TextStyle(fontSize: 12.5)),
              SizedBox(height: 6),
              Text(
                  '5. Minimum 75% attendance criterion is mandatory; attendance below 75% requires formal medical condonation approved by Principal.',
                  style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white),
            child: const Text('Acknowledged'),
          ),
        ],
      ),
    );
  }

  static const minAxisSize = MainAxisSize.min;
}
