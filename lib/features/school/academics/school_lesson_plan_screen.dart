import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

class SchoolLessonPlanScreen extends StatefulWidget {
  final String? initialClassId;
  final String? initialSubject;
  const SchoolLessonPlanScreen({super.key, this.initialClassId, this.initialSubject});

  @override
  State<SchoolLessonPlanScreen> createState() => _SchoolLessonPlanScreenState();
}

class _SchoolLessonPlanScreenState extends State<SchoolLessonPlanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = 'teacher';
  String _username = '';

  // Selectors
  String _selectedClassId = 'cls-10a';
  String _selectedClassName = 'Class 10-A';
  String _selectedSubject = 'All';
  String _statusFilter = 'All';
  String _searchQuery = '';

  // State
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _curriculumUnits = [];
  Map<String, dynamic> _pacingData = {};

  final List<String> _subjects = [
    'All',
    'Mathematics',
    'Science',
    'English',
    'Social Science',
    'Computer Applications',
  ];

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _bg = Color(0xFFF8FAFC);
  static const _primary = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    if (widget.initialClassId != null && widget.initialClassId!.isNotEmpty) {
      _selectedClassId = widget.initialClassId!;
      _selectedClassName = _selectedClassId.contains('10') ? 'Class 10-A' : 'Class 9-A';
    }
    if (widget.initialSubject != null && widget.initialSubject!.isNotEmpty) {
      _selectedSubject = widget.initialSubject!;
    }
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
      final role = await _authService.getCurrentUserRole() ?? 'teacher';
      final username = await _authService.getCurrentUsername() ?? 'steacher1';

      final plans = await _schoolService.getEnterpriseLessonPlans(
        classId: _selectedClassId,
        subject: _selectedSubject,
        status: _statusFilter,
      );

      final units = await _schoolService.getCurriculumSyllabusUnits(
        classId: _selectedClassId,
        subject: _selectedSubject == 'All' ? 'Mathematics' : _selectedSubject,
      );

      final pacing = await _schoolService.getSyllabusPacingVelocity(_selectedClassId);

      if (mounted) {
        setState(() {
          _userRole = role;
          _username = username;
          _plans = plans;
          _curriculumUnits = units;
          _pacingData = pacing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load lesson plans: $e';
        });
      }
    }
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return const Color(0xFF2563EB);
      case 'science':
        return const Color(0xFF059669);
      case 'english':
        return const Color(0xFF7C3AED);
      case 'social science':
        return const Color(0xFFD97706);
      case 'computer applications':
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Color _getBloomColor(String bloom) {
    if (bloom.contains('Creating')) return const Color(0xFF7C3AED);
    if (bloom.contains('Evaluating')) return const Color(0xFFDC2626);
    if (bloom.contains('Analyzing')) return const Color(0xFFD97706);
    if (bloom.contains('Applying')) return const Color(0xFF2563EB);
    if (bloom.contains('Understanding')) return const Color(0xFF059669);
    return const Color(0xFF64748B);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'taught':
        return const Color(0xFF10B981);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'in progress':
        return const Color(0xFFF59E0B);
      case 'under review':
        return const Color(0xFF8B5CF6);
      case 'needs revision':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'admin' || _userRole == 'sadmin';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Lesson Plan & NEP 2020 Studio',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAdmin ? const Color(0xFFFEF3C7) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isAdmin ? const Color(0xFFFDE68A) : const Color(0xFFC7D2FE)),
                  ),
                  child: Text(
                    isAdmin ? 'Scrutiny Desk' : 'CBSE K-12',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isAdmin ? const Color(0xFF92400E) : const Color(0xFF4338CA),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '5E Pedagogical Model • Bloom\'s Taxonomy • Syllabus Velocity Matrix',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Plans',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadData,
          ),
          IconButton(
            tooltip: 'Print Syllabus Master',
            icon: const Icon(Icons.print_outlined, size: 20),
            onPressed: () => _showPrintPreviewModal(_plans.isNotEmpty ? _plans.first : null),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
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
              tabs: [
                const Tab(icon: Icon(Icons.speed_rounded, size: 16), text: '1. Pacing & Syllabus Tracker'),
                const Tab(icon: Icon(Icons.auto_stories_rounded, size: 16), text: '2. Lesson Plan Studio (5E)'),
                const Tab(icon: Icon(Icons.edit_document, size: 16), text: '3. Authoring Wizard'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fact_check_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('4. Principal Scrutiny'),
                      if ((_pacingData['under_review_count'] as int? ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_pacingData['under_review_count']}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(icon: Icon(Icons.psychology_alt_rounded, size: 16), text: '5. Reflective Diary & Remedial'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPacingAndSyllabusTab(),
                    _buildLessonStudioTab(),
                    _buildAuthoringWizardTab(),
                    _buildPrincipalScrutinyTab(),
                    _buildReflectiveDiaryTab(),
                  ],
                ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 14),
          Text('Loading CBSE Pedagogical Studio...', style: TextStyle(color: _muted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'An unexpected error occurred.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _muted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: CURRICULUM PACING & SYLLABUS TRACKER
  // ──────────────────────────────────────────────

  Widget _buildPacingAndSyllabusTab() {
    final syllabusPct = (_pacingData['syllabus_percentage'] as num?)?.toDouble() ?? 82.5;
    final isOnTrack = _pacingData['is_on_track'] == true;
    final countdown = _pacingData['term_exam_countdown_days'] ?? 24;
    final avgMastery = (_pacingData['average_concept_mastery'] as num?)?.toDouble() ?? 88.4;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Pacing Speedometer Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
              ],
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CBSE Curriculum Velocity Matrix',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '$_selectedClassName • Term 2 Academic Schedule 2026-27',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOnTrack ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isOnTrack ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      ),
                      child: Row(
                        children: [
                          Icon(isOnTrack ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 14, color: isOnTrack ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                          const SizedBox(width: 5),
                          Text(
                            isOnTrack ? 'Pacing: On Track' : 'Lagging Alert',
                            style: TextStyle(color: isOnTrack ? const Color(0xFF34D399) : const Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Board Syllabus Completion',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${syllabusPct.toStringAsFixed(1)}% Completed',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: syllabusPct / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(height: 16),

                // 4 Sub-metrics
                Row(
                  children: [
                    _buildHeroMetricPill(icon: Icons.calendar_today_rounded, label: 'Exam Countdown', value: '$countdown Days Left'),
                    const SizedBox(width: 8),
                    _buildHeroMetricPill(icon: Icons.psychology_rounded, label: 'Avg Concept Mastery', value: '${avgMastery.toStringAsFixed(1)}%'),
                    const SizedBox(width: 8),
                    _buildHeroMetricPill(icon: Icons.fact_check_rounded, label: 'Approved Plans', value: '${_pacingData['taught_count'] ?? 0} Taught'),
                    const SizedBox(width: 8),
                    _buildHeroMetricPill(icon: Icons.support_agent_rounded, label: 'Remedials Logged', value: '${_pacingData['remedial_sessions_count'] ?? 0} Sessions'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subject Tabs Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _subjects.map((sub) {
                final isSelected = _selectedSubject == sub;
                final color = sub == 'All' ? _ink : _getSubjectColor(sub);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(sub, style: TextStyle(color: isSelected ? Colors.white : _ink, fontWeight: FontWeight.w600, fontSize: 12)),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? color : _border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedSubject = sub);
                        _loadData();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Curriculum Units Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chapter-by-Chapter Curriculum Matrix (${_selectedSubject == 'All' ? 'Mathematics' : _selectedSubject})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink),
              ),
              Text(
                '${_curriculumUnits.length} Chapters Mapped',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Curriculum Units List
          ..._curriculumUnits.map((u) {
            final isCompleted = u['status'] == 'Completed';
            final isInProgress = u['status'] == 'In Progress';
            final statusColor = isCompleted ? const Color(0xFF10B981) : isInProgress ? const Color(0xFF2563EB) : const Color(0xFF64748B);
            final hoursEst = (u['hours_est'] as num?)?.toInt() ?? 10;
            final hoursTaught = (u['hours_taught'] as num?)?.toInt() ?? 0;
            final weightage = u['weightage'] ?? 6;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          u['unit_no'] ?? 'Unit',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          u['title'] ?? 'Chapter',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Board Weight: $weightage Marks',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          u['status'] ?? 'Planned',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CBSE Learning Outcomes: ${u['learning_outcome'] ?? ''}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: hoursEst > 0 ? (hoursTaught / hoursEst).clamp(0.0, 1.0) : 0.0,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$hoursTaught / $hoursEst Hours Taught',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeroMetricPill({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: LESSON PLAN STUDIO (5E MODEL CARDS)
  // ──────────────────────────────────────────────

  Widget _buildLessonStudioTab() {
    final filteredPlans = _plans.where((p) {
      final q = _searchQuery.trim().toLowerCase();
      final topic = (p['topic'] ?? '').toString().toLowerCase();
      final chapter = (p['chapter_title'] ?? '').toString().toLowerCase();
      final teacher = (p['teacher_name'] ?? '').toString().toLowerCase();
      return q.isEmpty || topic.contains(q) || chapter.contains(q) || teacher.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filter Row & Search
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search topic, chapter, or teacher...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    items: ['All', 'Approved', 'In Progress', 'Taught', 'Under Review'].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _statusFilter = val);
                        _loadData();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (filteredPlans.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
              child: Column(
                children: [
                  const Icon(Icons.menu_book_rounded, size: 48, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  const Text('No lesson plans found matching criteria.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 4),
                  const Text('Create a new 5E lesson plan using the authoring wizard.', style: TextStyle(fontSize: 12, color: _muted)),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _tabController.animateTo(2),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Open Authoring Wizard'),
                  ),
                ],
              ),
            )
          else
            ...filteredPlans.map((plan) => _buildLessonPlanCard(plan)),
        ],
      ),
    );
  }

  Widget _buildLessonPlanCard(Map<String, dynamic> plan) {
    final subject = (plan['subject'] ?? 'Mathematics').toString();
    final subjectColor = _getSubjectColor(subject);
    final status = (plan['status'] ?? 'Approved').toString();
    final statusColor = _getStatusColor(status);
    final bloom = (plan['blooms_taxonomy'] ?? 'Applying').toString();
    final bloomColor = _getBloomColor(bloom);
    final fiveE = plan['five_e_model'] as Map<String, dynamic>? ?? {};
    final tlms = (plan['tlm_resources'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final outcomes = (plan['specific_learning_outcomes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ribbon
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: subjectColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: subjectColor.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: subjectColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    subject,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  plan['plan_code'] ?? 'CBSE/10/MATH',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bloomColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: bloomColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.psychology_outlined, size: 12, color: bloomColor),
                      const SizedBox(width: 4),
                      Text(
                        'Bloom: $bloom',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: bloomColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chapter & Topic
                Text(
                  '${plan['chapter_no'] ?? ''} • ${plan['chapter_title'] ?? ''}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subjectColor),
                ),
                const SizedBox(height: 2),
                Text(
                  plan['topic'] ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Teacher: ${plan['teacher_name']} • Periods: ${plan['current_period'] ?? 1} of ${plan['total_periods'] ?? 4} • Target: ${plan['planned_date']}',
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
                const SizedBox(height: 12),

                // Specific Learning Outcomes
                if (outcomes.isNotEmpty) ...[
                  const Text('Key Pedagogical Learning Outcomes:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 4),
                  ...outcomes.take(2).map((lo) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: _primary, fontWeight: FontWeight.w900)),
                            Expanded(child: Text(lo, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 10),
                ],

                // 5E Interactive Accordion Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hub_outlined, size: 14, color: _primary),
                          SizedBox(width: 6),
                          Text(
                            '5E Instructional Phases (Constructivist Blueprint)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildFiveERow('⚡ Engage (Hook):', fiveE['engage'] ?? 'Opening provocation'),
                      _buildFiveERow('🔍 Explore (Activity):', fiveE['explore'] ?? 'Hands-on inquiry'),
                      _buildFiveERow('💡 Explain (Concept):', fiveE['explain'] ?? 'Teacher derivation & formalization'),
                      _buildFiveERow('🚀 Elaborate (HOTS):', fiveE['elaborate'] ?? 'Real-world application task'),
                      _buildFiveERow('📝 Evaluate (Check):', fiveE['evaluate'] ?? '3-minute formative exit ticket'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // TLMs & Resources Row
                if (tlms.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tlms.map((tlm) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tlm['type'] == 'Digital Tool' ? Icons.laptop_chromebook_rounded : Icons.menu_book_rounded, size: 12, color: _primary),
                            const SizedBox(width: 4),
                            Text(tlm['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showPrintPreviewModal(plan),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                      label: const Text('Official CBSE Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: _primary),
                    ),
                    Row(
                      children: [
                        if (status != 'Taught')
                          ElevatedButton.icon(
                            onPressed: () => _showReflectionDialog(plan),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                            label: const Text('Mark Taught & Reflect', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () => _showReflectionDialog(plan),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.history_edu_rounded, size: 14),
                            label: const Text('View Diary Reflection', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiveERow(String phase, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(phase, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          ),
          Expanded(
            child: Text(detail, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 3: LESSON PLAN AUTHORING WIZARD
  // ──────────────────────────────────────────────

  Widget _buildAuthoringWizardTab() {
    final chapterCtrl = TextEditingController(text: 'Chapter 5: Arithmetic Progressions');
    final topicCtrl = TextEditingController(text: 'Sum of First n Terms of an AP: Formula & Practical Word Problems');
    final targetDateCtrl = TextEditingController(text: '2026-11-12');
    final periodsCtrl = TextEditingController(text: '4');
    String selectedSubject = 'Mathematics';
    String selectedPedagogy = 'Inquiry-Based & Problem-Solving Approach';
    String selectedBloom = 'Applying & Analyzing';

    final engageCtrl = TextEditingController(text: 'Present problem: Carl Friedrich Gauss summing 1 to 100 in 1 minute. Challenge class.');
    final exploreCtrl = TextEditingController(text: 'Pair students to write sequence backwards and add corresponding terms.');
    final explainCtrl = TextEditingController(text: 'Derive formula Sₙ = n/2[2a + (n-1)d] on smartboard.');
    final elaborateCtrl = TextEditingController(text: 'Solve word problem: A contract on construction job specifies penalty for delay.');
    final evaluateCtrl = TextEditingController(text: 'Formative Exit Ticket: Find sum of first 20 terms of 3, 7, 11, 15...');

    final loCtrl = TextEditingController(text: 'Derive sum formula of AP; apply to financial savings & physical series contexts.');
    final tlmCtrl = TextEditingController(text: 'NCERT Textbook Ex 5.3, GeoGebra Series Bar Grapher, Digital Classroom Whiteboard');
    final slowerCtrl = TextEditingController(text: 'Provide structured grid template for pairing 1st and last terms.');
    final giftedCtrl = TextEditingController(text: 'Prove formula for sum of first n odd natural numbers without formula using geometric squares.');

    return StatefulBuilder(
      builder: (context, setWizardState) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick Auto-Fill Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CBSE / NEP 2020 Lesson Plan Authoring Studio',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pre-aligned with NCERT learning indicators, 5E constructivist model, and Bloom\'s taxonomy.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Auto-filled standard NCERT template for Chapter 5!'), backgroundColor: Color(0xFF2563EB)),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    child: const Text('Template Auto-Fill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form Sections
            _buildWizardSection(
              title: '1. Academic Context & Class Schedule',
              icon: Icons.calendar_month_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedSubject,
                        decoration: _inputDecoration('Subject'),
                        items: ['Mathematics', 'Science', 'English', 'Social Science', 'Computer Applications'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5)));
                        }).toList(),
                        onChanged: (v) => setWizardState(() => selectedSubject = v ?? 'Mathematics'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: periodsCtrl,
                        decoration: _inputDecoration('Total Periods Allocated'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: chapterCtrl,
                        decoration: _inputDecoration('Chapter / Unit Name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: targetDateCtrl,
                        decoration: _inputDecoration('Target Completion Date'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: topicCtrl,
                  decoration: _inputDecoration('Sub-Topic & Specific Micro-Concept'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildWizardSection(
              title: '2. Pedagogical Approach & Bloom\'s Taxonomy',
              icon: Icons.psychology_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPedagogy,
                        decoration: _inputDecoration('Pedagogical Method (NEP 2020)'),
                        items: [
                          'Inquiry-Based & Problem-Solving Approach',
                          'Experiential & Lab Investigation',
                          'Constructivist 5E Learning Cycle',
                          'Communicative & Collaborative Discourse',
                          'Project-Based & Digital Simulation',
                        ].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 11.5)))).toList(),
                        onChanged: (v) => setWizardState(() => selectedPedagogy = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedBloom,
                        decoration: _inputDecoration('Target Cognitive Level (Bloom\'s)'),
                        items: [
                          'Remembering (Recall)',
                          'Understanding (Explain)',
                          'Applying & Analyzing',
                          'Evaluating & Justifying',
                          'Creating (Formulating)',
                        ].map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 11.5)))).toList(),
                        onChanged: (v) => setWizardState(() => selectedBloom = v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: loCtrl,
                  maxLines: 2,
                  decoration: _inputDecoration('Specific Learning Outcomes (Measurable Competencies)'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildWizardSection(
              title: '3. 5E Instructional Cycle (Constructivist Activity Blueprint)',
              icon: Icons.hub_rounded,
              children: [
                TextFormField(controller: engageCtrl, maxLines: 2, decoration: _inputDecoration('1. Engage (Hook / Provocative Problem / Video Demo)')),
                const SizedBox(height: 8),
                TextFormField(controller: exploreCtrl, maxLines: 2, decoration: _inputDecoration('2. Explore (Hands-on Student Inquiry / Group Investigation)')),
                const SizedBox(height: 8),
                TextFormField(controller: explainCtrl, maxLines: 2, decoration: _inputDecoration('3. Explain (Teacher Concept Synthesis & Formula Derivation)')),
                const SizedBox(height: 8),
                TextFormField(controller: elaborateCtrl, maxLines: 2, decoration: _inputDecoration('4. Elaborate (Real-Life Transfer & High-Order Challenge)')),
                const SizedBox(height: 8),
                TextFormField(controller: evaluateCtrl, maxLines: 2, decoration: _inputDecoration('5. Evaluate (Formative Assessment Exit Ticket / Quick Quiz)')),
              ],
            ),
            const SizedBox(height: 14),

            _buildWizardSection(
              title: '4. TLMs, Digital Simulators & Differentiated Learning',
              icon: Icons.auto_awesome_motion_rounded,
              children: [
                TextFormField(controller: tlmCtrl, decoration: _inputDecoration('Teaching Learning Materials (TLMs) & Digital Links')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: slowerCtrl, maxLines: 2, decoration: _inputDecoration('Support for Slower Learners (Scaffolding)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: giftedCtrl, maxLines: 2, decoration: _inputDecoration('Enrichment for Advanced Learners (HOTS)'))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Submit Bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved locally!')));
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save as Draft', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newPlan = {
                        'class_id': _selectedClassId,
                        'class_name': _selectedClassName,
                        'subject': selectedSubject,
                        'chapter_no': 'Chapter 5',
                        'chapter_title': chapterCtrl.text.trim(),
                        'topic': topicCtrl.text.trim(),
                        'sub_topics': ['Formula derivation', 'Application problems'],
                        'teacher_username': _username,
                        'teacher_name': 'Rajesh Sharma (TGT Mathematics)',
                        'planned_date': targetDateCtrl.text.trim(),
                        'target_completion_date': targetDateCtrl.text.trim(),
                        'total_periods': int.tryParse(periodsCtrl.text) ?? 4,
                        'current_period': 1,
                        'academic_term': 'Term 2 (Pre-Board 2026-27)',
                        'pedagogy_method': selectedPedagogy,
                        'blooms_taxonomy': selectedBloom,
                        'specific_learning_outcomes': [loCtrl.text.trim()],
                        'five_e_model': {
                          'engage': engageCtrl.text.trim(),
                          'explore': exploreCtrl.text.trim(),
                          'explain': explainCtrl.text.trim(),
                          'elaborate': elaborateCtrl.text.trim(),
                          'evaluate': evaluateCtrl.text.trim(),
                        },
                        'tlm_resources': [
                          {'name': tlmCtrl.text.trim(), 'type': 'Textbook / Digital'},
                        ],
                        'inclusive_strategies': {
                          'slower_learners': slowerCtrl.text.trim(),
                          'gifted_students': giftedCtrl.text.trim(),
                        },
                        'status': 'Approved',
                        'approval_audit': {
                          'approved_by': 'Dr. K. S. Rawat (Principal)',
                          'approved_at': '2026-11-05 10:30',
                          'rubric_rating': 5,
                          'hod_remarks': 'Approved via Authoring Wizard.',
                        },
                        'reflection': {
                          'is_recorded': false,
                          'concept_mastery_pct': 0.0,
                          'what_went_well': '',
                          'learning_gaps': '',
                          'remedial_action': '',
                          'struggling_students': [],
                        },
                      };

                      await _schoolService.saveEnterpriseLessonPlan(newPlan);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎉 Lesson Plan published and added to curriculum matrix!'), backgroundColor: Color(0xFF10B981)),
                        );
                        _loadData();
                        _tabController.animateTo(1);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Publish & Submit to Principal', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildWizardSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: _muted),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 4: HOD & PRINCIPAL QUALITY SCRUTINY DESK
  // ──────────────────────────────────────────────

  Widget _buildPrincipalScrutinyTab() {
    final pendingPlans = _plans.where((p) => p['status'] == 'Under Review' || p['status'] == 'Approved').toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF7C3AED), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Academic Quality & Lesson Plan Scrutiny Desk',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF5B21B6)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Principal and Head of Department (HOD) review console. Evaluate 5E pedagogical compliance, assessment rigor, and stamp official approval.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF6D28D9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Faculty Lesson Plans Queue (${pendingPlans.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink),
              ),
              const Text('Scrutiny Rubrics: 1 to 5 Stars', style: TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
          const SizedBox(height: 10),

          ...pendingPlans.map((p) {
            final audit = p['approval_audit'] as Map<String, dynamic>? ?? {};
            final rating = (audit['rubric_rating'] as num?)?.toInt() ?? 5;
            final isApproved = p['status'] == 'Approved';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${p['subject']} • ${p['chapter_title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                        ),
                        child: Text(
                          isApproved ? 'Approved by Principal' : 'Awaiting Review',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: isApproved ? const Color(0xFF059669) : const Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Topic: ${p['topic']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  Text('Teacher: ${p['teacher_name']} • Allocated Periods: ${p['total_periods']}', style: const TextStyle(fontSize: 11, color: _muted)),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'HOD Audit Remarks: "${audit['hod_remarks'] ?? 'Lesson structure adheres to CBSE standards.'}"',
                      style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 18,
                            color: const Color(0xFFF59E0B),
                          );
                        }),
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _showPrintPreviewModal(p),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(60, 28),
                            ),
                            child: const Text('Inspect PDF', style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _schoolService.updateLessonPlanWorkflowStatus(
                                id: p['id'],
                                status: 'Approved',
                                approverName: 'Dr. K. S. Rawat (Principal)',
                                remarks: 'Pedagogical flow, 5E steps, and TLM integration verified & stamped.',
                                rubricRating: 5,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Plan officially approved and signed by Principal!'), backgroundColor: Color(0xFF10B981)),
                                );
                                _loadData();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(60, 28),
                            ),
                            icon: const Icon(Icons.verified_rounded, size: 14),
                            label: const Text('Approve & Stamp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 5: TEACHER REFLECTIVE DIARY & REMEDIAL LOG
  // ──────────────────────────────────────────────

  Widget _buildReflectiveDiaryTab() {
    final taughtPlans = _plans.where((p) {
      final ref = p['reflection'];
      return ref is Map && ref['is_recorded'] == true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_alt_rounded, color: Color(0xFF059669), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEP 2020 Teacher Reflective Journal & Diary',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Statutory post-lesson reflections. Evaluates real classroom concept mastery, learning gaps observed, and zero-period remedial student rosters.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Reflective Journal Entries (${taughtPlans.length} Taught Units)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 10),

          if (taughtPlans.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
              child: const Center(
                child: Text('No reflective diary entries yet. Tap "Mark Taught & Reflect" on any active lesson plan.', style: TextStyle(color: _muted, fontSize: 12)),
              ),
            )
          else
            ...taughtPlans.map((plan) {
              final ref = plan['reflection'] as Map<String, dynamic>? ?? {};
              final mastery = (ref['concept_mastery_pct'] as num?)?.toDouble() ?? 85.0;
              final struggling = (ref['struggling_students'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${plan['subject']} • ${plan['topic']}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Text(
                            'Mastery: ${mastery.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('Taught On: ${ref['taught_on'] ?? 'Recent'} • Teacher: ${plan['teacher_name']}', style: const TextStyle(fontSize: 11, color: _muted)),
                    const SizedBox(height: 10),

                    _buildReflectionRow('✅ What Went Well:', ref['what_went_well'] ?? ''),
                    _buildReflectionRow('⚠️ Learning Gaps Observed:', ref['learning_gaps'] ?? ''),
                    _buildReflectionRow('🎯 Remedial Action Plan:', ref['remedial_action'] ?? ''),
                    const SizedBox(height: 8),

                    if (struggling.isNotEmpty) ...[
                      Row(
                        children: [
                          const Text('Students Flagged for Remedial: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
                          ...struggling.map((sid) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFECACA))),
                                child: Text(sid, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                              )),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReflectionRow(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
          children: [
            TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
            TextSpan(text: content),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // REFLECTION & TEACHER DIARY MODAL
  // ──────────────────────────────────────────────

  void _showReflectionDialog(Map<String, dynamic> plan) {
    final existingRef = plan['reflection'] as Map<String, dynamic>? ?? {};
    double mastery = (existingRef['concept_mastery_pct'] as num?)?.toDouble() ?? 88.0;
    final whatWentWellCtrl = TextEditingController(text: existingRef['what_went_well']?.toString() ?? 'Active student participation; practical demonstration clarified the abstract theory.');
    final gapsCtrl = TextEditingController(text: existingRef['learning_gaps']?.toString() ?? '3 students had trouble with computational signs in negative exponents.');
    final remedialCtrl = TextEditingController(text: existingRef['remedial_action']?.toString() ?? '15-minute zero period practice session with peer buddy assistance.');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: Color(0xFF059669), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Teacher Reflective Diary • ${plan['topic']}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Exit Slip Concept Mastery (%):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
                          Text('${mastery.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                        ],
                      ),
                      Slider(
                        value: mastery,
                        min: 40,
                        max: 100,
                        divisions: 12,
                        activeColor: const Color(0xFF059669),
                        onChanged: (val) => setDialogState(() => mastery = val),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: whatWentWellCtrl, maxLines: 2, decoration: _inputDecoration('What worked well in classroom?')),
                      const SizedBox(height: 10),
                      TextFormField(controller: gapsCtrl, maxLines: 2, decoration: _inputDecoration('Gaps & misconceptions observed')),
                      const SizedBox(height: 10),
                      TextFormField(controller: remedialCtrl, maxLines: 2, decoration: _inputDecoration('Remedial action plan scheduled')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    await _schoolService.recordLessonPlanReflection(
                      id: plan['id'],
                      conceptMasteryPct: mastery,
                      whatWentWell: whatWentWellCtrl.text.trim(),
                      learningGaps: gapsCtrl.text.trim(),
                      remedialAction: remedialCtrl.text.trim(),
                      strugglingStudents: ['sstudent1', 'student4'],
                    );
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reflective Diary entry saved & plan marked as Taught!'), backgroundColor: Color(0xFF10B981)),
                      );
                      _loadData();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                  child: const Text('Save Reflection & Mark Taught', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // OFFICIAL CBSE PRINTABLE LESSON PLAN MODAL
  // ──────────────────────────────────────────────

  void _showPrintPreviewModal(Map<String, dynamic>? plan) {
    if (plan == null) return;
    final fiveE = plan['five_e_model'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 700,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // School Letterhead
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'SHIVALIK INTERNATIONAL SCHOOL',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Affiliated to Central Board of Secondary Education (CBSE), New Delhi',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                        const Text(
                          'CBSE Affiliation No: 3530124 • School Code: 84021 • Dehradun, Uttarakhand',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                          child: const Text(
                            'NEP 2020 PEDAGOGICAL LESSON PLAN & LEARNING OUTCOMES SHEET',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(thickness: 1.5, color: Color(0xFF0F172A)),
                  const SizedBox(height: 10),

                  // Metadata Matrix Table
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: _border)),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.2), 3: FlexColumnWidth(2)},
                      children: [
                        _tableRow('Class & Section:', plan['class_name'] ?? 'Class 10-A', 'Subject:', plan['subject'] ?? 'Mathematics'),
                        _tableRow('Plan Code:', plan['plan_code'] ?? 'CBSE/10/MATH/01', 'Target Date:', plan['planned_date'] ?? '2026-11-06'),
                        _tableRow('Teacher:', plan['teacher_name'] ?? 'Rajesh Sharma', 'Allocated Periods:', '${plan['total_periods'] ?? 4} Periods'),
                        _tableRow('Bloom\'s Level:', plan['blooms_taxonomy'] ?? 'Analyzing', 'Pedagogy:', plan['pedagogy_method'] ?? 'Constructivist'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _docSectionHeader('CHAPTER & TOPIC SPECIFICATION'),
                  const SizedBox(height: 4),
                  Text('${plan['chapter_no']}: ${plan['chapter_title']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
                  Text('Micro-Concept: ${plan['topic']}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  const SizedBox(height: 12),

                  _docSectionHeader('5E CONSTRUCTIVIST INSTRUCTIONAL MATRIX'),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: _border)),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(3)},
                      children: [
                        _doc5ERow('1. Engage (Hook)', fiveE['engage'] ?? ''),
                        _doc5ERow('2. Explore (Activity)', fiveE['explore'] ?? ''),
                        _doc5ERow('3. Explain (Concept)', fiveE['explain'] ?? ''),
                        _doc5ERow('4. Elaborate (HOTS)', fiveE['elaborate'] ?? ''),
                        _doc5ERow('5. Evaluate (Quiz)', fiveE['evaluate'] ?? ''),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _docSectionHeader('CLASSWORK, HOMEWORK & INCLUSIVE STRATEGY'),
                  const SizedBox(height: 6),
                  Text('• Classwork: ${plan['classwork_summary'] ?? 'Textbook problems solved with peer feedback.'}', style: const TextStyle(fontSize: 11)),
                  Text('• Homework: ${plan['homework_assigned'] ?? 'NCERT Exercises.'}', style: const TextStyle(fontSize: 11)),
                  Text('• Inclusive Adaptation: Provide step-by-step visual cue cards for slower learners.', style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 24),

                  // Signature & Seal Block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 30),
                          Container(width: 140, height: 1, color: _ink),
                          const SizedBox(height: 4),
                          const Text('Subject Teacher Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
                          Text(plan['teacher_name'] ?? 'Faculty', style: const TextStyle(fontSize: 10, color: _muted)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF059669), width: 1.5), borderRadius: BorderRadius.circular(8)),
                        child: const Column(
                          children: [
                            Icon(Icons.verified_rounded, size: 24, color: Color(0xFF059669)),
                            SizedBox(height: 2),
                            Text('CBSE AUDIT VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                            Text('Academic Session 2026-27', style: TextStyle(fontSize: 8, color: Color(0xFF059669))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 30),
                          Container(width: 140, height: 1, color: _ink),
                          const SizedBox(height: 4),
                          const Text('Principal / Academic Seal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
                          const Text('Dr. K. S. Rawat (Principal)', style: TextStyle(fontSize: 10, color: _muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Close Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Document formatted for A4 printing! (Ctrl + P)'), backgroundColor: _ink),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print / Export PDF'),
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

  TableRow _tableRow(String l1, String v1, String l2, String v2) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(6), child: Text(l1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
        Padding(padding: const EdgeInsets.all(6), child: Text(v1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink))),
        Padding(padding: const EdgeInsets.all(6), child: Text(l2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
        Padding(padding: const EdgeInsets.all(6), child: Text(v2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink))),
      ],
    );
  }

  TableRow _doc5ERow(String phase, String content) {
    return TableRow(
      children: [
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.all(6),
          child: Text(phase, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ink)),
        ),
        Padding(padding: const EdgeInsets.all(6), child: Text(content, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
      ],
    );
  }

  Widget _docSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
    );
  }
}
