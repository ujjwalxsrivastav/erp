import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For ImageFilter
import '../../services/auth_service.dart';
import '../hod/manage_classes_screen.dart';

class HODDashboard extends StatefulWidget {
  const HODDashboard({super.key});

  @override
  State<HODDashboard> createState() => _HODDashboardState();
}

class _HODDashboardState extends State<HODDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  late AnimationController _entranceController;

  int _totalFaculty = 0;
  int _totalStudents = 0;
  int _activeCourses = 0;
  double _departmentAttendance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadDashboardData();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Simulate network delay for smooth animation
      await Future.delayed(const Duration(milliseconds: 800));

      final facultyData = await _supabase.from('teacher_details').select();
      final studentsData = await _supabase.from('student_details').select();
      final coursesData = await _supabase.from('subjects').select();

      if (mounted) {
        setState(() {
          _totalFaculty = facultyData.length;
          _totalStudents = studentsData.length;
          _activeCourses = coursesData.length;
          _departmentAttendance = 87.5; // Mock data
          _isLoading = false;
        });
        _entranceController.forward();
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0F172A),
                strokeWidth: 3,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _buildSectionHeader('ANALYTICS', 0),
                        const SizedBox(height: 16),
                        _buildStatsGrid(),
                        const SizedBox(height: 40),
                        _buildSectionHeader('QUICK ACCESS', 200),
                        const SizedBox(height: 16),
                        _buildHeroActionCard(),
                        const SizedBox(height: 40),
                        _buildSectionHeader('MANAGEMENT', 400),
                        const SizedBox(height: 16),
                        _buildManagementGrid(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A), // Slate-900
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Gradient Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A), // Slate-900
                    Color(0xFF1E293B), // Slate-800
                  ],
                ),
              ),
            ),
            // Decorative Elements (Nano Banana Style)
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF38BDF8).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Glass Badge
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.verified,
                                      color: Color(0xFF38BDF8), size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'HOD Portal',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Logout Button
                        IconButton(
                          onPressed: () async {
                            await _authService.logout();
                            if (mounted) context.go('/login');
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.power_settings_new,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overview & Controls',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8), // Slate-400
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int delay) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: Interval(
          (delay / 1500).clamp(0.0, 1.0),
          ((delay + 400) / 1500).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B), // Slate-500
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return SizedBox(
      height: 320,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildStatCard(
                    'Total Students',
                    '$_totalStudents',
                    Icons.groups_outlined,
                    const Color(0xFF6366F1), // Indigo
                    const Color(0xFFEEF2FF),
                    0,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  flex: 2,
                  child: _buildStatCard(
                    'Faculty',
                    '$_totalFaculty',
                    Icons.person_outline,
                    const Color(0xFF0EA5E9), // Sky
                    const Color(0xFFF0F9FF),
                    100,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildStatCard(
                    'Courses',
                    '$_activeCourses',
                    Icons.book_outlined,
                    const Color(0xFF10B981), // Emerald
                    const Color(0xFFECFDF5),
                    200,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  flex: 3,
                  child: _buildStatCard(
                    'Avg Attendance',
                    '${_departmentAttendance.toInt()}%',
                    Icons.trending_up,
                    const Color(0xFFF59E0B), // Amber
                    const Color(0xFFFFFBEB),
                    300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color bgColor,
    int delay,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entranceController,
        curve: Interval(
          (delay / 1500).clamp(0.0, 1.0),
          ((delay + 600) / 1500).clamp(0.0, 1.0),
          curve: Curves.easeOutBack,
        ),
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceController,
          curve: Interval(
            (delay / 1500).clamp(0.0, 1.0),
            ((delay + 400) / 1500).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroActionCard() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutBack),
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageClassesScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(32),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2563EB), // Blue-600
                    Color(0xFF4F46E5), // Indigo-600
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative background icon
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.calendar_month,
                      size: 140,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'PRIMARY ACTION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Manage Classes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFF4F46E5),
                            size: 24,
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
      ),
    );
  }

  Widget _buildManagementGrid() {
    final tools = [
      {
        'icon': Icons.assignment_ind_outlined,
        'label': 'Faculty',
        'color': Colors.orange
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Reports',
        'color': Colors.purple
      },
      {
        'icon': Icons.notifications_none_outlined,
        'label': 'Notices',
        'color': Colors.pink
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'color': Colors.grey
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        final delay = 400 + (index * 100);

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _entranceController,
            curve: Interval(
              (delay / 1500).clamp(0.0, 1.0),
              ((delay + 600) / 1500).clamp(0.0, 1.0),
              curve: Curves.easeOutBack,
            ),
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _entranceController,
              curve: Interval(
                (delay / 1500).clamp(0.0, 1.0),
                ((delay + 400) / 1500).clamp(0.0, 1.0),
                curve: Curves.easeOut,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${tool['label']} - Coming Soon'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF64748B).withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (tool['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tool['icon'] as IconData,
                          color: tool['color'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tool['label'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
