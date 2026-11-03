import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

class HomeworkListScreen extends StatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  State<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends State<HomeworkListScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();
  late TabController _tabController;

  String? _role;
  bool _isLoading = true;

  List<Map<String, dynamic>> _homework = [];
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;

  // Student context (resolved from backend — students do NOT pick a class)
  bool _isStudent = false;
  String _username = '';
  Map<String, dynamic>? _myProfile;
  // homework_id -> my submission record (proof of what/when was submitted)
  Map<String, Map<String, dynamic>> _mySubmissions = {};
  // homework_id -> real submission count from backend (teacher view)
  Map<String, int> _submissionCounts = {};

  // Subject colour map (cycles by index)
  static const List<Color> _subjectColors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  Color _colorForSubject(String subject) {
    final idx = subject.codeUnits.fold(0, (a, b) => a + b) % _subjectColors.length;
    return _subjectColors[idx];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  bool get _canPickClass => !_isStudent;

  Future<void> _init() async {
    final role = await _authService.getCurrentUserRole();
    if (!mounted) return;
    setState(() {
      _role = role;
      _isStudent = role == 'student' || role == 'parent';
    });

    // Students: resolve their own class from the backend (no class chooser).
    if (_isStudent) {
      final username = await _authService.getCurrentUsername() ?? '';
      final profile =
          await _schoolService.getSchoolStudentProfile(username);
      if (!mounted) return;
      setState(() {
        _username = username;
        _myProfile = profile;
      });
      await _loadHomework();
      return;
    }

    await _loadClasses();
  }

  Future<void> _loadClasses() async {
    final classes = await _schoolService.getSchoolClasses();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _selectedClass = classes.isNotEmpty ? classes.first : null;
    });
    await _loadHomework();
  }

  /// Class identifiers for filtering, derived from the student's own profile.
  ({
    String? classId,
    String? className,
    String? section,
  }) get _myClassFilter {
    final classId = _myProfile?['class_id']?.toString();
    final className = _myProfile?['class_name']?.toString();
    String? section = _myProfile?['section']?.toString();
    if ((section == null || section.isEmpty) &&
        className != null &&
        className.contains('-')) {
      section = className.substring(className.lastIndexOf('-') + 1);
    }
    return (classId: classId, className: className, section: section);
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> hw;
    if (_isStudent) {
      final f = _myClassFilter;
      hw = await _schoolService.getHomework(
        classId: f.classId,
        className: f.className,
        section: f.section,
      );
      // Real submission records for THIS student from the backend
      final subs = await _schoolService.getHomeworkSubmissions(
          studentUsername: _username);
      _mySubmissions = {
        for (final s in subs)
          if (s['homework_id'] != null) s['homework_id'].toString(): s,
      };
    } else {
      final classId = _selectedClass?['id']?.toString();
      hw = await _schoolService.getHomework(classId: classId);
      // Real submission counts for the whole class (teacher view)
      final ids = hw.map((h) => h['id']?.toString() ?? '').toList();
      _submissionCounts =
          await _schoolService.getHomeworkSubmissionCounts(ids);
    }

    if (!mounted) return;
    setState(() {
      _homework = hw;
      _isLoading = false;
    });
  }

  bool _isPastDue(Map<String, dynamic> hw) {
    final dueDateStr = hw['due_date'] as String?;
    if (dueDateStr == null) return false;
    try {
      final due = DateTime.parse(dueDateStr);
      return due.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  bool _submittedByMe(Map<String, dynamic> hw) =>
      _mySubmissions.containsKey(hw['id']?.toString());

  /// Active homework for the student = everything I have not submitted yet
  /// (overdue ones stay here with a red badge until handled).
  List<Map<String, dynamic>> get _studentActive =>
      _homework.where((h) => !_submittedByMe(h)).toList()
        ..sort((a, b) {
          final aPast = _isPastDue(a) ? 1 : 0;
          final bPast = _isPastDue(b) ? 1 : 0;
          if (aPast != bPast) return aPast - bPast;
          return (a['due_date']?.toString() ?? '')
              .compareTo(b['due_date']?.toString() ?? '');
        });

  /// Past/Submitted for the student = everything I HAVE submitted (real
  /// backend records), plus anything still unsubmitted but past due.
  List<Map<String, dynamic>> get _studentPast {
    final submitted = _homework.where(_submittedByMe).toList();
    final missed = _homework
        .where((h) => !_submittedByMe(h) && _isPastDue(h))
        .toList();
    return [...submitted, ...missed];
  }

  List<Map<String, dynamic>> get _active {
    final now = DateTime.now();
    return _homework.where((h) {
      final status = (h['status'] as String? ?? '').toLowerCase();
      if (status == 'submitted' || status == 'reviewed') return false;
      final dueDateStr = h['due_date'] as String?;
      if (dueDateStr == null) return true;
      try {
        final due = DateTime.parse(dueDateStr);
        return due.isAfter(now.subtract(const Duration(days: 1)));
      } catch (_) {
        return true;
      }
    }).toList();
  }

  List<Map<String, dynamic>> get _past {
    final now = DateTime.now();
    return _homework.where((h) {
      final status = (h['status'] as String? ?? '').toLowerCase();
      if (status == 'submitted' || status == 'reviewed') return true;
      final dueDateStr = h['due_date'] as String?;
      if (dueDateStr == null) return false;
      try {
        final due = DateTime.parse(dueDateStr);
        return due.isBefore(now.subtract(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Future<void> _markSubmitted(Map<String, dynamic> hw) async {
    final id = hw['id']?.toString();
    if (id == null || !_isStudent) return;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Submit Homework',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hw['title']?.toString() ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(hw['subject']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Note to teacher (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Submission'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _schoolService.submitHomework(
      homeworkId: id,
      studentUsername: _username,
      studentId: _myProfile?['id']?.toString(),
      studentName: _myProfile?['name']?.toString(),
      note: noteController.text,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Homework submitted! Your submission is recorded.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadHomework();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not save submission. Database setup missing — run database/school_homework_submissions_setup.sql in Supabase.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Student: show the real backend record of what was submitted.
  void _showMySubmission(Map<String, dynamic> hw) {
    final sub = _mySubmissions[hw['id']?.toString()];
    if (sub == null) return;
    final submittedAt = sub['submitted_at']?.toString() ?? '';
    String dateLabel = submittedAt;
    try {
      final dt = DateTime.parse(submittedAt);
      dateLabel =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.task_alt, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('My Submission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Homework', hw['title']?.toString() ?? '-'),
            _detailRow('Subject', hw['subject']?.toString() ?? '-'),
            _detailRow('Class', hw['class_name']?.toString() ?? '-'),
            _detailRow('Submitted on', dateLabel),
            _detailRow('Status',
                (sub['status']?.toString() ?? 'submitted').toUpperCase()),
            _detailRow('Note', sub['note']?.toString() ?? '—'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF111827))),
          ),
        ],
      ),
    );
  }

  /// Teacher: real backend submission list for a homework item.
  Future<void> _showTeacherSubmissions(Map<String, dynamic> hw) async {
    final id = hw['id']?.toString();
    if (id == null) return;
    final subs = await _schoolService.getHomeworkSubmissions(homeworkId: id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submissions — ${hw['title']?.toString() ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${subs.length} student(s) submitted',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            if (subs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No submissions yet.',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              )
            else
              ...subs.map((s) {
                final name = s['student_name']?.toString() ??
                    s['student_username']?.toString() ??
                    'Student';
                String when = s['submitted_at']?.toString() ?? '';
                try {
                  final dt = DateTime.parse(when);
                  when =
                      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                } catch (_) {}
                final note = s['note']?.toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: note != null && note.isNotEmpty
                      ? Text(note, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Text(when,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _role == 'teacher' || _role == 'steacher' || _role == 'admin' || _role == 'sadmin';

    final active = _isStudent ? _studentActive : _active;
    final past = _isStudent ? _studentPast : _past;

    // Never let the dropdown hold a class that is not in the item list.
    final effectiveSelectedClass = _classes.contains(_selectedClass)
        ? _selectedClass
        : (_classes.isNotEmpty ? _classes.first : null);

    // Header label: student's own class, or the teacher-selected class
    final headerLabel = _isStudent
        ? (_myProfile?['class_name']?.toString() ?? 'Class 10')
        : (_selectedClass?['name']?.toString() ?? _selectedClass?['id']?.toString() ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Homework & Assignments',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              // Students see only their own class — no class chooser.
              if (_canPickClass && _classes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<Map<String, dynamic>>(
                      value: effectiveSelectedClass,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: const Color(0xFF1E40AF),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: _classes.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c['name']?.toString() ?? c['id']?.toString() ?? 'Unknown Class',
                          style: const TextStyle(color: Colors.white),
                        ),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _selectedClass = v);
                        _loadHomework();
                      },
                    ),
                  ),
                )
              else if (_isStudent && headerLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.class_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '$headerLabel · ${_myProfile?['name']?.toString() ?? _username}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF1E40AF),
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  tabs: [
                    Tab(text: 'Active (${active.length})'),
                    Tab(text: _isStudent
                        ? 'Submitted (${past.length})'
                        : 'Completed (${past.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/school/homework/add'),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add),
              label: const Text('Assign Homework', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? _buildLoadingSkeleton()
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadHomework,
                  color: const Color(0xFF3B82F6),
                  child: _buildHomeworkList(active, isTeacher: isTeacher, isPast: false),
                ),
                RefreshIndicator(
                  onRefresh: _loadHomework,
                  color: const Color(0xFF3B82F6),
                  child: _buildHomeworkList(past, isTeacher: isTeacher, isPast: true),
                ),
              ],
            ),
    );
  }

  Widget _buildHomeworkList(
    List<Map<String, dynamic>> items, {
    required bool isTeacher,
    bool isPast = false,
  }) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPast ? Icons.assignment_turned_in_outlined : Icons.assignment_outlined,
                  size: 72,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  isPast ? ( _isStudent ? 'Nothing submitted yet' : 'No past homework') : 'No active homework!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPast
                      ? (_isStudent
                          ? 'Your submitted homework will appear here.'
                          : 'Submitted and past-due homework appear here.')
                      : 'All caught up 🎉',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildHomeworkCard(items[index], isTeacher: isTeacher, isPast: isPast),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw,
      {required bool isTeacher, required bool isPast}) {
    final subject = hw['subject'] as String? ?? 'Subject';
    final title = hw['title'] as String? ?? 'Homework';
    final description = hw['description'] as String? ?? '';
    final className = hw['class_name'] as String? ?? hw['class_id']?.toString() ?? '';
    final teacherName = hw['teacher_name'] as String? ?? hw['teacher_username'] as String? ?? '';
    final dueDateStr = hw['due_date'] as String? ?? '';

    final subjectColor = _colorForSubject(subject);
    // Student: submitted state comes from the real backend submission record.
    final mySubmission = _isStudent ? _mySubmissions[hw['id']?.toString()] : null;
    final isSubmitted = _isStudent ? mySubmission != null : false;
    final missed = _isStudent && !isSubmitted && _isPastDue(hw);
    // Teacher: real submission count from backend.
    final submissionCount = _isStudent
        ? 0
        : (_submissionCounts[hw['id']?.toString()] ?? 0);

    // Days remaining calculation
    String daysLabel = '';
    Color daysColor = const Color(0xFFEF4444);
    if (!isSubmitted && dueDateStr.isNotEmpty) {
      try {
        final due = DateTime.parse(dueDateStr);
        final diff = due.difference(DateTime.now()).inDays;
        if (diff < 0) {
          daysLabel = '${(-diff)}d overdue';
          daysColor = const Color(0xFFEF4444);
        } else if (diff == 0) {
          daysLabel = 'Due today';
          daysColor = const Color(0xFFF59E0B);
        } else {
          daysLabel = '$diff day${diff == 1 ? '' : 's'} left';
          daysColor = diff <= 2 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
        }
      } catch (_) {
        daysLabel = 'Due: $dueDateStr';
      }
    }

    // For submitted items show the backend submission date instead.
    if (mySubmission != null) {
      try {
        final dt = DateTime.parse(
            (mySubmission['submitted_at'] as String?)?.toString() ?? '');
        daysLabel = 'Submitted ${dt.day}/${dt.month}/${dt.year}';
        daysColor = const Color(0xFF10B981);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isSubmitted ? () => _showMySubmission(hw) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with subject colour
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: subjectColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: subjectColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.book_outlined, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: subjectColor,
                    ),
                  ),
                  const Spacer(),
                  // Teacher: real submission count badge from backend
                  if (isTeacher && submissionCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$submissionCount submitted',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isSubmitted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✓ Submitted',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (missed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Missed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (className.isNotEmpty) ...[
                        Icon(Icons.class_outlined, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(className, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 12),
                      ],
                      if (teacherName.isNotEmpty) ...[
                        Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            teacherName,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (daysLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: daysColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isSubmitted ? Icons.check_circle : Icons.calendar_today,
                                  size: 12, color: daysColor),
                              const SizedBox(width: 4),
                              Text(
                                daysLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: daysColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Action buttons
                  const SizedBox(height: 12),
                  if (isTeacher)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showTeacherSubmissions(hw),
                        icon: const Icon(Icons.people_outline, size: 16),
                        label: Text(
                          submissionCount > 0
                              ? 'View Submissions ($submissionCount)'
                              : 'View Submissions',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    )
                  else if (!isSubmitted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _markSubmitted(hw),
                        icon: const Icon(Icons.upload_outlined, size: 16, color: Colors.white),
                        label: const Text(
                          'Mark as Submitted',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    )
                  else if (isPast)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showMySubmission(hw),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View My Submission'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
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

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
