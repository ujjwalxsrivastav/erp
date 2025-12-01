// Admin Dashboard - Main Screen
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/complete_admin_service.dart';
import '../../services/session_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _adminService = AdminService();
  final _sessionService = SessionService();

  Map<String, dynamic>? _overview;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final overview = await _adminService.getSystemOverview();
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(),
                      SliverPadding(
                        padding: const EdgeInsets.all(AppTheme.md),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildWelcomeCard(),
                            const SizedBox(height: AppTheme.md),
                            _buildSystemStats(),
                            const SizedBox(height: AppTheme.md),
                            _buildQuickActions(),
                            const SizedBox(height: AppTheme.md),
                            _buildManagementSections(),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.adminGradient,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Portal',
                  style: AppTheme.h3.copyWith(color: AppTheme.white),
                ),
                const SizedBox(height: AppTheme.xs),
                Text(
                  'System Administration',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppTheme.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: AppTheme.white),
          onPressed: () async {
            await _sessionService.clearSession();
            if (mounted) context.go('/login');
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return GlassCard(
      gradient: AppTheme.adminGradient,
      elevated: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: AppTheme.white,
              size: 35,
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Administrator',
                  style: AppTheme.h4.copyWith(color: AppTheme.white),
                ),
                const SizedBox(height: AppTheme.xs),
                Text(
                  'Manage your institution efficiently',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Students',
                '${_overview?['total_students'] ?? 0}',
                Icons.school_outlined,
                AppTheme.studentPrimary,
                '${_overview?['active_students'] ?? 0} active',
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: _buildStatCard(
                'Staff',
                '${_overview?['total_staff'] ?? 0}',
                Icons.people_outline,
                AppTheme.teacherPrimary,
                'All departments',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Courses',
                '${_overview?['total_courses'] ?? 0}',
                Icons.book_outlined,
                AppTheme.accentTeal,
                'Active courses',
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: _buildStatCard(
                'Departments',
                '${_overview?['total_departments'] ?? 0}',
                Icons.business_outlined,
                AppTheme.accentOrange,
                'All departments',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return GlassCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.sm),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                value,
                style: AppTheme.h3.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.dark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'title': 'Students',
        'icon': Icons.school,
        'route': '/admin/students',
        'color': AppTheme.studentPrimary
      },
      {
        'title': 'Staff',
        'icon': Icons.people,
        'route': '/admin/staff',
        'color': AppTheme.teacherPrimary
      },
      {
        'title': 'Courses',
        'icon': Icons.book,
        'route': '/admin/courses',
        'color': AppTheme.accentTeal
      },
      {
        'title': 'Exams',
        'icon': Icons.quiz,
        'route': '/admin/exams',
        'color': AppTheme.accentOrange
      },
      {
        'title': 'Library',
        'icon': Icons.library_books,
        'route': '/admin/library',
        'color': AppTheme.accentPink
      },
      {
        'title': 'Hostel',
        'icon': Icons.hotel,
        'route': '/admin/hostel',
        'color': AppTheme.adminPrimary
      },
      {
        'title': 'Transport',
        'icon': Icons.directions_bus,
        'route': '/admin/transport',
        'color': AppTheme.success
      },
      {
        'title': 'Fees',
        'icon': Icons.payment,
        'route': '/admin/fees',
        'color': AppTheme.warning
      },
      {
        'title': 'Reports',
        'icon': Icons.assessment,
        'route': '/admin/reports',
        'color': AppTheme.info
      },
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Management',
            style: AppTheme.h5.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: AppTheme.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppTheme.sm,
              mainAxisSpacing: AppTheme.sm,
              childAspectRatio: 1,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _buildActionButton(
                action['title'] as String,
                action['icon'] as IconData,
                action['route'] as String,
                action['color'] as Color,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, String route, Color color) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.extraLightGray),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.sm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppTheme.xs),
            Text(
              title,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.dark,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSections() {
    final pendingFees = _overview?['pending_fees'] ?? 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warning, size: 20),
              const SizedBox(width: AppTheme.sm),
              Text(
                'Attention Required',
                style: AppTheme.h5.copyWith(color: AppTheme.dark),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          _buildAttentionItem(
            'Pending Fees',
            '₹${pendingFees.toStringAsFixed(2)}',
            Icons.payment,
            AppTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionItem(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
                const SizedBox(height: AppTheme.xs),
                Text(
                  value,
                  style: AppTheme.h4.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: color),
        ],
      ),
    );
  }
}
