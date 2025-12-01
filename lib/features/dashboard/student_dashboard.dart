import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../services/fees_service.dart';
import '../fees/student_fees_screen.dart';
import '../notices/notices_screen.dart';
import '../student/student_marks_screen.dart';
import '../student/student_subjects_screen.dart';
import '../student/student_timetable.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final StudentService _studentService = StudentService();
  final FeesService _feesService = FeesService();
  late AnimationController _fadeController;
  late AnimationController _slideController;

  Map<String, dynamic>? _studentData;
  String _studentName = 'Loading...';
  String _studentInfo = '';
  List<Map<String, dynamic>> _marks = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _upcomingClasses = [];
  bool _loadingClasses = true;
  double _attendancePercentage = 0.0;
  double _gpa = 0.0;
  double _pendingFees = 0.0;
  bool _feesLoading = true;
  List<Map<String, dynamic>> _subjectPerformance = [];
  Map<String, List<Map<String, dynamic>>> _examWisePerformance = {
    'End Semester': [],
    'Mid Term': [],
  };
  int _currentExamPage = 0; // 0 = End Semester, 1 = Mid Term

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
  }

  Future<void> _loadStudentData() async {
    try {
      final username = await _authService.getCurrentUsername();
      if (username != null) {
        final data = await _studentService.getStudentDetails(username);
        final marks = await _studentService.getStudentMarks(username);
        final assignments =
            await _studentService.getStudentAssignments(username);
        final timetable = await _studentService.getTimetable(username);

        // Fetch fees
        Map<String, dynamic> feesData = {};
        try {
          feesData = await _feesService.getStudentFees(username, '2024-25');
        } catch (e) {
          print('Error fetching fees: $e');
        }

        // Filter for today and upcoming times
        final now = DateTime.now();
        final dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        final today = dayNames[now.weekday - 1];

        final todayClasses =
            timetable.where((c) => c['day_of_week'] == today).toList();

        final upcoming = todayClasses.where((c) {
          try {
            final endTimeParts = c['end_time'].toString().split(':');
            final endMinutes =
                int.parse(endTimeParts[0]) * 60 + int.parse(endTimeParts[1]);
            final nowMinutes = now.hour * 60 + now.minute;
            return endMinutes > nowMinutes;
          } catch (e) {
            return false;
          }
        }).toList();

        if (mounted) {
          setState(() {
            if (data != null) {
              _studentData = data;
              _studentName = data['name'] ?? 'Student';
              _studentInfo =
                  '${data['student_id']} • CSE Year ${data['year']} Sem ${data['semester']}';
            }
            _marks = marks;
            _assignments = assignments;
            _upcomingClasses = upcoming;
            _loadingClasses = false;

            // Update Fees
            if (feesData.isNotEmpty) {
              _pendingFees =
                  (feesData['pending_amount'] as num?)?.toDouble() ?? 0.0;
              _feesLoading = false;
            }

            // Calculate GPA from marks
            if (marks.isNotEmpty) {
              double totalPercentage = 0.0;
              int count = 0;

              for (var mark in marks) {
                if (mark['percentage'] != null) {
                  totalPercentage += (mark['percentage'] as num).toDouble();
                  count++;
                }
              }

              if (count > 0) {
                final avgPercentage = totalPercentage / count;
                // Convert percentage to GPA (10 point scale)
                _gpa = (avgPercentage / 10.0);
              }

              // Calculate subject-wise performance
              Map<String, List<double>> subjectMarks = {};
              Map<String, String> subjectNames = {};

              for (var mark in marks) {
                final subjectId = mark['subject_id'];
                final percentage = mark['percentage'];
                final subjectName = mark['subjects']?['subject_name'];

                if (subjectId != null &&
                    percentage != null &&
                    subjectName != null) {
                  if (!subjectMarks.containsKey(subjectId)) {
                    subjectMarks[subjectId] = [];
                    subjectNames[subjectId] = subjectName;
                  }
                  subjectMarks[subjectId]!.add((percentage as num).toDouble());
                }
              }

              // Calculate average for each subject
              _subjectPerformance = subjectMarks.entries.map((entry) {
                final subjectId = entry.key;
                final percentages = entry.value;
                final avgPercentage =
                    percentages.reduce((a, b) => a + b) / percentages.length;

                return {
                  'subject_id': subjectId,
                  'subject_name': subjectNames[subjectId],
                  'percentage': avgPercentage,
                };
              }).toList();

              // Sort by percentage (highest first)
              _subjectPerformance.sort((a, b) => (b['percentage'] as double)
                  .compareTo(a['percentage'] as double));

              // Calculate exam-wise subject performance (End Semester and Mid Term separately)
              Map<String, Map<String, List<double>>> examSubjectMarks = {
                'End Semester': {},
                'Mid Term': {},
              };
              Map<String, Map<String, String>> examSubjectNames = {
                'End Semester': {},
                'Mid Term': {},
              };

              for (var mark in marks) {
                final subjectId = mark['subject_id'];
                final percentage = mark['percentage'];
                final subjectName = mark['subjects']?['subject_name'];
                final examType =
                    mark['exam_type']; // 'End Semester' or 'Mid Term'

                if (subjectId != null &&
                    percentage != null &&
                    subjectName != null &&
                    examType != null &&
                    (examType == 'End Semester' || examType == 'Mid Term')) {
                  if (!examSubjectMarks[examType]!.containsKey(subjectId)) {
                    examSubjectMarks[examType]![subjectId] = [];
                    examSubjectNames[examType]![subjectId] = subjectName;
                  }
                  examSubjectMarks[examType]![subjectId]!
                      .add((percentage as num).toDouble());
                }
              }

              // Calculate average for each subject in each exam type
              for (var examType in ['End Semester', 'Mid Term']) {
                _examWisePerformance[examType] =
                    examSubjectMarks[examType]!.entries.map((entry) {
                  final subjectId = entry.key;
                  final percentages = entry.value;
                  final avgPercentage =
                      percentages.reduce((a, b) => a + b) / percentages.length;

                  return {
                    'subject_id': subjectId,
                    'subject_name': examSubjectNames[examType]![subjectId],
                    'percentage': avgPercentage,
                  };
                }).toList();

                // Sort by percentage (highest first)
                _examWisePerformance[examType]!.sort((a, b) =>
                    (b['percentage'] as double)
                        .compareTo(a['percentage'] as double));
              }
            }

            // Set attendance (placeholder - you can fetch real attendance later)
            _attendancePercentage = 85.0; // TODO: Fetch from attendance table
          });
        }
      } else {
        if (mounted) setState(() => _loadingClasses = false);
      }
    } catch (e) {
      print('Error loading student data: $e');
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show exit confirmation dialog
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        drawer: _buildSidebar(context),
        body: CustomScrollView(
          slivers: [
            // ---------- PREMIUM APP BAR ----------
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF1E3A8A),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E3A8A),
                        const Color(0xFF3B82F6),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Animated background pattern
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -30,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),
                      // Profile section
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FadeTransition(
                              opacity: _fadeController,
                              child: Row(
                                children: [
                                  // Clickable Profile Photo
                                  GestureDetector(
                                    onTap: () => context.go('/student-profile'),
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.cyan.shade300,
                                            Colors.blue.shade400,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _studentName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _studentInfo,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // View Profile Icon Button
                                  IconButton(
                                    onPressed: () =>
                                        context.go('/student-profile'),
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    tooltip: 'View Profile',
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
            ),
            // ---------- MAIN CONTENT ----------
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ---------- ID CARD BUTTON (PREMIUM) ----------
                  GestureDetector(
                    onTap: () {
                      if (_studentData != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                _IDCardScreen(studentData: _studentData!),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF8B5CF6),
                            const Color(0xFFA78BFA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.badge,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Student ID Card',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'View your digital identity card',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- PREMIUM STATS CARDS ----------
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_slideController),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _PremiumStatCard(
                              title: "Attendance",
                              value:
                                  "${_attendancePercentage.toStringAsFixed(1)}%",
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF10B981),
                              bgColor: const Color(0xFFECFDF5),
                              onTap: () {},
                            ),
                            _PremiumStatCard(
                              title: "Timetable",
                              value: "View",
                              icon: Icons.calendar_today_outlined,
                              color: const Color(0xFFF59E0B),
                              bgColor: const Color(0xFFFEF3C7),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const StudentTimetable(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _PremiumStatCard(
                              title: "Fees Status",
                              value: _feesLoading
                                  ? "..."
                                  : "₹${_pendingFees.toStringAsFixed(0)}",
                              icon: Icons.account_balance_wallet_outlined,
                              color: const Color(0xFFEF4444),
                              bgColor: const Color(0xFFFEE2E2),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const StudentFeesScreen(),
                                  ),
                                );
                              },
                            ),
                            _PremiumStatCard(
                              title: "Notices",
                              value: "3",
                              icon: Icons.notifications_outlined,
                              color: const Color(0xFF8B5CF6),
                              bgColor: const Color(0xFFF3E8FF),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NoticesScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---------- QUICK ACTIONS ----------
                  const Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 8),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    padding: EdgeInsets.zero,
                    children: [
                      const _QuickActionCard(
                        icon: Icons.checklist_rtl,
                        label: "Attendance",
                        color: Color(0xFF10B981),
                      ),
                      _QuickActionCard(
                        icon: Icons.book_outlined,
                        label: "Marks",
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StudentMarksScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.schedule_outlined,
                        label: "Timetable",
                        color: const Color(0xFFF59E0B),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StudentTimetable(),
                            ),
                          );
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.payment_outlined,
                        label: "Fees",
                        color: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StudentFeesScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.subject_outlined,
                        label: "Subjects",
                        color: const Color(0xFF8B5CF6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const StudentSubjectsScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickActionCard(
                        icon: Icons.person_outline,
                        label: "Profile",
                        color: const Color(0xFF06B6D4),
                        onTap: () {
                          print('🔘 Profile button clicked!');
                          context.go('/student-profile');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ---------- RECENT MARKS ----------
                  if (_marks.isNotEmpty) ...[
                    const Text(
                      'Recent Marks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._marks.take(3).map((mark) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF3B82F6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.grade,
                                    color: Color(0xFF3B82F6)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mark['subjects']['subject_name'] ??
                                          'Subject',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      mark['exam_type'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${mark['marks_obtained']}/${mark['total_marks']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                  Text(
                                    'Marks',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // ---------- ASSIGNMENTS ----------
                  if (_assignments.isNotEmpty) ...[
                    const Text(
                      'Assignments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._assignments.take(3).map((assignment) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.assignment,
                                    color: Color(0xFFF59E0B)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      assignment['title'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      assignment['due_date'] != null
                                          ? 'Due: ${DateTime.parse(assignment['due_date']).toString().split(' ')[0]}'
                                          : 'No Due Date',
                                      style: TextStyle(
                                        color: Colors.red[400],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (assignment['file_url'] != null)
                                IconButton(
                                  icon: const Icon(Icons.download_rounded,
                                      color: Color(0xFF059669)),
                                  onPressed: () {
                                    // Handle download
                                  },
                                ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // ---------- ACADEMIC PERFORMANCE ----------
                  const Text(
                    "Academic Performance",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with pagination
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Semester Marks",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Page indicator
                            Row(
                              children: [
                                Text(
                                  _currentExamPage == 0
                                      ? 'End Sem'
                                      : 'Mid Term',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Page ${_currentExamPage + 1}/2',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Dynamic exam-wise subject performance
                        Builder(
                          builder: (context) {
                            final examType = _currentExamPage == 0
                                ? 'End Semester'
                                : 'Mid Term';
                            final subjects =
                                _examWisePerformance[examType] ?? [];

                            if (subjects.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text(
                                    'No marks available yet',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: subjects.asMap().entries.map((entry) {
                                final index = entry.key;
                                final subject = entry.value;
                                final colors = [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF10B981),
                                  const Color(0xFFF59E0B),
                                  const Color(0xFF8B5CF6),
                                  const Color(0xFFEF4444),
                                  const Color(0xFF06B6D4),
                                ];

                                return Column(
                                  children: [
                                    if (index > 0) const SizedBox(height: 12),
                                    _buildProgressBar(
                                      subject['subject_name'] ?? 'Unknown',
                                      (subject['percentage'] as double).round(),
                                      colors[index % colors.length],
                                    ),
                                  ],
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Page navigation buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Previous button
                            InkWell(
                              onTap: _currentExamPage > 0
                                  ? () {
                                      setState(() {
                                        _currentExamPage--;
                                      });
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentExamPage > 0
                                      ? const Color(0xFF3B82F6)
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_back_ios,
                                      size: 14,
                                      color: _currentExamPage > 0
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Previous',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _currentExamPage > 0
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Next button
                            InkWell(
                              onTap: _currentExamPage < 1
                                  ? () {
                                      setState(() {
                                        _currentExamPage++;
                                      });
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentExamPage < 1
                                      ? const Color(0xFF3B82F6)
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _currentExamPage < 1
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: _currentExamPage < 1
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---------- STUDY MATERIALS ----------
                  const Text(
                    "Study Materials",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _buildStudyMaterialCard(
                    "Data Structures",
                    "5 files • 2.3 MB",
                    Icons.folder_open,
                    const Color(0xFF3B82F6),
                  ),

                  const SizedBox(height: 10),

                  _buildStudyMaterialCard(
                    "Web Development",
                    "12 files • 5.1 MB",
                    Icons.folder_open,
                    const Color(0xFF10B981),
                  ),

                  const SizedBox(height: 28),

                  // ---------- ANNOUNCEMENTS ----------
                  const Text(
                    "Important Announcements",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _buildAnnouncementCard(
                    "📚 Mid-Semester Exams",
                    "Mid-sem exams start from 12 Nov. Please check the exam schedule.",
                    const Color(0xFF3B82F6),
                  ),

                  const SizedBox(height: 10),

                  _buildAnnouncementCard(
                    "💰 Fee Submission Extended",
                    "Fees last date has been extended to 5 December 2024.",
                    const Color(0xFFF59E0B),
                  ),

                  const SizedBox(height: 10),

                  _buildAnnouncementCard(
                    "🎉 Freshers Orientation",
                    "Freshers orientation will be held on Monday at 10 AM.",
                    const Color(0xFF10B981),
                  ),

                  const SizedBox(height: 28),

                  // ---------- UPCOMING CLASSES ----------
                  const Text(
                    "Upcoming Classes",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_loadingClasses)
                    const Center(child: CircularProgressIndicator())
                  else if (_upcomingClasses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.weekend,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            "No upcoming classes today!",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._upcomingClasses.map((classData) {
                      final subject =
                          classData['subjects']?['subject_name'] ?? 'Subject';
                      final teacher =
                          classData['teacher_details']?['name'] ?? 'Teacher';
                      final room = classData['room_number'] ?? 'Room TBD';
                      final time =
                          '${classData['start_time']} - ${classData['end_time']}';
                      final color = _upcomingClasses.indexOf(classData) % 2 == 0
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF10B981);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildClassCard(
                          subject,
                          teacher,
                          room,
                          time,
                          color,
                        ),
                      );
                    }),

                  const SizedBox(height: 28),

                  // ---------- LIBRARY RESOURCES ----------
                  const Text(
                    "Library Resources",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _buildLibraryCard(
                    "📖 Reference Books",
                    "45 books available",
                    const Color(0xFF8B5CF6),
                  ),

                  const SizedBox(height: 10),

                  _buildLibraryCard(
                    "📰 Journals & Papers",
                    "120 research papers",
                    const Color(0xFF06B6D4),
                  ),

                  const SizedBox(height: 28),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // WillPopScope
  }

  Widget _buildLibraryCard(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.library_books, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildNavButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF1E3A8A),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _studentName.isNotEmpty
                          ? _studentName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _studentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _studentData?['student_id'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _buildSidebarItem(
                    Icons.dashboard,
                    "Dashboard",
                    Colors.cyan,
                    () => Navigator.pop(context),
                  ),
                  _buildSidebarItem(
                    Icons.book,
                    "Subjects",
                    Colors.blue,
                    () {
                      Navigator.pop(context);
                      context.push('/student/subjects');
                    },
                  ),
                  _buildSidebarItem(
                    Icons.calendar_today,
                    "Exam Schedule",
                    Colors.purple,
                    () {
                      Navigator.pop(context);
                      context.push('/student/exam-schedule');
                    },
                  ),
                  _buildSidebarItem(
                    Icons.library_books,
                    "Library",
                    Colors.green,
                    () {
                      Navigator.pop(context);
                      context.push('/student/library');
                    },
                  ),
                  _buildSidebarItem(
                    Icons.groups,
                    "Clubs & Activities",
                    Colors.orange,
                    () {
                      Navigator.pop(context);
                      context.push('/student/clubs');
                    },
                  ),
                  _buildSidebarItem(
                    Icons.notifications,
                    "Notice",
                    Colors.red,
                    () {
                      Navigator.pop(context);
                      context.push('/student/notice');
                    },
                  ),
                  _buildSidebarItem(
                    Icons.settings,
                    "Settings",
                    Colors.grey,
                    () {
                      Navigator.pop(context);
                      context.push('/student/settings');
                    },
                  ),
                ],
              ),
            ),
            // Logout button at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _authService.logout();
                    if (!mounted) return;
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color, size: 24),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.white30,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStudyMaterialCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.download, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildExamResultCard(
    String examName,
    String score,
    String grade,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assessment, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  grade,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            score,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
            Text(
              "$percentage%",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(String title, String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    String subject,
    String instructor,
    String room,
    String time,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.class_, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      instructor,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      room,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

// ---------- PREMIUM STAT CARD ----------
class _PremiumStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _PremiumStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- QUICK ACTION CARD ----------
class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.95).animate(_controller),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- ID CARD SCREEN ----------
class _IDCardScreen extends StatelessWidget {
  final Map<String, dynamic> studentData;

  const _IDCardScreen({required this.studentData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Student ID Card'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 350,
            height: 550,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: const [
                      Text(
                        'SHIVALIK COLLEGE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'STUDENT IDENTITY CARD',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Photo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: ClipOval(
                    child: studentData['profile_photo_url'] != null
                        ? Image.network(
                            studentData['profile_photo_url'],
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.white,
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      _buildIDField('Name', studentData['name']),
                      _buildIDField(
                        'Father\'s Name',
                        studentData['father_name'],
                      ),
                      _buildIDField('Student ID', studentData['student_id']),
                      _buildIDField('Department', studentData['department']),
                      _buildIDField(
                        'Year & Semester',
                        'Year ${studentData['year']} - Sem ${studentData['semester']}',
                      ),
                      _buildIDField('Section', studentData['section']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIDField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
