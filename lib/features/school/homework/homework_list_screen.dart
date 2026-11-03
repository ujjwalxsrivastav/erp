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

  Future<void> _init() async {
    final role = await _authService.getCurrentUserRole();
    if (!mounted) return;
    setState(() => _role = role);
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

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    final classId = _selectedClass?['id']?.toString();
    final hw = await _schoolService.getHomework(classId: classId);
    if (!mounted) return;
    setState(() {
      _homework = hw;
      _isLoading = false;
    });
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
    if (id == null) return;
    final ok = await _schoolService.updateHomeworkStatus(id, 'submitted');
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as submitted!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadHomework();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status. Try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markReviewed(Map<String, dynamic> hw) async {
    final id = hw['id']?.toString();
    if (id == null) return;
    final ok = await _schoolService.updateHomeworkStatus(id, 'reviewed');
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Homework marked as reviewed!'),
          backgroundColor: Color(0xFF8B5CF6),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadHomework();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _role == 'teacher';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Homework', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Class selector dropdown
              if (_classes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedClass,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: const Color(0xFF2563EB),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: _classes.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c['name']?.toString() ?? c['id']?.toString() ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _selectedClass = v);
                        _loadHomework();
                      },
                    ),
                  ),
                ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'Active (${_active.length})'),
                  Tab(text: 'Past/Submitted (${_past.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/school/homework/upload'),
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadHomework,
                  color: const Color(0xFF3B82F6),
                  child: _buildHomeworkList(_active, isTeacher: isTeacher),
                ),
                RefreshIndicator(
                  onRefresh: _loadHomework,
                  color: const Color(0xFF3B82F6),
                  child: _buildHomeworkList(_past, isTeacher: isTeacher, isPast: true),
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
                  isPast ? 'No past homework' : 'No active homework!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPast ? 'Submitted and past-due homework appear here.' : 'All caught up 🎉',
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
          _buildHomeworkCard(items[index], isTeacher: isTeacher),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw, {required bool isTeacher}) {
    final subject = hw['subject'] as String? ?? 'Subject';
    final title = hw['title'] as String? ?? 'Homework';
    final description = hw['description'] as String? ?? '';
    final className = hw['class_name'] as String? ?? hw['class_id']?.toString() ?? '';
    final teacherName = hw['teacher_name'] as String? ?? hw['teacher'] as String? ?? '';
    final dueDateStr = hw['due_date'] as String? ?? '';
    final status = (hw['status'] as String? ?? 'pending').toLowerCase();
    final submissionCount = hw['submission_count'] as int? ?? 0;

    final subjectColor = _colorForSubject(subject);
    final isSubmitted = status == 'submitted' || status == 'reviewed';

    // Days remaining calculation
    String daysLabel = '';
    Color daysColor = const Color(0xFFEF4444);
    if (dueDateStr.isNotEmpty) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with subject colour
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: subjectColor.withOpacity(0.08),
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
                // Teacher: submission count badge
                if (isTeacher && submissionCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
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
                    child: Text(
                      status == 'reviewed' ? '✓ Reviewed' : '✓ Submitted',
                      style: const TextStyle(
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
                          color: daysColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: daysColor),
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
                if (!isSubmitted) ...[
                  if (isTeacher)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _markReviewed(hw),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Mark Reviewed'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    )
                  else
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
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
