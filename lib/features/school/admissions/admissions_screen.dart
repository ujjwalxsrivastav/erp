import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/offer_letter_pdf_service.dart';
import '../../../services/entrance_exam_service.dart';
import '../../../services/entrance_test_service.dart';
import 'entrance_test_builder_dialog.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _admissions = [];
  List<Map<String, dynamic>> _enquiries = [];

  String _selectedStatus = 'all';
  String _selectedGradeFilter = 'all';
  String _searchQuery = '';
  String _userRole = 'admin';

  final List<String> _statusFilters = [
    'all',
    'Under Review',
    'Entrance Exam',
    'Documents Verified',
    'Offer Letter Issued',
    'Enrolled',
    'Rejected',
  ];

  final List<String> _gradeOptions = [
    'all',
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
  ];

  List<Map<String, dynamic>> _liveClasses = [];

  final _entranceService = EntranceExamService();
  final _testService = EntranceTestService();
  List<Map<String, dynamic>> _entranceSubjects = [];
  List<Map<String, dynamic>> _entranceTests = [];
  String _catalogGrade = 'Class 1';
  String _entranceRosterGrade = 'all';
  bool _entranceCatalogLoading = false;
  bool _entranceTestsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
      final role = await _authService.getCurrentUserRole() ?? 'admin';
      final admissions = await _schoolService.getAdmissions();
      final enquiries = await _schoolService.getAdmissionEnquiries();
      final liveClasses = await _schoolService.getSchoolClasses();

      if (!mounted) return;
      setState(() {
        _userRole = role;
        _admissions = admissions;
        _enquiries = enquiries;
        _liveClasses = liveClasses;
        _isLoading = false;
      });
      _loadEntranceCatalog(_catalogGrade);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load admission system: $e';
      });
    }
  }

  Future<void> _loadEntranceCatalog(String className) async {
    setState(() {
      _entranceCatalogLoading = true;
      _entranceTestsLoading = true;
    });
    final subjects = await _entranceService.getSubjects(className);
    final tests = await _testService.getTests(className: className);
    final enriched = await Future.wait(tests.map((t) async {
      final questions =
          await _testService.getTestQuestions(t['id']?.toString() ?? '');
      return <String, dynamic>{
        ...t,
        'questions': questions,
        'question_count': questions.length,
        'subject_count': questions
            .map((q) => (q['subject'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet()
            .length,
        'total_marks': questions.fold<int>(
            0, (sum, q) => sum + ((q['marks'] as num?)?.toInt() ?? 0)),
      };
    }));
    if (!mounted) return;
    setState(() {
      _entranceSubjects = subjects;
      _entranceTests = enriched;
      _entranceCatalogLoading = false;
      _entranceTestsLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredAdmissions {
    var list = [..._admissions];

    if (_selectedStatus != 'all') {
      list = list.where((a) => a['status'] == _selectedStatus).toList();
    }

    if (_selectedGradeFilter != 'all') {
      list = list.where((a) => (a['grade_applying'] ?? '').toString() == _selectedGradeFilter).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((a) {
        final name = (a['applicant_name'] ?? '').toString().toLowerCase();
        final pName = (a['parent_name'] ?? '').toString().toLowerCase();
        final phone = (a['parent_phone'] ?? '').toString().toLowerCase();
        final id = (a['id'] ?? '').toString().toLowerCase();
        final appNo = (a['application_no'] ?? '').toString().toLowerCase();
        final grade = (a['grade_applying'] ?? '').toString().toLowerCase();
        return name.contains(q) || pName.contains(q) || phone.contains(q) || id.contains(q) || appNo.contains(q) || grade.contains(q);
      }).toList();
    }

    return list;
  }

  Map<String, int> get _statusCounts {
    final m = <String, int>{'all': _admissions.length};
    for (final s in _statusFilters) {
      if (s == 'all') continue;
      m[s] = _admissions.where((a) => a['status'] == s).length;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
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
                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 12),
                const Text('Could Not Load Admissions Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
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
          _buildPipelineTab(),
          _buildIntakeWizardTab(),
          _buildEntranceExamTab(),
          _buildDocumentScrutinyTab(),
          _buildInteractionTestTab(),
          _buildEnquiriesTab(),
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
            'School Admissions & Student Intake Master',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          Text(
            'CBSE Session 2026-27 • ${_userRole.toUpperCase()} • Multi-Step Intake, Document Scrutiny & RTE 25% Quota',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Open public admission form',
          icon: const Icon(Icons.open_in_new_rounded, size: 20),
          onPressed: () => context.push('/admissions/school-apply'),
        ),
        IconButton(
          tooltip: 'Refresh Admissions',
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: _loadData,
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.view_kanban_rounded, size: 16), text: '1. Admission Pipeline'),
                    Tab(icon: Icon(Icons.person_add_alt_1_rounded, size: 16), text: '2. New Intake Form'),
                    Tab(icon: Icon(Icons.quiz_rounded, size: 16), text: '3. Entrance Exam'),
                    Tab(icon: Icon(Icons.verified_user_rounded, size: 16), text: '4. Document Scrutiny'),
                    Tab(icon: Icon(Icons.fact_check_rounded, size: 16), text: '5. Interaction & Readiness'),
                    Tab(icon: Icon(Icons.contact_phone_rounded, size: 16), text: '6. Prospect Leads & Enquiries'),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // ============================================================================
  // TAB 1: ADMISSION PIPELINE & OVERVIEW
  // ============================================================================
  Widget _buildPipelineTab() {
    final underReview = _statusCounts['Under Review'] ?? 0;
    final entranceExam = _statusCounts['Entrance Exam'] ?? 0;
    final documentsVerified = _statusCounts['Documents Verified'] ?? 0;
    final offerIssued = _statusCounts['Offer Letter Issued'] ?? 0;
    final enrolled = _statusCounts['Enrolled'] ?? 0;
    final rteEnrolled = _admissions.where((a) {
      final s = (a['status']?.toString() ?? '').toLowerCase();
      final isRte = a['quota']?.toString().toUpperCase() == 'RTE' || a['is_rte'] == true;
      return s == 'enrolled' && isRte;
    }).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Metric Banner
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: 196, child: _buildMetricTile('Total Applications', '${_admissions.length}', 'Session 2026-27 Intake', Icons.folder_shared_rounded, const Color(0xFF2563EB))),
            SizedBox(width: 196, child: _buildMetricTile('Under Review', '$underReview', 'Application & KYC scrutiny', Icons.hourglass_top_rounded, const Color(0xFFD97706))),
            SizedBox(width: 196, child: _buildMetricTile('Entrance Exam', '$entranceExam', 'Offline marks or AI paper', Icons.quiz_rounded, const Color(0xFF0284C7))),
            SizedBox(width: 196, child: _buildMetricTile('Documents Verified', '$documentsVerified', 'Ready for offer letter', Icons.fact_check_rounded, const Color(0xFF0D9488))),
            SizedBox(width: 196, child: _buildMetricTile('Offer Letters', '$offerIssued', 'Awaiting Approve & Enrol', Icons.mail_outline_rounded, const Color(0xFF7C3AED))),
            SizedBox(width: 196, child: _buildMetricTile('Enrolled Students', '$enrolled', '$rteEnrolled Enrolled (RTE Quota)', Icons.school_rounded, const Color(0xFF059669))),
          ],
        ),
        const SizedBox(height: 18),

        // Search & Filter Toolbar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by student name, parent name, mobile, app no...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGradeFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter Grade',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _gradeOptions.map((g) => DropdownMenuItem(value: g, child: Text(g == 'all' ? 'All Classes' : g))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedGradeFilter = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Horizontal status pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusFilters.map((s) {
                    final selected = _selectedStatus == s;
                    final count = _statusCounts[s] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selected,
                        label: Text(s == 'all' ? 'All Applications ($count)' : '$s ($count)'),
                        selectedColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : const Color(0xFF334155),
                        ),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: BorderSide(color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (_) => setState(() => _selectedStatus = s),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // List of Application Cards
        if (_filteredAdmissions.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: const [
                  Icon(Icons.inbox_rounded, size: 44, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text('No admission applications match current filter.', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  SizedBox(height: 4),
                  Text('Try switching the status filter or clearing your search term.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else
          ..._filteredAdmissions.map(_buildAdmissionApplicationCard),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildAdmissionApplicationCard(Map<String, dynamic> a) {
    final status = a['status']?.toString() ?? 'Under Review';
    final docStatus = a['doc_status']?.toString() ?? 'Pending';
    final bool isRte = a['rte_quota'] == true;
    final bool hasSibling = a['sibling_priority'] == true;

    Color statusColor;
    Color statusBg;
    if (status == 'Enrolled') {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
    } else if (status == 'Offer Letter Issued') {
      statusColor = const Color(0xFF7C3AED);
      statusBg = const Color(0xFFEDE9FE);
    } else if (status == 'Approved') {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFEFF6FF);
    } else if (status == 'Interview Scheduled') {
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFE0F2FE);
    } else if (status == 'Entrance Exam') {
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFE0F2FE);
    } else if (status == 'Documents Verified') {
      statusColor = const Color(0xFF0D9488);
      statusBg = const Color(0xFFF0FDFA);
    } else if (status == 'Rejected') {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
    } else {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badges row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    a['application_no'] ?? a['id'] ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
                if (isRte) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: const Text('RTE 25% EWS QUOTA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                  ),
                ],
                if (hasSibling) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFDE68A))),
                    child: const Text('SIBLING PRIORITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                  ),
                ],
                const Spacer(),
                Text(
                  'Applied: ${a['date'] ?? '2026-10-25'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    (a['applicant_name'] ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['applicant_name'] ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Applying for: ${a['grade_applying']} • Stream: ${a['stream'] ?? "General"} • DOB: ${(a['dob'] ?? '').toString().isNotEmpty ? a['dob'] : "N/A"} (${(a['gender'] ?? '').toString().isNotEmpty ? a['gender'] : "N/A"})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Father: ${a['parent_name']} (${a['parent_occupation'] ?? "Parent"}) • Phone: ${a['parent_phone']} • Email: ${a['email'] ?? "N/A"}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _buildMiniInfo(Icons.history_edu_rounded, 'Prev: ${a['previous_school'] ?? "Not Specified"} (${a['previous_grade'] ?? "N/A"})'),
                          _buildMiniInfo(Icons.directions_bus_rounded, a['transport_required'] == true ? 'Transport: ${a['transport_stop']}' : 'Self Transport'),
                          _buildMiniInfo(Icons.verified_user_outlined, 'KYC: $docStatus', color: docStatus == 'Verified' ? const Color(0xFF059669) : const Color(0xFFD97706)),
                          _buildMiniInfo(
                            Icons.quiz_rounded,
                            'Entrance: ${a['entrance_exam_status'] ?? 'Pending'}'
                                '${((a['entrance_percentage'] as num?) ?? 0) > 0 ? ' • ${(a['entrance_percentage'] as num).toStringAsFixed(1)}% (${a['entrance_score'] ?? 0}/${a['entrance_max_score'] ?? 0})' : ''}',
                            color: (a['entrance_exam_status']?.toString().toLowerCase() == 'completed')
                                ? const Color(0xFF059669)
                                : const Color(0xFF0284C7),
                          ),
                          if ((a['referral'] ?? '').toString().isNotEmpty)
                            _buildMiniInfo(Icons.share_rounded, 'Referral: ${a['referral']}', color: const Color(0xFF7C3AED)),
                          _buildMiniInfo(
                            Icons.support_agent_rounded,
                            (a['counsellor_name'] ?? '').toString().isNotEmpty
                                ? 'Counsellor: ${a['counsellor_name']}'
                                : 'Counsellor: Unassigned',
                            color: (a['counsellor_name'] ?? '').toString().isNotEmpty
                                ? const Color(0xFF0891B2)
                                : const Color(0xFFDC2626),
                          ),
                          if ((a['test_score'] as num?) != null && (a['test_score'] as num) > 0)
                            _buildMiniInfo(Icons.grade_rounded, 'Test: ${a['test_score']}/50 Score', color: const Color(0xFF2563EB)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Action Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showCandidateDossierModal(a),
                  icon: const Icon(Icons.badge_rounded, size: 14),
                  label: const Text('View Dossier / KYC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openEntranceDesk(a),
                  icon: Icon(
                    _isEntranceCompleted(a)
                        ? Icons.assignment_turned_in_rounded
                        : Icons.quiz_rounded,
                    size: 14,
                  ),
                  label: Text(
                      _isEntranceCompleted(a)
                          ? 'Entrance Marks'
                          : 'Entrance Exam',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openScrutinyOrGate(a),
                  icon: Icon(
                    _isEntranceCompleted(a)
                        ? Icons.fact_check_rounded
                        : Icons.lock_rounded,
                    size: 14,
                  ),
                  label: const Text('Scrutiny Documents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isEntranceCompleted(a)
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                    side: BorderSide(
                        color: _isEntranceCompleted(a)
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                if (status == 'Under Review' || status == 'Interview Scheduled')
                  OutlinedButton.icon(
                    onPressed: () => _showInteractionTestDialog(a),
                    icon: const Icon(Icons.event_note_rounded, size: 14),
                    label: const Text('Record Interaction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                if (status != 'Enrolled' && status != 'Rejected') ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showRejectAdmissionDialog(a),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                const Spacer(),

                // Decision Action
                if ((status == 'Approved' ||
                        status == 'Under Review' ||
                        status == 'Interview Scheduled' ||
                        status == 'Entrance Exam' ||
                        status == 'Documents Verified') &&
                    (docStatus == 'Verified' || status == 'Documents Verified'))
                  ElevatedButton.icon(
                    onPressed: () => _showIssueOfferLetterDialog(a),
                    icon: const Icon(Icons.mail_rounded, size: 14),
                    label: const Text('Issue Offer Letter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  )
                else if (status == 'Approved' ||
                    status == 'Under Review' ||
                    status == 'Interview Scheduled' ||
                    status == 'Entrance Exam' ||
                    status == 'Documents Verified')
                  OutlinedButton.icon(
                    onPressed: () => _openScrutinyOrGate(a),
                    icon: const Icon(Icons.lock_clock_rounded, size: 14),
                    label: const Text('Verify Documents First', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                else if (status == 'Offer Letter Issued') ...[
                  OutlinedButton.icon(
                    onPressed: () => _showOfferLetterPreviewModal(a),
                    icon: const Icon(Icons.print_rounded, size: 14),
                    label: const Text('View Offer Letter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFFDDD6FE)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showFinalEnrollmentDialog(a),
                    icon: const Icon(Icons.how_to_reg_rounded, size: 14),
                    label: const Text('Approve & Enrol', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ] else if (status == 'Enrolled') ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Enrolled as ${a['enrolled_class'] ?? a['grade_applying']} • Adm: ${a['admission_no'] ?? '—'}'
                              '${(a['student_username'] ?? '').toString().isNotEmpty ? ' • Login: ${a['student_username']}' : ''}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showClassAllotmentDialog(a),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 13, color: Color(0xFF059669)),
                            label: const Text('Allot / Transfer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11.5, color: color ?? const Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ============================================================================
  // TAB 2: MULTI-STEP INTAKE REGISTRATION WIZARD
  // ============================================================================
  Widget _buildIntakeWizardTab() {
    return _AdmissionIntakeForm(
      onSubmitted: () {
        _loadData();
        _tabController.animateTo(0);
      },
      schoolService: _schoolService,
    );
  }

  // ============================================================================
  // TAB 3: ENTRANCE EXAMINATION DESK
  // ============================================================================
  Widget _buildEntranceExamTab() {
    final candidates = _admissions.where((a) {
      final s = (a['status'] ?? '').toString().toLowerCase();
      if (s == 'enrolled' || s == 'rejected') return false;
      if (_entranceRosterGrade != 'all' &&
          (a['grade_applying'] ?? '').toString() != _entranceRosterGrade) {
        return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Entrance Examination Desk',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
        const Text(
          'Runs before document verification • Offline marks entry or an AI paper built from previous-class + target-class topics • Each subject is worth 50 marks',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Class blueprint:',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B))),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _catalogGrade,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A)),
              items: _gradeOptions
                  .where((g) => g != 'all')
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _catalogGrade = v);
                _loadEntranceCatalog(v);
              },
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/entrance-test'),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Open Candidate Portal',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildEntranceTestsCard(),
        const SizedBox(height: 14),
        _buildEntranceCatalogCard(),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('Applicant Roster (${candidates.length})',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            const Spacer(),
            const Text('Class:',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: _entranceRosterGrade,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A)),
              items: _gradeOptions
                  .map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g == 'all' ? 'All classes' : g)))
                  .toList(),
              onChanged: (v) => setState(() => _entranceRosterGrade = v ?? 'all'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text('Record the entrance outcome before scrutiny',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        if (candidates.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text('No applicants are currently in the entrance stage.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            ),
          )
        else
          ...candidates.map(_buildEntranceCandidateCard),
      ],
    );
  }

  // ============================================================================
  // CLASS TEST BUILDER + CANDIDATE LOGINS
  // ============================================================================
  Widget _buildEntranceTestsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class Entrance Tests',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    Text(
                      'One page per subject • candidates sign in with an enrollment number and ddmmyy password',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _entranceTestsLoading ? null : () => _openTestBuilder(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create / Edit Test',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_entranceTestsLoading)
            const LinearProgressIndicator(
                minHeight: 2, color: Color(0xFF2563EB))
          else if (_entranceTests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'No entrance test exists for $_catalogGrade yet. Create one to issue candidate logins and run the online exam.',
                style: const TextStyle(
                    fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            )
          else
            ..._entranceTests.map(_buildEntranceTestRow),
        ],
      ),
    );
  }

  Widget _buildEntranceTestRow(Map<String, dynamic> t) {
    final title = (t['title'] ?? 'Entrance Test').toString();
    final published =
        (t['status'] ?? 'published').toString().toLowerCase() == 'published';
    final subjectCount = (t['subject_count'] as num?)?.toInt() ?? 0;
    final questionCount = (t['question_count'] as num?)?.toInt() ?? 0;
    final totalMarks = (t['total_marks'] as num?)?.toInt() ?? 0;
    final duration = (t['duration_minutes'] as num?)?.toInt() ?? 90;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              size: 17, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(
                  '$subjectCount subject page(s) • $questionCount questions • $totalMarks marks • $duration min',
                  style: const TextStyle(
                      fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: published
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              published ? 'Published' : 'Draft',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: published
                      ? const Color(0xFF047857)
                      : const Color(0xFFB45309)),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _openTestBuilder(existing: t),
            icon: const Icon(Icons.edit_rounded, size: 14),
            label: const Text('Edit',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete test',
            onPressed: () => _deleteEntranceTest(t),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 17, color: Color(0xFFDC2626)),
          ),
        ],
      ),
    );
  }

  Future<void> _openTestBuilder({Map<String, dynamic>? existing}) async {
    final className = _catalogGrade;
    final subjects = await _entranceService.getSubjects(className);
    final questions = existing == null
        ? const <Map<String, dynamic>>[]
        : ((existing['questions'] as List?) ?? const [])
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList();
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EntranceTestBuilderDialog(
        className: className,
        subjects: subjects,
        createdBy: _userRole,
        existingTest: existing,
        existingQuestions: questions,
      ),
    );
    if (saved == true) {
      await _loadEntranceCatalog(className);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entrance test saved for $className.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    }
  }

  Future<void> _deleteEntranceTest(Map<String, dynamic> t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entrance test?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            'Remove "${t['title'] ?? 'this test'}" and all of its questions? Candidates will not be able to take it afterwards.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _testService.deleteTest(t['id']?.toString() ?? '');
    await _loadEntranceCatalog(_catalogGrade);
  }

  Future<void> _showTestCredentialsDialog(Map<String, dynamic> a) async {
    final className = (a['grade_applying'] ?? '').toString().trim();
    final test = await _testService.getPublishedTestForClass(className);
    if (!mounted) return;

    if (test == null) {
      final openBuilder = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Create the class test first',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
            'No published entrance test exists for ${className.isEmpty ? 'this class' : className}.\n\n'
            'Build the test (one page per subject), then issue the candidate login.',
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Create Test'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
      if (openBuilder == true) {
        setState(() => _catalogGrade =
            className.isEmpty ? _catalogGrade : className);
        await _loadEntranceCatalog(_catalogGrade);
        await _openTestBuilder();
      }
      return;
    }

    final result = await _testService.issueCredentials(
      admission: a,
      className: className,
      issuedBy: _userRole,
      testId: test['id']?.toString(),
    );
    if (!mounted) return;

    if (result['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ??
              'Could not issue the test login.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final candidate =
        Map<String, dynamic>.from(result['candidate'] as Map);
    await _loadData();
    if (!mounted) return;
    _showIssuedCredentialsDialog(
      a,
      candidate,
      result['test'] is Map
          ? Map<String, dynamic>.from(result['test'] as Map)
          : test,
      reused: result['reused'] == true,
    );
  }

  void _showIssuedCredentialsDialog(
    Map<String, dynamic> a,
    Map<String, dynamic> candidate,
    Map<String, dynamic>? test, {
    bool reused = false,
  }) {
    final enrollment = (candidate['enrollment_no'] ?? '').toString();
    final password = (candidate['password'] ?? '').toString();
    final className = (candidate['class_name'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.key_rounded, size: 18, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reused ? 'Candidate Test Login' : 'Test Login Issued',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
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
              Text(
                '${a['applicant_name'] ?? candidate['candidate_name'] ?? ''} • $className',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
              if (test != null && (test['title'] ?? '').toString().isNotEmpty)
                Text('Test: ${test['title']}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 14),
              _buildCredentialRow('Enrollment number', enrollment),
              const SizedBox(height: 8),
              _buildCredentialRow('Password (ddmmyy)', password),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Share these details with the candidate. They can sign in at /entrance-test and the test for their class opens automatically.',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF1E40AF), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text: 'Enrollment: $enrollment\nPassword: $password\n'
                      'Portal: /entrance-test'));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Candidate credentials copied.'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/entrance-test');
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Open Portal'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          SelectableText(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildEntranceCatalogCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Subjects, Topics & Weightage',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _showEntrancePaperPreview(className: _catalogGrade),
                icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                label: const Text('AI Paper',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showEntranceCatalogDialog(),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add Subject',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Every subject carries a fixed 50-mark weightage. Topics are combined with the previous class syllabus when the AI paper is generated.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (_entranceCatalogLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(
                  minHeight: 2, color: Color(0xFF0284C7)),
            )
          else if (_entranceSubjects.isEmpty)
            const Text('No subjects configured for this class yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _entranceSubjects.map((s) {
                final topics = (s['topics'] as List?) ?? const [];
                return Container(
                  width: 300,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(s['subject']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('${s['weightage'] ?? 50} marks',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0369A1))),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showEntranceCatalogDialog(existing: s),
                            child: const Icon(Icons.edit_rounded,
                                size: 14, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _deleteEntranceSubject(s),
                            child: const Icon(Icons.delete_outline_rounded,
                                size: 14, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        topics.isEmpty
                            ? 'No topics added'
                            : topics.join(' • '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                            height: 1.3),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEntranceCandidateCard(Map<String, dynamic> a) {
    final status = a['status']?.toString() ?? 'Under Review';
    final entranceStatus =
        a['entrance_exam_status']?.toString() ?? 'Pending';
    final completed = entranceStatus.toLowerCase() == 'completed';
    final pct = (a['entrance_percentage'] as num?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: completed
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                completed ? '${pct.toStringAsFixed(0)}%' : '—',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: completed
                        ? const Color(0xFF059669)
                        : const Color(0xFF0284C7)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['applicant_name'] ?? '',
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(
                  '${a['grade_applying']} • ${a['application_no'] ?? a['id']} • Stage: $status'
                  '${(a['entrance_enrollment_no'] ?? '').toString().isNotEmpty ? ' • Login: ${a['entrance_enrollment_no']}' : ''}',
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  completed
                      ? 'Entrance completed (${a['entrance_exam_mode'] ?? 'offline'}) • ${a['entrance_score'] ?? 0}/${a['entrance_max_score'] ?? 0} marks'
                      : 'Entrance not recorded • ${(a['entrance_subjects'] as List?)?.length ?? 0} subject snapshot(s)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: completed
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (completed) ...[
            OutlinedButton.icon(
              onPressed: () => _showEntranceMarksViewDialog(a),
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 15),
              label: const Text('View Marks',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showOfflineEntranceMarksDialog(a),
              icon: const Icon(Icons.edit_note_rounded, size: 15),
              label: const Text('Update Marks',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => _showOfflineEntranceMarksDialog(a),
              icon: const Icon(Icons.edit_note_rounded, size: 15),
              label: const Text('Offline Marks',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showEntrancePaperDialog(a),
              icon: const Icon(Icons.auto_awesome_rounded, size: 15),
              label: const Text('AI Online Paper',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isEntranceCompleted(Map<String, dynamic> a) =>
      (a['entrance_exam_status'] ?? '').toString().toLowerCase() ==
      'completed';

  /// Opens the entrance desk. Once marks exist we show the recorded scorecard
  /// (with an Update Marks action at the bottom) instead of the entry chooser.
  void _openEntranceDesk(Map<String, dynamic> a) {
    if (_isEntranceCompleted(a)) {
      _showEntranceMarksViewDialog(a);
    } else {
      _showEntranceExamChooser(a);
    }
  }

  /// Read-only scorecard for an applicant whose entrance exam is complete.
  void _showEntranceMarksViewDialog(Map<String, dynamic> a) {
    final scores = ((a['entrance_subjects'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final total = (a['entrance_score'] as num?)?.toDouble() ?? 0;
    final max = (a['entrance_max_score'] as num?)?.toDouble() ?? 0;
    final pct = (a['entrance_percentage'] as num?)?.toDouble() ?? 0;
    final mode = (a['entrance_exam_mode'] ?? 'offline').toString();
    final at = (a['entrance_exam_at'] ?? '').toString();
    final dateLabel = at.length >= 10 ? at.substring(0, 10) : at;
    final grade = pct >= 90
        ? 'A+'
        : pct >= 80
            ? 'A'
            : pct >= 70
                ? 'B'
                : pct >= 60
                    ? 'C'
                    : pct >= 50
                        ? 'D'
                        : 'E';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 640),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in_rounded,
                      color: Color(0xFF059669), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrance Result • ${a['applicant_name'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                        Text(
                          '${a['grade_applying'] ?? ''} • ${a['application_no'] ?? a['id'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF047857))),
                        Text('${total.toStringAsFixed(0)} / ${max.toStringAsFixed(0)} marks',
                            style: const TextStyle(
                                fontSize: 11.5, color: Color(0xFF047857))),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildEntrancePill('Grade $grade'),
                        const SizedBox(height: 4),
                        _buildEntrancePill(mode == 'online'
                            ? 'AI / Online paper'
                            : 'Offline paper'),
                        if (dateLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Recorded $dateLabel',
                              style: const TextStyle(
                                  fontSize: 10.5, color: Color(0xFF64748B))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Subject-wise marks',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Flexible(
                child: scores.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No subject-wise snapshot was stored for this result.',
                          style: TextStyle(
                              fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: scores.map((s) {
                            final subject =
                                (s['subject'] ?? 'General').toString();
                            final marks =
                                (s['marks'] as num?)?.toDouble() ?? 0;
                            final subjectMax =
                                (s['max'] as num?)?.toDouble() ?? 50;
                            final ratio = subjectMax > 0
                                ? (marks / subjectMax).clamp(0.0, 1.0)
                                : 0.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(subject,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF334155))),
                                      ),
                                      Text(
                                        '${marks.toStringAsFixed(0)} / ${subjectMax.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio.toDouble(),
                                      minHeight: 5,
                                      backgroundColor:
                                          const Color(0xFFE2E8F0),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF059669)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showTestCredentialsDialog(a);
                    },
                    icon: const Icon(Icons.key_rounded, size: 15),
                    label: const Text('Test Login'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEntrancePaperDialog(a);
                    },
                    icon: const Icon(Icons.description_outlined, size: 15),
                    label: const Text('View Paper'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showOfflineEntranceMarksDialog(a);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 15),
                    label: const Text('Update Marks'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
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

  Widget _buildEntrancePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF047857)),
      ),
    );
  }

  /// Blocking gate shown when document scrutiny is opened before the entrance
  /// exam has been recorded.
  void _showEntranceRequiredDialog(Map<String, dynamic> a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrance Exam Pending',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Document verification is unlocked only after the entrance exam is '
          'recorded for ${a['applicant_name'] ?? 'this applicant'}.\n\n'
          'Record the offline marks or generate the online paper first.',
          style: const TextStyle(fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openEntranceDesk(a);
            },
            icon: const Icon(Icons.quiz_rounded, size: 15),
            label: const Text('Open Entrance Exam'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _openScrutinyOrGate(Map<String, dynamic> a) {
    if (_isEntranceCompleted(a)) {
      _showDocumentScrutinyDialog(a);
    } else {
      _showEntranceRequiredDialog(a);
    }
  }

  void _showEntranceExamChooser(Map<String, dynamic> a) {
    if (_isEntranceCompleted(a)) {
      _showEntranceMarksViewDialog(a);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Entrance Exam: ${a['applicant_name']}',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showTestCredentialsDialog(a);
            },
            child: const Row(
              children: [
                Icon(Icons.key_rounded, size: 20, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Candidate Test Login — issue or re-share the enrollment number and ddmmyy password.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showOfflineEntranceMarksDialog(a);
            },
            child: const Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF0F172A)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Record Offline Marks — enter marks obtained in each subject (out of 50).',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showEntrancePaperDialog(a);
            },
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFF0284C7)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generate AI Online Paper — build a paper from previous + target class topics.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _catalogGrade =
                  (a['grade_applying'] ?? 'Class 1').toString());
              _loadEntranceCatalog(_catalogGrade);
              _tabController.animateTo(2);
            },
            child: const Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF64748B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Manage Subjects & Topics for this class.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEntranceCatalogDialog({Map<String, dynamic>? existing}) {
    final subjectCtrl =
        TextEditingController(text: existing?['subject']?.toString() ?? '');
    final topicsCtrl = TextEditingController(
        text: ((existing?['topics'] as List?) ?? const []).join(', '));
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${isEdit ? 'Edit' : 'Add'} Entrance Subject — $_catalogGrade',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectCtrl,
                enabled: !isEdit,
                decoration: const InputDecoration(
                    labelText: 'Subject (e.g. Mathematics)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topicsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Topics (comma separated)',
                  hintText:
                      'Number system, fractions, problem solving, previous class revision',
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text(
                  'Weightage is fixed at 50 marks per subject. The AI paper combines these topics with the previous class syllabus.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF075985)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white),
            onPressed: () async {
              final subject = subjectCtrl.text.trim();
              if (subject.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a subject name.'),
                      backgroundColor: Color(0xFFDC2626)),
                );
                return;
              }
              final topics = topicsCtrl.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              await _entranceService.saveSubject(
                className: _catalogGrade,
                subject: subject,
                topics: topics,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadEntranceCatalog(_catalogGrade);
            },
            child: Text(isEdit ? 'Save Subject' : 'Add Subject'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntranceSubject(Map<String, dynamic> subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Subject?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
            'Remove ${subject['subject']} from the $_catalogGrade entrance blueprint?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _entranceService.deleteSubject(subject['id']?.toString() ?? '');
    _loadEntranceCatalog(_catalogGrade);
  }

  Future<void> _showOfflineEntranceMarksDialog(Map<String, dynamic> a,
      {Map<String, dynamic>? paper}) async {
    final className = (a['grade_applying'] ?? 'Class 1').toString();
    final subjects = paper != null
        ? ((paper['subjects'] as List?) ?? const [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList()
        : await _entranceService.getSubjects(className);

    if (subjects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Add at least one entrance subject first.'),
              backgroundColor: Color(0xFFD97706)),
        );
      }
      return;
    }

    final controllers = <String, TextEditingController>{};
    for (final s in subjects) {
      final subject = s['subject']?.toString() ?? 'General';
      final existing = ((paper?['subjects'] as List?) ?? const [])
          .whereType<Map>()
          .where((e) =>
              (e['subject']?.toString() ?? '').toLowerCase() ==
              subject.toLowerCase())
          .toList();
      final existingScores = ((a['entrance_subjects'] as List?) ?? const [])
          .whereType<Map>()
          .where((e) =>
              (e['subject']?.toString() ?? '').toLowerCase() ==
              subject.toLowerCase())
          .toList();
      final priorMarks = existing.isNotEmpty
          ? existing.first['marks']
          : (existingScores.isNotEmpty ? existingScores.first['marks'] : null);
      controllers[subject] = TextEditingController(
          text: (priorMarks as num?)?.toString() ?? '');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          double total = 0;
          for (final s in subjects) {
            final subject = s['subject']?.toString() ?? 'General';
            total += double.tryParse(controllers[subject]!.text.trim()) ?? 0;
          }
          final max = subjects.fold<double>(
              0, (sum, s) => sum + ((s['weightage'] as num?)?.toDouble() ?? 50));
          return AlertDialog(
            title: Text('Offline Entrance Marks: ${a['applicant_name']}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$className • Each subject is scored out of 50. Enter the marks obtained in the offline paper.',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    ...subjects.map((s) {
                      final subject = s['subject']?.toString() ?? 'General';
                      final subjectMax =
                          (s['weightage'] as num?)?.toDouble() ?? 50;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(subject,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: controllers[subject],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: 'Marks',
                                  helperText: 'of ${subjectMax.toInt()}',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                                onChanged: (_) => setDState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('${total.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7))),
                      ],
                    ),
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
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white),
                onPressed: () async {
                  final scores = <Map<String, dynamic>>[];
                  for (final s in subjects) {
                    final subject = s['subject']?.toString() ?? 'General';
                    final subjectMax =
                        (s['weightage'] as num?)?.toDouble() ?? 50;
                    final raw =
                        double.tryParse(controllers[subject]!.text.trim()) ?? 0;
                    scores.add({
                      'subject': subject,
                      'marks': raw.clamp(0, subjectMax).toDouble(),
                      'max': subjectMax,
                    });
                  }
                  final res = await _schoolService
                      .recordAdmissionEntranceResult(
                    admissionId: a['id']?.toString() ?? '',
                    subjectScores: scores,
                    mode: 'offline',
                    recordedBy: _userRole,
                    className: className,
                    paperId: paper?['id']?.toString(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Entrance recorded: ${res['total_score']}/${res['max_score']} (${res['percentage']}%).'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  }
                },
                child: const Text('Save Entrance Result'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEntrancePaperDialog(Map<String, dynamic> a) {
    _showEntrancePaperPreview(
      className: (a['grade_applying'] ?? 'Class 1').toString(),
      admissionId: a['id']?.toString() ?? '',
      applicantLabel: a['applicant_name']?.toString() ?? '',
      admission: a,
    );
  }

  /// Shows an AI entrance paper. When [admission] is null the paper is a
  /// class-level preview for [className] (no marks entry).
  void _showEntrancePaperPreview({
    required String className,
    String admissionId = '',
    String applicantLabel = '',
    Map<String, dynamic>? admission,
  }) {
    late Future<Map<String, dynamic>> paperFuture;

    Future<Map<String, dynamic>> load() async {
      final existing = admissionId.isEmpty
          ? null
          : await _entranceService.getPaperForAdmission(admissionId);
      if (existing != null) return existing;
      return _entranceService.generatePaper(
        className: className,
        username: _userRole,
        mode: 'online',
        admissionId: admissionId,
      );
    }

    paperFuture = load();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 780),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFF0284C7), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Entrance Paper • $className${applicantLabel.isNotEmpty ? ' • $applicantLabel' : ''}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: paperFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF0284C7)),
                              SizedBox(height: 14),
                              Text(
                                'Building the paper from previous + target class topics…',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text('Could not generate the paper: ${snapshot.error ?? 'unknown error'}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFDC2626))),
                        );
                      }
                      final paper = snapshot.data!;
                      final subjects = ((paper['subjects'] as List?) ?? const [])
                          .map((s) => Map<String, dynamic>.from(s as Map))
                          .toList();
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFBAE6FD))),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${paper['instructions'] ?? 'Answer all questions.'} Total: ${paper['total_marks'] ?? 0} marks • Model: ${paper['ai_model'] ?? 'template'}',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF075985)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...subjects.map((s) {
                              final questions =
                                  ((s['questions'] as List?) ?? const [])
                                      .map((q) =>
                                          Map<String, dynamic>.from(q as Map))
                                      .toList();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                                child: ExpansionTile(
                                  initiallyExpanded: true,
                                  tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  title: Text(
                                    '${s['subject']} — ${s['weightage'] ?? 50} marks',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A)),
                                  ),
                                  children: [
                                    ...questions.asMap().entries.map((entry) {
                                      final i = entry.key;
                                      final q = entry.value;
                                      final options = ((q['options'] as List?) ??
                                              const [])
                                          .map((o) => o?.toString() ?? '')
                                          .where((o) => o.isNotEmpty)
                                          .toList();
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 4, 16, 10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Q${i + 1}. ${q['question']} (${q['marks'] ?? 10} marks)',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF334155),
                                                  height: 1.35),
                                            ),
                                            if (options.isNotEmpty)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        top: 4, left: 10),
                                                child: Text(
                                                  options.join('   '),
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: Color(0xFF64748B)),
                                                ),
                                              ),
                                            if ((q['answer']?.toString() ??
                                                    '')
                                                .isNotEmpty)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        top: 4, left: 10),
                                                child: Text(
                                                  'Answer key: ${q['answer']}',
                                                  style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color: Color(0xFF059669)),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setDState(() {
                          paperFuture = _entranceService.generatePaper(
                            className: className,
                            username: _userRole,
                            mode: 'online',
                            admissionId: admissionId,
                          );
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Regenerate'),
                    ),
                    const SizedBox(width: 8),
                    if (admission != null)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final paper = await paperFuture;
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _showOfflineEntranceMarksDialog(admission, paper: paper);
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                        label: const Text('Enter Marks'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text(
                          'Open an applicant from the roster to record marks.',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 4: DOCUMENT SCRUTINY MASTER
  // ============================================================================
  Widget _buildDocumentScrutinyTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: const [
              Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CBSE Statutory Verification Desk: Scrutinize mandatory candidate proofs (Birth Certificate, Aadhaar, Countersigned Transfer Certificate, Medical Fitness, RTE Income Proof) prior to offer letter release.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._admissions.map(_buildDocumentAuditCard),
      ],
    );
  }

  Widget _buildDocumentAuditCard(Map<String, dynamic> a) {
    final docs = (a['documents'] as Map<String, dynamic>?) ?? {};
    final bool birth = docs['birth_cert'] == true;
    final bool stdAadhaar = docs['student_aadhaar'] == true;
    final bool parAadhaar = docs['parent_aadhaar'] == true;
    final bool tc = docs['transfer_cert'] == true;
    final bool report = docs['previous_report_card'] == true;
    final bool med = docs['medical_fitness'] == true;
    final bool rteDoc = docs['rte_income_cert'] == true;
    final entranceDone = _isEntranceCompleted(a);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['applicant_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      Text('${a['application_no']} • Applying for ${a['grade_applying']} • Parent: ${a['parent_name']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                if (entranceDone)
                  ElevatedButton.icon(
                    onPressed: () => _showDocumentScrutinyDialog(a),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Update Verification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _openEntranceDesk(a),
                    icon: const Icon(Icons.lock_clock_rounded, size: 16),
                    label: const Text('Complete Entrance Exam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  entranceDone
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  size: 13,
                  color: entranceDone
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    entranceDone
                        ? 'Entrance completed (${a['entrance_exam_mode'] ?? 'offline'}) • ${(a['entrance_percentage'] as num?)?.toStringAsFixed(1) ?? '0'}% • Verification unlocked'
                        : 'Entrance exam pending — document verification is locked until the entrance result is recorded.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: entranceDone
                          ? const Color(0xFF059669)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildDocBadge('Birth Certificate', birth),
                _buildDocBadge('Student Aadhaar', stdAadhaar),
                _buildDocBadge('Parent ID / Aadhaar', parAadhaar),
                _buildDocBadge('Transfer Cert (TC)', tc),
                _buildDocBadge('Previous Report Card', report),
                _buildDocBadge('Medical Fitness', med),
                if (a['rte_quota'] == true) _buildDocBadge('RTE Income Proof', rteDoc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocBadge(String title, bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isVerified ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isVerified ? Icons.check_circle_rounded : Icons.pending_actions_rounded, size: 12, color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706))),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 5: ENTRANCE & INTERACTION ROSTER
  // ============================================================================
  Widget _buildInteractionTestTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Interaction & Academic Readiness Roster', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('Evaluate foundational numeracy, literacy, and conduct', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 14),
        ..._admissions.map((a) {
          final score = (a['test_score'] as num?)?.toInt() ?? 0;
          final notes = a['interaction_notes']?.toString() ?? 'No notes recorded.';
          final date = a['interaction_date']?.toString() ?? 'Not Scheduled';

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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: Center(
                      child: Text(
                        score > 0 ? '$score' : '-',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['applicant_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text('Grade: ${a['grade_applying']} • Test Date: $date • Status: ${a['test_status'] ?? "Pending"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                          child: Text(notes, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _showInteractionTestDialog(a),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                    child: const Text('Record Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================================
  // TAB 6: ENQUIRIES & PROSPECT LEADS
  // ============================================================================
  Widget _buildEnquiriesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Walk-in Enquiries & Prospect Leads', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                SizedBox(height: 2),
                Text('Capture walk-ins, phone inquiries and 1-click convert into full admission applications', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showNewEnquiryDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Record Walk-in Enquiry', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._enquiries.map(_buildEnquiryCard),
      ],
    );
  }

  Widget _buildEnquiryCard(Map<String, dynamic> e) {
    final status = e['status']?.toString() ?? 'Fresh';
    final isConverted = status == 'Converted';

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(e['child_name'] ?? 'Candidate', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isConverted ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isConverted ? const Color(0xFF059669) : const Color(0xFFD97706)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Source: ${e['source']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Parent: ${e['parent_name']} • Mobile: ${e['phone']} • Email: ${e['email'] ?? "N/A"}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 4),
                  Text('Seeking: ${e['grade_seeking']} • Follow-up Date: ${e['follow_up_date'] ?? "N/A"}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Text(e['notes'] ?? '', style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!isConverted)
              ElevatedButton.icon(
                onPressed: () => _convertEnquiry(e['id']),
                icon: const Icon(Icons.transform_rounded, size: 14),
                label: const Text('Convert to Application', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              )
            else
              const Chip(
                avatar: Icon(Icons.check, size: 14, color: Color(0xFF059669)),
                label: Text('Converted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                backgroundColor: Color(0xFFECFDF5),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS & ACTIONS
  // ============================================================================

  void _showCandidateDossierModal(Map<String, dynamic> a) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        (a['applicant_name'] ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['applicant_name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          Text('Application ID: ${a['application_no']} • Class: ${a['grade_applying']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),

                _buildDossierSection('1. Student Identity & Bio-Data', [
                  _buildDossierRow('Date of Birth:', '${a['dob']} (Age: 9 Years)'),
                  _buildDossierRow('Gender / Blood Group:', '${a['gender']} • ${a['blood_group']}'),
                  _buildDossierRow('Category:', '${a['category']} • ${a['rte_quota'] == true ? "RTE 25% EWS Quota" : "General"}'),
                  _buildDossierRow('Aadhaar UID:', '${a['aadhaar_no'] ?? "Provided & Verified"}'),
                  _buildDossierRow('2nd Language:', '${a['second_language'] ?? "Hindi"}'),
                ]),
                const SizedBox(height: 12),

                _buildDossierSection('2. Parent / Guardian KYC', [
                  _buildDossierRow("Father's Name:", '${a['parent_name']} (${a['parent_occupation']})'),
                  _buildDossierRow("Mother's Name:", '${a['mother_name'] ?? "Parent"}'),
                  _buildDossierRow('Contact Mobile:', '${a['parent_phone']}'),
                  _buildDossierRow('Email Address:', '${a['email'] ?? "N/A"}'),
                  _buildDossierRow('Annual Income:', '${a['annual_income'] ?? "Verified"}'),
                  _buildDossierRow('Residential Address:', '${a['address'] ?? "Dehradun"}'),
                ]),
                const SizedBox(height: 12),

                _buildDossierSection('3. Academic Background & Logistics', [
                  _buildDossierRow('Previous School:', '${a['previous_school']}'),
                  _buildDossierRow('Affiliation Board:', '${a['previous_board']}'),
                  _buildDossierRow('Last Exam Performance:', '${a['previous_grade']}'),
                  _buildDossierRow('Transport Facility:', a['transport_required'] == true ? 'Yes (${a['transport_stop']})' : 'Self Transport'),
                ]),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDossierSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDossierRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  void _showDocumentScrutinyDialog(Map<String, dynamic> a) {
    final docs = Map<String, bool>.from((a['documents'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v == true)) ?? {
      'birth_cert': true,
      'student_aadhaar': true,
      'parent_aadhaar': true,
      'transfer_cert': false,
      'previous_report_card': true,
      'medical_fitness': true,
      'rte_income_cert': false,
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Document Scrutiny: ${a['applicant_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('1. Birth Certificate (Municipal Authority)', style: TextStyle(fontSize: 12.5)),
                    value: docs['birth_cert'] ?? false,
                    onChanged: (v) => setDState(() => docs['birth_cert'] = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('2. Student Aadhaar Card (UIDAI Verified)', style: TextStyle(fontSize: 12.5)),
                    value: docs['student_aadhaar'] ?? false,
                    onChanged: (v) => setDState(() => docs['student_aadhaar'] = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('3. Father & Mother Photo ID / Aadhaar', style: TextStyle(fontSize: 12.5)),
                    value: docs['parent_aadhaar'] ?? false,
                    onChanged: (v) => setDState(() => docs['parent_aadhaar'] = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('4. Original Transfer Certificate (TC)', style: TextStyle(fontSize: 12.5)),
                    value: docs['transfer_cert'] ?? false,
                    onChanged: (v) => setDState(() => docs['transfer_cert'] = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('5. Previous Class Progress Report Card', style: TextStyle(fontSize: 12.5)),
                    value: docs['previous_report_card'] ?? false,
                    onChanged: (v) => setDState(() => docs['previous_report_card'] = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('6. Medical Fitness & Vaccination Record', style: TextStyle(fontSize: 12.5)),
                    value: docs['medical_fitness'] ?? false,
                    onChanged: (v) => setDState(() => docs['medical_fitness'] = v ?? false),
                  ),
                  if (a['rte_quota'] == true)
                    CheckboxListTile(
                      title: const Text('7. Revenue Inspector RTE 25% Income Proof', style: TextStyle(fontSize: 12.5)),
                      value: docs['rte_income_cert'] ?? false,
                      onChanged: (v) => setDState(() => docs['rte_income_cert'] = v ?? false),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                // Only the documents actually shown for this applicant are
                // required — a non-RTE application must not be blocked by the
                // hidden RTE income certificate entry.
                final requiredDocKeys = <String>[
                  'birth_cert',
                  'student_aadhaar',
                  'parent_aadhaar',
                  'transfer_cert',
                  'previous_report_card',
                  'medical_fitness',
                  if (a['rte_quota'] == true) 'rte_income_cert',
                ];
                final allDone = requiredDocKeys.every((k) => docs[k] == true);
                final entranceCompleted = a['entrance_exam_status']
                        ?.toString()
                        .toLowerCase() ==
                    'completed';
                if (allDone && !entranceCompleted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Record the entrance exam before verifying all documents.'),
                      backgroundColor: Color(0xFFD97706),
                    ),
                  );
                  return;
                }
                final status = allDone ? 'Verified' : 'Pending';
                final saved = await _schoolService.updateAdmissionDocStatus(
                    a['id'], status,
                    documents: docs);
                if (!saved) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Entrance exam must be recorded before document verification.'),
                        backgroundColor: Color(0xFFD97706),
                      ),
                    );
                  }
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(allDone
                          ? 'All required documents verified — Offer Letter auto-issued.'
                          : 'Verification saved. Some required documents are still pending.'),
                      backgroundColor: allDone
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                  );
                }
              },
              child: const Text('Save Verification'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectAdmissionDialog(Map<String, dynamic> a) {
    final remarksCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Application: ${a['applicant_name']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This closes the application and removes it from the live admission pipeline. Record the reason for the counsellor desk.',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g. Seat unavailable, documents incomplete or eligibility not met',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              final remarks = remarksCtrl.text.trim();
              if (remarks.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason.'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                return;
              }
              await _schoolService.updateAdmissionStatus(a['id'], 'Rejected');
              await _schoolService.logAuditEvent(
                actorUsername: _userRole,
                action: 'Admission Rejected',
                entityType: 'Admission',
                entityId: a['id']?.toString() ?? '',
                details: remarks,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Application rejected and counsellor desk updated.'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              }
            },
            child: const Text('Reject Application'),
          ),
        ],
      ),
    );
  }

  void _showInteractionTestDialog(Map<String, dynamic> a) {
    final scoreCtrl = TextEditingController(text: ((a['test_score'] as num?) ?? 40).toString());
    final notesCtrl = TextEditingController(text: a['interaction_notes'] ?? 'Foundational literacy and numeracy concepts verified.');
    String verdict = 'Recommended';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Interaction Assessment: ${a['applicant_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: scoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Academic Readiness Score (Out of 50)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: verdict,
                  decoration: const InputDecoration(labelText: 'Admission Recommendation Verdict'),
                  items: const [
                    DropdownMenuItem(value: 'Recommended', child: Text('Recommended for Admission')),
                    DropdownMenuItem(value: 'Borderline', child: Text('Borderline / Remedial Support')),
                    DropdownMenuItem(value: 'Not Recommended', child: Text('Not Recommended')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDState(() => verdict = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Principal / Faculty Notes'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This assessment is advisory. It does not change the application stage; use Verify Documents and Issue Offer Letter to advance the application.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                await _schoolService.recordAdmissionTestScore(
                  admissionId: a['id'],
                  score: int.tryParse(scoreCtrl.text) ?? 40,
                  notes: notesCtrl.text.trim(),
                  verdict: verdict,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Record Assessment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIssueOfferLetterDialog(Map<String, dynamic> a) {
    final feeCtrl = TextEditingController(text: ((a['fee_demanded'] as num?) ?? 35000.0).toString());
    final validCtrl = TextEditingController(text: '2026-11-20');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Issue Admission Offer Letter: ${a['applicant_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Admission & Composite Fee (₹)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: validCtrl,
                decoration: const InputDecoration(labelText: 'Offer Acceptance Deadline (YYYY-MM-DD)'),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: const Text(
                  'Once issued, parent receives digital notification and provisional admission offer letter with fee payment challan.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
            onPressed: () async {
              await _schoolService.issueAdmissionOfferLetter(
                admissionId: a['id'],
                feeDemanded: double.tryParse(feeCtrl.text) ?? 35000.0,
                validTill: validCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Issue Offer Letter'),
          ),
        ],
      ),
    );
  }

  void _showOfferLetterPreviewModal(Map<String, dynamic> a) {
    final schoolName = 'SHIVALIK INTERNATIONAL SCHOOL';
    final schoolAddress = 'NH-72, Chakrata Road, Dehradun - 248007, Uttarakhand';
    final affiliationNo = '3530124';
    final principalName = 'Dr. Priya Sharma';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 780),
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('SIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(schoolName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text(schoolAddress, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          Text('Affiliated to CBSE, New Delhi • Affiliation No: $affiliationNo', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Chip(
                      label: const Text('OFFER LETTER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
                      backgroundColor: const Color(0xFFEDE9FE),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 2, color: const Color(0xFFE2E8F0)),
                const SizedBox(height: 20),

                // Reference and date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ref: ${a['application_no'] ?? a['id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    Text('Date: ${_formatDate(a['offer_date'] ?? DateTime.now().toIso8601String())}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('PROVISIONAL ADMISSION OFFER LETTER', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF4C1D95))),
                  ),
                ),
                const SizedBox(height: 24),

                // Salutation
                Text('Dear ${a['parent_name'] ?? 'Parent'},', style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                const SizedBox(height: 16),

                // Body
                Text(
                  'We are pleased to inform you that following the document scrutiny and academic assessment, '
                  'your ward ${a['applicant_name']} has been provisionally granted admission to '
                  '${a['grade_applying']} at $schoolName for the Academic Session ${_academicSessionFromDate(a['offer_date'])}.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5),
                ),
                const SizedBox(height: 20),

                // Fee structure
                const Text('Fee Structure (Provisional):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                _buildFeeStructureTable(a),
                const SizedBox(height: 20),

                // Validity notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.event_busy_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This offer is valid until ${_formatDate(a['offer_valid_till'] ?? '')}. '
                          'Please complete the enrolment formalities and fee payment before this date to confirm the seat.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Terms & Conditions
                _buildTermsSection(),
                const SizedBox(height: 30),

                // Signature Block
                _buildSignatureBlock(
                  principalName: principalName,
                  studentName: a['applicant_name'] ?? 'Student',
                  parentName: a['parent_name'] ?? 'Parent',
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await OfferLetterPdfService.instance.shareOfferLetterPdf(
                          admission: a,
                          schoolName: schoolName,
                          schoolAddress: schoolAddress,
                          affiliationNo: affiliationNo,
                          principalName: principalName,
                          fileName: 'Offer_Letter_${a['application_no'] ?? a['id']}.pdf',
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await OfferLetterPdfService.instance.printOfferLetterPdf(
                          admission: a,
                          schoolName: schoolName,
                          schoolAddress: schoolAddress,
                          affiliationNo: affiliationNo,
                          principalName: principalName,
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _handleApproveAndEnrolFromOfferLetter(a),
                      icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                      label: const Text('Approve & Enrol'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Called from the Offer Letter preview modal to approve & enrol.
  Future<void> _handleApproveAndEnrolFromOfferLetter(Map<String, dynamic> a) async {
    final availableClassItems = _liveClasses.isNotEmpty
        ? _liveClasses.map((c) => c['name']?.toString() ?? c['id']?.toString() ?? 'Class').toList()
        : _gradeOptions.where((g) => g != 'all').toList();

    String selectedClass = (a['grade_applying'] ?? (availableClassItems.isNotEmpty ? availableClassItems.first : 'Class 1')).toString();
    if (!availableClassItems.contains(selectedClass) && availableClassItems.isNotEmpty) {
      selectedClass = availableClassItems.first;
    }
    String section = 'A';
    final feePaidCtrl = TextEditingController(text: ((a['fee_demanded'] as num?) ?? 35000.0).toString());
    String paymentMode = 'Online / UPI';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Approve & Enrol: ${a['applicant_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedClass,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: availableClassItems.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (v) {
                            if (v != null) setDState(() => selectedClass = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: section,
                          decoration: const InputDecoration(labelText: 'Section'),
                          items: const [
                            DropdownMenuItem(value: 'A', child: Text('Section A')),
                            DropdownMenuItem(value: 'B', child: Text('Section B')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDState(() => section = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: feePaidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Admission Fee Collected (₹)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    decoration: const InputDecoration(labelText: 'Payment Mode'),
                    items: const [
                      DropdownMenuItem(value: 'Online / UPI', child: Text('Online / UPI')),
                      DropdownMenuItem(value: 'Bank Transfer / NEFT', child: Text('Bank Transfer / NEFT')),
                      DropdownMenuItem(value: 'Cheque / DD', child: Text('Cheque / DD')),
                      DropdownMenuItem(value: 'Cash at Counter', child: Text('Cash at Counter')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDState(() => paymentMode = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'Approving will generate the admission number and a student login '
                      '(username = year + admission sequence, password = username), '
                      'create the Student Master record, parent link, and fee receipt.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve & Enrol Student'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final selectedEntry = _liveClasses.isEmpty
        ? <String, dynamic>{}
        : _liveClasses.firstWhere(
            (c) =>
                (c['name']?.toString() ?? c['id']?.toString() ?? '') ==
                selectedClass,
            orElse: () => <String, dynamic>{},
          );
    final resolvedClassId =
        (selectedEntry['id']?.toString() ?? '').trim().isNotEmpty
            ? selectedEntry['id'].toString()
            : selectedClass;
    final res = await _schoolService.enrollAdmissionStudent(
      admission: a,
      classId: resolvedClassId,
      className: selectedClass,
      section: section,
      feePaid: double.tryParse(feePaidCtrl.text) ?? 35000.0,
      paymentMode: paymentMode,
    );
    _loadData();
    if (mounted) {
      _showEnrolledCredentialsDialog(a, res);
    }
  }

  Widget _buildFeeStructureTable(Map<String, dynamic> a) {
    final feeDemanded = (a['fee_demanded'] as num?)?.toDouble() ?? 35000.0;
    final admissionFee = 10000.0;
    final cautionMoney = 5000.0;
    final firstQuarter = feeDemanded - admissionFee - cautionMoney;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _feeRow('Admission Fee (One-Time)', '₹${admissionFee.toStringAsFixed(0)}'),
          _dividerRow(),
          _feeRow('Caution Money (Refundable)', '₹${cautionMoney.toStringAsFixed(0)}'),
          _dividerRow(),
          _feeRow('First Quarter Fee', '₹${firstQuarter.toStringAsFixed(0)}'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: _feeRow('Total Payable', '₹${feeDemanded.toStringAsFixed(0)}', isTotal: true),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String amount, {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? const Color(0xFF1E40AF) : const Color(0xFF334155),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? const Color(0xFF1E40AF) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerRow() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0), indent: 16, endIndent: 16);
  }

  Widget _buildTermsSection() {
    final terms = [
      'This admission is provisional and subject to verification of all original documents at the time of physical enrolment.',
      'The fee structure is subject to revision as per school policy and CBSE guidelines.',
      'Caution money is refundable only upon withdrawal/transfer with due clearance certificates.',
      'Attendance of 75% is mandatory as per CBSE norms; failure may affect promotion/examination eligibility.',
      'The school reserves the right to cancel admission if any information provided is found to be incorrect.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Terms & Conditions:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        ...terms.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  Expanded(child: Text(t, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSignatureBlock({
    required String principalName,
    required String studentName,
    required String parentName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 20),
        const Text('Authorised Signatures', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Principal signature with stamp
            Expanded(
              child: Column(
                children: [
                  _signatureLineBox('Principal\'s Signature'),
                  const SizedBox(height: 8),
                  _stampBox(),
                  const SizedBox(height: 10),
                  Text(principalName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text('Principal', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  Text('SHIVALIK INTERNATIONAL SCHOOL', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Parent signature
            Expanded(
              child: Column(
                children: [
                  _signatureLineBox('Parent\'s Signature'),
                  const SizedBox(height: 18),
                  Text(parentName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const Text('Parent / Guardian', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  const Text('Date: __________________', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Student signature
            Expanded(
              child: Column(
                children: [
                  _signatureLineBox('Student\'s Signature'),
                  const SizedBox(height: 18),
                  Text(studentName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const Text('Student', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  const Text('Date: __________________', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _signatureLineBox(String label) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _stampBox() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'School Stamp',
          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _academicSessionFromDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final year = dt.month >= 4 ? dt.year : dt.year - 1;
      return '$year-${(year + 1).toString().substring(2)}';
    } catch (_) {
      return '2026-27';
    }
  }

  void _showFinalEnrollmentDialog(Map<String, dynamic> a) {
    final availableClassItems = _liveClasses.isNotEmpty
        ? _liveClasses.map((c) => c['name']?.toString() ?? c['id']?.toString() ?? 'Class').toList()
        : _gradeOptions.where((g) => g != 'all').toList();

    String selectedClass = (a['grade_applying'] ?? (availableClassItems.isNotEmpty ? availableClassItems.first : 'Class 1')).toString();
    if (!availableClassItems.contains(selectedClass) && availableClassItems.isNotEmpty) {
      selectedClass = availableClassItems.first;
    }
    String section = 'A';
    final feePaidCtrl = TextEditingController(text: ((a['fee_demanded'] as num?) ?? 35000.0).toString());
    String paymentMode = 'Online / UPI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Approve & Enrol: ${a['applicant_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedClass,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: availableClassItems.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (v) {
                            if (v != null) setDState(() => selectedClass = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: section,
                          decoration: const InputDecoration(labelText: 'Section'),
                          items: const [
                            DropdownMenuItem(value: 'A', child: Text('Section A')),
                            DropdownMenuItem(value: 'B', child: Text('Section B')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDState(() => section = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: feePaidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Admission Fee Collected (₹)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    decoration: const InputDecoration(labelText: 'Payment Mode'),
                    items: const [
                      DropdownMenuItem(value: 'Online / UPI', child: Text('Online / UPI')),
                      DropdownMenuItem(value: 'Bank Transfer / NEFT', child: Text('Bank Transfer / NEFT')),
                      DropdownMenuItem(value: 'Cheque / DD', child: Text('Cheque / DD')),
                      DropdownMenuItem(value: 'Cash at Counter', child: Text('Cash at Counter')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDState(() => paymentMode = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'Approving will generate the admission number and a student login '
                      '(username = year + admission sequence, password = username), '
                      'create the Student Master record, parent link, and fee receipt.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () async {
                final selectedEntry = _liveClasses.isEmpty
                    ? <String, dynamic>{}
                    : _liveClasses.firstWhere(
                        (c) =>
                            (c['name']?.toString() ??
                                c['id']?.toString() ??
                                '') ==
                            selectedClass,
                        orElse: () => <String, dynamic>{},
                      );
                final resolvedClassId =
                    (selectedEntry['id']?.toString() ?? '').trim().isNotEmpty
                        ? selectedEntry['id'].toString()
                        : selectedClass;
                final res = await _schoolService.enrollAdmissionStudent(
                  admission: a,
                  classId: resolvedClassId,
                  className: selectedClass,
                  section: section,
                  feePaid: double.tryParse(feePaidCtrl.text) ?? 35000.0,
                  paymentMode: paymentMode,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  _showEnrolledCredentialsDialog(a, res);
                }
              },
              child: const Text('Approve & Enrol Student'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown right after enrolment with the generated admission number and
  /// login credentials the admin should hand over to the family.
  void _showEnrolledCredentialsDialog(
      Map<String, dynamic> a, Map<String, dynamic> res) {
    final username = (res['username'] ?? '').toString();
    final password = (res['password'] ?? username).toString();
    final admissionNo = (res['admission_no'] ?? '').toString();
    final className = (res['class_name'] ?? '').toString();
    final studentName =
        (a['applicant_name'] ?? a['student_name'] ?? 'The student').toString();
    final loginCreated = res['login_created'] != false;

    Widget credentialRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF059669), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text('Student Enrolled',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${studentName} has been approved, enrolled and a '
                'login account was created. Share these credentials with the '
                'student/parent.',
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
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
                    credentialRow('Admission No', admissionNo),
                    credentialRow('Class', className),
                    credentialRow('Username', username),
                    credentialRow('Password', password),
                  ],
                ),
              ),
              if (!loginCreated) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Text(
                    'The student record was saved but the login account could '
                    'not be created automatically. Create it from Manage Users.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'The default password is the same as the username. Ask the '
                'student to change it after the first login.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = 'Admission No: $admissionNo\n'
                  'Class: $className\n'
                  'Username: $username\n'
                  'Password: $password';
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Credentials copied to clipboard'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy Credentials'),
          ),
        ],
      ),
    );
  }

  void _showClassAllotmentDialog(Map<String, dynamic> student) {
    final availableClassItems = _liveClasses.isNotEmpty
        ? _liveClasses
        : [
            {'id': 'cls-10a', 'name': 'Class 10-A'},
            {'id': 'cls-9a', 'name': 'Class 9-A'}
          ];

    String selectedClassId = student['class_id']?.toString() ?? (availableClassItems.isNotEmpty ? availableClassItems.first['id'].toString() : 'cls-10a');
    String selectedClassName = student['class_name']?.toString() ?? (availableClassItems.isNotEmpty ? availableClassItems.first['name'].toString() : 'Class 10-A');
    String section = student['section']?.toString() ?? 'A';
    final studentUsername = student['username']?.toString() ?? student['student_id']?.toString() ?? student['applicant_name']?.toString() ?? '';
    final studentName = student['name']?.toString() ?? student['applicant_name']?.toString() ?? 'Student';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Assign / Transfer Class: $studentName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedClassId,
                decoration: const InputDecoration(labelText: 'Target Class'),
                items: availableClassItems.map((c) {
                  final cid = c['id']?.toString() ?? '';
                  final cname = c['name']?.toString() ?? cid;
                  return DropdownMenuItem(value: cid, child: Text('$cname ($cid)'));
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    final found = availableClassItems.firstWhere((c) => c['id']?.toString() == v, orElse: () => {'name': v});
                    setDState(() {
                      selectedClassId = v;
                      selectedClassName = found['name']?.toString() ?? v;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: section,
                decoration: const InputDecoration(labelText: 'Section'),
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Section A')),
                  DropdownMenuItem(value: 'B', child: Text('Section B')),
                  DropdownMenuItem(value: 'C', child: Text('Section C')),
                ],
                onChanged: (v) {
                  if (v != null) setDState(() => section = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                final success = await _schoolService.assignStudentClass(
                  studentUsername: studentUsername,
                  classId: selectedClassId,
                  className: selectedClassName,
                  section: section,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Student $studentName assigned to $selectedClassName ($section)!' : 'Failed to assign class.'),
                      backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  );
                }
              },
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  void _convertEnquiry(String enquiryId) async {
    await _schoolService.convertEnquiryToApplication(enquiryId);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry converted to application successfully!'), backgroundColor: Color(0xFF2563EB)),
      );
    }
  }

  void _showNewEnquiryDialog() {
    final childCtrl = TextEditingController();
    final parentCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final gradeCtrl = TextEditingController(text: 'Class 1');
    final sourceCtrl = TextEditingController(text: 'Walk-in');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Walk-in Admission Enquiry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: childCtrl, decoration: const InputDecoration(labelText: 'Child / Applicant Name *')),
              const SizedBox(height: 10),
              TextField(controller: parentCtrl, decoration: const InputDecoration(labelText: "Parent / Guardian Name *")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number *'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: gradeCtrl, decoration: const InputDecoration(labelText: 'Grade Seeking'))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: sourceCtrl, decoration: const InputDecoration(labelText: 'Lead Source'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes / Query Details')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              if (childCtrl.text.trim().isEmpty || parentCtrl.text.trim().isEmpty) return;
              await _schoolService.saveAdmissionEnquiry({
                'child_name': childCtrl.text.trim(),
                'parent_name': parentCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'grade_seeking': gradeCtrl.text.trim(),
                'source': sourceCtrl.text.trim(),
                'date': DateTime.now().toIso8601String().substring(0, 10),
                'follow_up_date': DateTime.now().add(const Duration(days: 4)).toIso8601String().substring(0, 10),
                'status': 'Fresh',
                'notes': notesCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save Enquiry'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPREHENSIVE MULTI-STEP INTAKE REGISTRATION WIZARD
// ============================================================================
class _AdmissionIntakeForm extends StatefulWidget {
  final VoidCallback onSubmitted;
  final SchoolService schoolService;

  const _AdmissionIntakeForm({required this.onSubmitted, required this.schoolService});

  @override
  State<_AdmissionIntakeForm> createState() => _AdmissionIntakeFormState();
}

class _AdmissionIntakeFormState extends State<_AdmissionIntakeForm> {
  int _currentStep = 0;

  // Step 1: Student
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(text: '2016-05-12');
  final _aadhaarCtrl = TextEditingController();
  String _gender = 'Male';
  String _bloodGroup = 'B+';
  String _category = 'General';
  bool _isRteQuota = false;

  // Step 2: Parent
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController(text: '₹12,00,000 / year');
  final _addressCtrl = TextEditingController();
  bool _hasSibling = false;
  final _siblingNameCtrl = TextEditingController();

  // Step 3: Academic Mapping
  String _gradeApplying = 'Class 1';
  String _stream = 'N/A';
  String _secondLang = 'Hindi';
  final _prevSchoolCtrl = TextEditingController();
  final _prevBoardCtrl = TextEditingController(text: 'CBSE');
  final _prevMarksCtrl = TextEditingController();
  bool _transportReq = true;
  String _transportStop = 'Jakhan Chowk';

  // Step 4: Documents Checklist
  bool _docBirth = true;
  bool _docStdAadhaar = true;
  bool _docParAadhaar = true;
  bool _docTc = false;
  bool _docReport = true;
  bool _docMed = true;
  bool _docRteIncome = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('New Student Admission Intake Form', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('4-Step CBSE statutory registration wizard with KYC proofs verification', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: Text('Step ${_currentStep + 1} of 4', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: _buildCurrentStepContent(),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Bottom Step Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Previous Step'),
                )
              else
                const SizedBox.shrink(),
              ElevatedButton.icon(
                onPressed: _currentStep < 3 ? () => setState(() => _currentStep++) : _handleSubmitApplication,
                icon: Icon(_currentStep < 3 ? Icons.arrow_forward_rounded : Icons.check_circle_rounded, size: 16),
                label: Text(_currentStep < 3 ? 'Continue to Next Step' : 'Submit Admission Application', style: const TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep < 3 ? const Color(0xFF2563EB) : const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1StudentInfo();
      case 1:
        return _buildStep2ParentInfo();
      case 2:
        return _buildStep3AcademicMapping();
      case 3:
      default:
        return _buildStep4DocumentChecklist();
    }
  }

  Widget _buildStep1StudentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 1: Student Demographics & Statutory Identity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 14),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Applicant Full Legal Name *', hintText: 'As per Municipal Birth Certificate')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD) *'))),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: const InputDecoration(labelText: 'Blood Group'),
                items: const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setState(() => _bloodGroup = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Social Category'),
                items: const ['General', 'OBC (Non-Creamy)', 'SC', 'ST', 'EWS'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _aadhaarCtrl, decoration: const InputDecoration(labelText: 'Aadhaar UID Number (XXXX-XXXX-XXXX)'))),
          ],
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Statutory RTE Act 25% EWS Quota Seat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: const Text('Eligible under Right to Education Act for economically weaker sections with annual household income < ₹1.5 Lakhs.', style: TextStyle(fontSize: 11.5)),
          value: _isRteQuota,
          activeColor: const Color(0xFF059669),
          onChanged: (v) => setState(() => _isRteQuota = v ?? false),
        ),
      ],
    );
  }

  Widget _buildStep2ParentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 2: Parent / Guardian KYC & Residence Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: TextField(controller: _fatherNameCtrl, decoration: const InputDecoration(labelText: "Father's Full Name *"))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _motherNameCtrl, decoration: const InputDecoration(labelText: "Mother's Full Name *"))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Primary Contact Mobile *', prefixText: '+91 '))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Parent Email Address'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _occupationCtrl, decoration: const InputDecoration(labelText: 'Parent Occupation / Enterprise'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _incomeCtrl, decoration: const InputDecoration(labelText: 'Annual Household Income'))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Residential Permanent Address *')),
        const SizedBox(height: 10),
        CheckboxListTile(
          title: const Text('Sibling Currently Studying at Shivalik International', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          value: _hasSibling,
          onChanged: (v) => setState(() => _hasSibling = v ?? false),
        ),
        if (_hasSibling)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(controller: _siblingNameCtrl, decoration: const InputDecoration(labelText: 'Sibling Name & Current Class/Roll')),
          ),
      ],
    );
  }

  Widget _buildStep3AcademicMapping() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 3: Grade Selection & Academic History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gradeApplying,
                decoration: const InputDecoration(labelText: 'Grade Applying For *'),
                items: const [
                  'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
                  'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
                  'Class 11', 'Class 12'
                ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _gradeApplying = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _stream,
                decoration: const InputDecoration(labelText: 'Stream (11th & 12th)'),
                items: const [
                  DropdownMenuItem(value: 'N/A', child: Text('N/A (Up to Class 10)')),
                  DropdownMenuItem(value: 'Science (PCM + CS)', child: Text('Science (PCM + CS)')),
                  DropdownMenuItem(value: 'Science (PCB + Biotech)', child: Text('Science (PCB + Biotech)')),
                  DropdownMenuItem(value: 'Commerce (Accounts + Maths)', child: Text('Commerce (Accounts + Maths)')),
                  DropdownMenuItem(value: 'Humanities & Social Sciences', child: Text('Humanities & Social Sciences')),
                ],
                onChanged: (v) => setState(() => _stream = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _secondLang,
                decoration: const InputDecoration(labelText: 'Second Language'),
                items: const ['Hindi', 'Sanskrit', 'French', 'German'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _secondLang = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(flex: 2, child: TextField(controller: _prevSchoolCtrl, decoration: const InputDecoration(labelText: 'Previous School Attended'))),
            const SizedBox(width: 12),
            Expanded(flex: 1, child: TextField(controller: _prevBoardCtrl, decoration: const InputDecoration(labelText: 'Previous Board (CBSE/ICSE)'))),
            const SizedBox(width: 12),
            Expanded(flex: 1, child: TextField(controller: _prevMarksCtrl, decoration: const InputDecoration(labelText: 'Last Class % or Grade'))),
          ],
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('School Bus Transport Required', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          value: _transportReq,
          onChanged: (v) => setState(() => _transportReq = v ?? true),
        ),
        if (_transportReq)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              initialValue: _transportStop,
              decoration: const InputDecoration(labelText: 'Pickup & Drop Designated Stop'),
              items: const ['Jakhan Chowk', 'Clock Tower', 'Rajpur Road', 'Ballupur Chowk', 'ISBT Dehradun', 'Kishan Nagar'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _transportStop = v!),
            ),
          ),
      ],
    );
  }

  Widget _buildStep4DocumentChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 4: Mandatory Document & KYC Proof Checklist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        const Text('Mark original documents submitted at the registrar counter during application intake.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 14),
        CheckboxListTile(
          title: const Text('1. Municipal Birth Certificate (Original + Copy)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _docBirth,
          onChanged: (v) => setState(() => _docBirth = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('2. Student Aadhaar Card Photocopy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _docStdAadhaar,
          onChanged: (v) => setState(() => _docStdAadhaar = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('3. Father & Mother Photo ID / Aadhaar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _docParAadhaar,
          onChanged: (v) => setState(() => _docParAadhaar = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('4. Original Transfer Certificate (TC - Countersigned by DEO if interstate)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _docTc,
          onChanged: (v) => setState(() => _docTc = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('5. Previous Class Progress Report Card / Marksheet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _docReport,
          onChanged: (v) => setState(() => _docReport = v ?? false),
        ),
        CheckboxListTile(
          title: const Text('6. Medical Fitness Certificate & Blood Group Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _docMed,
          onChanged: (v) => setState(() => _docMed = v ?? false),
        ),
        if (_isRteQuota)
          CheckboxListTile(
            title: const Text('7. Revenue Inspector RTE 25% EWS Income / Caste Certificate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: _docRteIncome,
            onChanged: (v) => setState(() => _docRteIncome = v ?? false),
          ),
      ],
    );
  }

  void _handleSubmitApplication() async {
    final name = _nameCtrl.text.trim();
    final pName = _fatherNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || pName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill mandatory fields: Student Name, Parent Name and Phone.')),
      );
      return;
    }

    final data = {
      'applicant_name': name,
      'dob': _dobCtrl.text.trim(),
      'gender': _gender,
      'blood_group': _bloodGroup,
      'category': _category,
      'aadhaar_no': _aadhaarCtrl.text.trim(),
      'rte_quota': _isRteQuota,
      'parent_name': pName,
      'mother_name': _motherNameCtrl.text.trim(),
      'parent_phone': phone,
      'email': _emailCtrl.text.trim(),
      'parent_occupation': _occupationCtrl.text.trim(),
      'annual_income': _incomeCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'sibling_priority': _hasSibling,
      'sibling_name': _siblingNameCtrl.text.trim(),
      'grade_applying': _gradeApplying,
      'stream': _stream,
      'second_language': _secondLang,
      'previous_school': _prevSchoolCtrl.text.trim(),
      'previous_board': _prevBoardCtrl.text.trim(),
      'previous_grade': _prevMarksCtrl.text.trim(),
      'transport_required': _transportReq,
      'transport_stop': _transportStop,
      'status': 'Under Review',
      'doc_status': (_docBirth && _docStdAadhaar && _docParAadhaar) ? 'Verified' : 'Pending',
      'documents': {
        'birth_cert': _docBirth,
        'student_aadhaar': _docStdAadhaar,
        'parent_aadhaar': _docParAadhaar,
        'transfer_cert': _docTc,
        'previous_report_card': _docReport,
        'medical_fitness': _docMed,
        'rte_income_cert': _docRteIncome,
      },
      'fee_demanded': _isRteQuota ? 0.0 : 35000.0,
    };

    await widget.schoolService.submitAdmission(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admission application for $name submitted successfully!'), backgroundColor: const Color(0xFF059669)),
      );
    }
    widget.onSubmitted();
  }
}
