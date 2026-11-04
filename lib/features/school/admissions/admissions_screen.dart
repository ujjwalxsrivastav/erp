import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen> {
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
    'Interview Scheduled',
    'Offer Letter Issued',
    'Approved',
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

  @override
  void initState() {
    super.initState();
    _loadData();
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

      if (!mounted) return;
      setState(() {
        _userRole = role;
        _admissions = admissions;
        _enquiries = enquiries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load admission system: $e';
      });
    }
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

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(hasTabs: true),
        body: TabBarView(
          children: [
            _buildPipelineTab(),
            _buildIntakeWizardTab(),
            _buildDocumentScrutinyTab(),
            _buildInteractionTestTab(),
            _buildEnquiriesTab(),
          ],
        ),
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
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Color(0xFF2563EB),
                  unselectedLabelColor: Color(0xFF64748B),
                  indicatorColor: Color(0xFF2563EB),
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(icon: Icon(Icons.view_kanban_rounded, size: 16), text: '1. Admission Pipeline'),
                    Tab(icon: Icon(Icons.person_add_alt_1_rounded, size: 16), text: '2. New Intake Form'),
                    Tab(icon: Icon(Icons.verified_user_rounded, size: 16), text: '3. Document Scrutiny'),
                    Tab(icon: Icon(Icons.quiz_rounded, size: 16), text: '4. Entrance & Interaction'),
                    Tab(icon: Icon(Icons.contact_phone_rounded, size: 16), text: '5. Prospect Leads & Enquiries'),
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
    final interview = _statusCounts['Interview Scheduled'] ?? 0;
    final offerIssued = _statusCounts['Offer Letter Issued'] ?? 0;
    final enrolled = _statusCounts['Enrolled'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Metric Banner
        Row(
          children: [
            Expanded(child: _buildMetricTile('Total Applications', '${_admissions.length}', 'Session 2026-27 Intake', Icons.folder_shared_rounded, const Color(0xFF2563EB))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricTile('Under Scrutiny', '$underReview', 'KYC & Document Review', Icons.hourglass_top_rounded, const Color(0xFFD97706))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricTile('Interaction / Test', '$interview', 'Readiness assessment', Icons.event_available_rounded, const Color(0xFF0284C7))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricTile('Offer Letters', '$offerIssued', 'Awaiting Fee Deposit', Icons.mail_outline_rounded, const Color(0xFF7C3AED))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricTile('Enrolled Students', '$enrolled', '38/45 RTE Seats Filled', Icons.school_rounded, const Color(0xFF059669))),
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
                        'Applying for: ${a['grade_applying']} • Stream: ${a['stream'] ?? "General"} • DOB: ${a['dob']} (${a['gender'] ?? "N/A"})',
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
                  onPressed: () => _showDocumentScrutinyDialog(a),
                  icon: const Icon(Icons.fact_check_rounded, size: 14),
                  label: const Text('Scrutiny Documents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
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
                const Spacer(),

                // Decision Action
                if (status == 'Approved' || status == 'Under Review' || status == 'Interview Scheduled')
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
                    label: const Text('Complete Enrolment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ] else if (status == 'Enrolled') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text('Enrolled as ${a['enrolled_class'] ?? a['grade_applying']} • Adm: ${a['admission_no'] ?? "ADM2026/089"}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                      ],
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
        DefaultTabController.of(context).animateTo(0);
      },
      schoolService: _schoolService,
    );
  }

  // ============================================================================
  // TAB 3: DOCUMENT SCRUTINY MASTER
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
                ElevatedButton.icon(
                  onPressed: () => _showDocumentScrutinyDialog(a),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Update Verification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
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
  // TAB 4: ENTRANCE & INTERACTION ROSTER
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
  // TAB 5: ENQUIRIES & PROSPECT LEADS
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
                final allDone = docs.values.every((v) => v);
                final status = allDone ? 'Verified' : 'Pending';
                await _schoolService.updateAdmissionDocStatus(a['id'], status, documents: docs);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Save Verification'),
            ),
          ],
        ),
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                    child: const Center(child: Text('SIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('SHIVALIK INTERNATIONAL SCHOOL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('Affiliated to CBSE, New Delhi • Affiliation No: 3530124', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const Chip(label: Text('OFFER LETTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))), backgroundColor: Color(0xFFEDE9FE)),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFE2E8F0)),
              Text('Ref: SIS/ADM/2026/${a['id'].toString().replaceAll(RegExp(r'[^0-9]'), '')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Text('PROVISIONAL ADMISSION OFFER: ${a['grade_applying'].toString().toUpperCase()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              Text(
                'Dear ${a['parent_name']},\n\nWe are pleased to inform you that following the document scrutiny and academic interaction, your ward ${a['applicant_name']} has been provisionally granted admission to ${a['grade_applying']} at Shivalik International School for the Academic Session 2026-27.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildDossierRow('Admission Fee:', '₹10,000 (One-Time)'),
                    _buildDossierRow('Caution Money:', '₹5,000 (Refundable)'),
                    _buildDossierRow('First Quarter Fee:', '₹20,000'),
                    const Divider(height: 12),
                    _buildDossierRow('Total Payable:', '₹${(a['fee_demanded'] as num?)?.toStringAsFixed(0) ?? "35000"}'),
                    _buildDossierRow('Valid Till:', a['offer_valid_till'] ?? '2026-11-20'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer Letter sent to printer / PDF queue.')));
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Official Letter'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFinalEnrollmentDialog(Map<String, dynamic> a) {
    String selectedClass = (a['grade_applying'] ?? 'Class 1').toString();
    String section = 'A';
    final feePaidCtrl = TextEditingController(text: ((a['fee_demanded'] as num?) ?? 35000.0).toString());
    String paymentMode = 'Online / UPI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Final Enrollment: ${a['applicant_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                          items: _gradeOptions.where((g) => g != 'all').map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
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
                      'Enrolling will automatically create Student Master record, Parent link, and Official Fee Receipt.',
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
                final res = await _schoolService.enrollAdmissionStudent(
                  admission: a,
                  classId: selectedClass,
                  section: section,
                  feePaid: double.tryParse(feePaidCtrl.text) ?? 35000.0,
                  paymentMode: paymentMode,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Enrolled ${a['applicant_name']} successfully! Admission No: ${res['admission_no']}'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
              child: const Text('Confirm & Enrol Student'),
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
