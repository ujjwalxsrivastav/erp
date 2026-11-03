import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/examination_service.dart';

/// COE (Controller of Examinations) dashboard.
/// Shows live counts from the examination tables and a menu grid
/// into sessions, results, tabulation and revaluation.
class COEDashboard extends StatefulWidget {
  const COEDashboard({super.key});

  @override
  State<COEDashboard> createState() => _COEDashboardState();
}

class _COEDashboardState extends State<COEDashboard> {
  final _service = ExaminationService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentSessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final stats = await _service.getDashboardStats();
    final sessions = await _service.getSessions();
    if (mounted) {
      setState(() {
        _stats = stats;
        _recentSessions = sessions.take(5).toList();
        _isLoading = false;
      });
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
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.adminPrimary))
              : RefreshIndicator(
                  color: AppTheme.adminPrimary,
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverPadding(
                        padding: const EdgeInsets.all(24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildStatsGrid(),
                            const SizedBox(height: 28),
                            Text('Examination Office',
                                style: AppTheme.h4
                                    .copyWith(color: AppTheme.dark)),
                            const SizedBox(height: 16),
                            _buildMenuGrid(),
                            const SizedBox(height: 28),
                            Text('Recent Sessions',
                                style: AppTheme.h4
                                    .copyWith(color: AppTheme.dark)),
                            const SizedBox(height: 16),
                            _buildRecentSessions(),
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

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.adminGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _load,
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fact_check,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Examination Cell',
                        style: AppTheme.h2.copyWith(color: Colors.white)),
                    Text(
                      'Controller of Examinations (COE)',
                      style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {
        'label': 'Exam Sessions',
        'value': '${_stats['totalSessions'] ?? 0}',
        'icon': Icons.event_note,
        'color': AppTheme.adminPrimary,
      },
      {
        'label': 'Registrations',
        'value': '${_stats['totalRegistrations'] ?? 0}',
        'icon': Icons.app_registration,
        'color': AppTheme.accentTeal,
      },
      {
        'label': 'Hall Tickets',
        'value': '${_stats['hallTicketsIssued'] ?? 0}',
        'icon': Icons.badge,
        'color': AppTheme.studentPrimary,
      },
      {
        'label': 'Results Declared',
        'value': '${_stats['resultsDeclared'] ?? 0}',
        'icon': Icons.emoji_events,
        'color': AppTheme.success,
      },
      {
        'label': 'Results Entered',
        'value': '${_stats['totalResults'] ?? 0}',
        'icon': Icons.grading,
        'color': AppTheme.accentOrange,
      },
      {
        'label': 'Revaluation Pending',
        'value': '${_stats['pendingRevaluations'] ?? 0}',
        'icon': Icons.rate_review,
        'color': AppTheme.accentPink,
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.45,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) {
        final s = stats[i];
        final color = s['color'] as Color;
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(s['icon'] as IconData, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(s['value'] as String,
                  style: AppTheme.h3.copyWith(color: AppTheme.dark)),
              Text(s['label'] as String,
                  style: AppTheme.caption
                      .copyWith(color: AppTheme.mediumGray)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid() {
    final menu = [
      {
        'label': 'Exam Sessions',
        'sub': 'Create & publish sessions',
        'icon': Icons.event_note,
        'color': AppTheme.adminPrimary,
        'route': '/examination/sessions',
      },
      {
        'label': 'Result Management',
        'sub': 'Enter & publish results',
        'icon': Icons.grading,
        'color': AppTheme.success,
        'route': '/examination/results',
      },
      {
        'label': 'Revaluation',
        'sub': 'Review student requests',
        'icon': Icons.rate_review,
        'color': AppTheme.accentPink,
        'route': '/examination/revaluation',
      },
      {
        'label': 'Tabulation',
        'sub': 'SGPA sheet per session',
        'icon': Icons.table_chart,
        'color': AppTheme.studentPrimary,
        'route': '/examination/tabulation',
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.25,
      ),
      itemCount: menu.length,
      itemBuilder: (context, i) {
        final m = menu[i];
        final color = m['color'] as Color;
        return GlassCard(
          onTap: () => context.push(m['route'] as String),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(m['icon'] as IconData,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(m['label'] as String,
                  style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.dark, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(m['sub'] as String,
                  style: AppTheme.caption
                      .copyWith(color: AppTheme.mediumGray)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSessions() {
    if (_recentSessions.isEmpty) {
      return GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text('No exam sessions yet. Create one to get started.',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.mediumGray)),
          ),
        ),
      );
    }
    return Column(
      children: _recentSessions.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            onTap: () => context.push('/examination/sessions'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_note,
                      color: AppTheme.adminPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name']?.toString() ?? 'Session',
                          style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.dark,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${s['academic_year'] ?? ''} • Sem ${s['semester'] ?? '-'} • ${s['exam_type'] ?? ''}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                _statusChip(s['status']?.toString() ?? 'draft'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'published':
        color = AppTheme.info;
        break;
      case 'conducted':
        color = AppTheme.warning;
        break;
      case 'result_declared':
        color = AppTheme.success;
        break;
      default:
        color = AppTheme.lightGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: AppTheme.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
