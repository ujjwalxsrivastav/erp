import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/auth_service.dart';
import '../data/lead_model.dart';
import '../data/lead_status.dart';
import '../data/counsellor_model.dart';
import '../services/lead_service.dart';
import '../services/counsellor_service.dart';
import '../services/lead_analytics_service.dart';
import '../widgets/lead_card.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/activity_feed.dart';
import '../widgets/sla_alerts.dart';
import 'lead_detail_screen.dart';
import 'counsellor_profile_screen.dart';

/// AdmissionDean Dashboard - Main dashboard for lead management
class DeanDashboard extends StatefulWidget {
  final String username;

  const DeanDashboard({super.key, required this.username});

  @override
  State<DeanDashboard> createState() => _DeanDashboardState();
}

class _DeanDashboardState extends State<DeanDashboard>
    with SingleTickerProviderStateMixin {
  final LeadService _leadService = LeadService();
  final CounsellorService _counsellorService = CounsellorService();
  final LeadAnalyticsService _analyticsService = LeadAnalyticsService();

  late TabController _tabController;

  // Data
  List<Lead> _unassignedLeads = [];
  List<Lead> _allLeads = [];
  List<CounsellorPerformance> _counsellorPerformance = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _dailyAnalytics = [];
  List<Map<String, dynamic>> _sourceAnalytics = [];
  List<Map<String, dynamic>> _stateAnalytics = [];

  bool _isLoading = true;
  String? _error;

  // Filters
  LeadStatus? _statusFilter;
  LeadPriority? _priorityFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _leadService.getUnassignedLeads(),
        _leadService.getLeads(limit: 100),
        _counsellorService.getCounsellorPerformance(),
        _leadService.getLeadStats(),
        _analyticsService.getDailyAnalytics(limit: 14),
        _analyticsService.getSourceAnalytics(),
        _analyticsService.getStateAnalytics(),
      ]);

      setState(() {
        _unassignedLeads = results[0] as List<Lead>;
        _allLeads = results[1] as List<Lead>;
        _counsellorPerformance = results[2] as List<CounsellorPerformance>;
        _stats = results[3] as Map<String, dynamic>;
        _dailyAnalytics = results[4] as List<Map<String, dynamic>>;
        _sourceAnalytics = results[5] as List<Map<String, dynamic>>;
        _stateAnalytics = results[6] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Column(
                    children: [
                      // SLA Alerts Banner
                      SlaAlertsWidget(
                          compact: true,
                          onTap: () {
                            _tabController.animateTo(4); // Go to Activity tab
                          }),
                      _buildStatsRow(),
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).primaryColor,
                        isScrollable: true,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inbox, size: 16),
                                const SizedBox(width: 4),
                                Text('New (${_unassignedLeads.length})'),
                              ],
                            ),
                          ),
                          const Tab(text: 'All Leads'),
                          const Tab(text: 'Team'),
                          const Tab(text: 'Analytics'),
                          const Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timeline, size: 16),
                                SizedBox(width: 4),
                                Text('Activity'),
                              ],
                            ),
                          ),
                          const Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off,
                                    size: 16, color: Colors.red),
                                SizedBox(width: 4),
                                Text('Rejected'),
                              ],
                            ),
                          ),
                          const Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business, size: 16),
                                SizedBox(width: 4),
                                Text('Facilities'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildUnassignedTab(),
                            _buildAllLeadsTab(),
                            _buildTeamTab(),
                            _buildAnalyticsTab(),
                            _buildActivityTab(),
                            _buildRejectedTab(),
                            _buildFacilitiesTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLeadDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Lead'),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.leaderboard),
          SizedBox(width: 8),
          Text('Lead Management'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await AuthService().logout();
            if (mounted) context.go('/login');
          },
          tooltip: 'Logout',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MiniStatCard(
              icon: Icons.inbox,
              value: '${_stats['new_leads'] ?? 0}',
              label: 'New',
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            _MiniStatCard(
              icon: Icons.trending_up,
              value: '${_stats['active_leads'] ?? 0}',
              label: 'Active',
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            _MiniStatCard(
              icon: Icons.check_circle,
              value: '${_stats['converted_leads'] ?? 0}',
              label: 'Converted',
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            _MiniStatCard(
              icon: Icons.today,
              value: '${_stats['today_leads'] ?? 0}',
              label: 'Today',
              color: Colors.purple,
            ),
            const SizedBox(width: 12),
            _MiniStatCard(
              icon: Icons.percent,
              value: '${_stats['overall_conversion_rate'] ?? 0}%',
              label: 'Rate',
              color: Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedTab() {
    if (_unassignedLeads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text(
              'All leads are assigned!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'No new leads waiting for assignment',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: _unassignedLeads.length,
      itemBuilder: (context, index) {
        final lead = _unassignedLeads[index];
        return LeadCard(
          lead: lead,
          showAssignButton: true,
          onTap: () => _openLeadDetail(lead),
          onAssign: () => _showAssignDialog(lead),
        );
      },
    );
  }

  Widget _buildAllLeadsTab() {
    return Column(
      children: [
        // Search and filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search leads...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _filterLeads();
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<LeadStatus?>(
                icon: Icon(
                  Icons.filter_list,
                  color: _statusFilter != null
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                onSelected: (status) {
                  setState(() => _statusFilter = status);
                  _filterLeads();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<LeadStatus?>(
                    value: null,
                    child: Text('All Statuses'),
                  ),
                  ...LeadStatus.values
                      .map((status) => PopupMenuItem<LeadStatus?>(
                            value: status,
                            child: Row(
                              children: [
                                Text(status.emoji),
                                const SizedBox(width: 8),
                                Text(status.label),
                              ],
                            ),
                          )),
                ],
              ),
            ],
          ),
        ),

        // Leads list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _filteredLeads.length,
            itemBuilder: (context, index) {
              final lead = _filteredLeads[index];
              final isAssigned = lead.assignedCounsellorId != null;

              // Get counsellor name if assigned
              String? counsellorName;
              if (isAssigned) {
                final counsellor = _counsellorPerformance.firstWhere(
                  (c) => c.counsellorId == lead.assignedCounsellorId,
                  orElse: () => _counsellorPerformance.isNotEmpty
                      ? _counsellorPerformance.first
                      : throw StateError('No counsellor found'),
                );
                try {
                  counsellorName = counsellor.counsellorName;
                } catch (_) {
                  counsellorName = null;
                }
              }

              return LeadCard(
                lead: lead,
                onTap: () => _openLeadDetail(lead),
                onStatusUpdate: () => _showStatusUpdateDialog(lead),
                showTransferButton: isAssigned,
                onTransfer: isAssigned ? () => _showTransferDialog(lead) : null,
                counsellorName: counsellorName,
                showDeleteButton: true,
                onDelete: () => _showDeleteConfirmation(lead),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(Lead lead) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Permanently Delete Lead?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete the lead for:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(lead.phone, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await _leadService.deleteLead(lead.id, widget.username);
              if (success) {
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lead deleted permanently'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete lead'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Forever',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<Lead> get _filteredLeads {
    return _allLeads.where((lead) {
      // Status filter
      if (_statusFilter != null && lead.status != _statusFilter) {
        return false;
      }
      // Priority filter
      if (_priorityFilter != null && lead.priority != _priorityFilter) {
        return false;
      }
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return lead.studentName.toLowerCase().contains(query) ||
            lead.phone.contains(query) ||
            (lead.email?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();
  }

  void _filterLeads() {
    // Trigger rebuild to apply filters
    setState(() {});
  }

  Widget _buildTeamTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Counsellor Performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap on a counsellor to view full profile',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ..._counsellorPerformance.asMap().entries.map((entry) {
          final index = entry.key;
          final counsellor = entry.value;
          final badge = index == 0
              ? '🏆'
              : index == 1
                  ? '🥈'
                  : index == 2
                      ? '🥉'
                      : '';

          return GestureDetector(
            onTap: () => _openCounsellorProfile(counsellor.counsellorId),
            child: _CounsellorPerformanceCard(
              counsellor: counsellor,
              rank: index + 1,
              badge: badge,
            ),
          );
        }),
      ],
    );
  }

  void _openCounsellorProfile(String counsellorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CounsellorProfileScreen(counsellorId: counsellorId),
      ),
    ).then((_) => _loadData());
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Lead Trend Chart
        LeadTrendChart(
          data: _dailyAnalytics,
          title: 'Lead Trends (Last 14 Days)',
        ),
        const SizedBox(height: 16),

        // State-wise Distribution
        StateDistributionChart(data: _stateAnalytics),
        const SizedBox(height: 16),

        // Source Distribution
        SourcePieChart(data: _sourceAnalytics),
        const SizedBox(height: 16),

        // Counsellor Comparison
        CounsellorBarChart(
          data: _counsellorPerformance
              .map((c) => {
                    'name': c.counsellorName,
                    'conversions': c.conversions,
                    'active_pipeline': c.activePipeline,
                  })
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    return ActivityFeedWidget(
      limit: 50,
      showHeader: false,
      onRefresh: _loadData,
    );
  }

  Widget _buildRejectedTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadDeadAdmissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    color: Colors.green.shade300, size: 64),
                const SizedBox(height: 12),
                const Text('No Rejected Admissions',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('All offers have been accepted!',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final deadAdmissions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: deadAdmissions.length,
          itemBuilder: (context, index) {
            final admission = deadAdmissions[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.person_off,
                      color: Colors.red.shade700, size: 20),
                ),
                title: Text(admission['student_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${admission['course'] ?? '-'} • ${admission['phone'] ?? '-'}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('REJECTED',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Text(admission['assigned_counsellor'] ?? '-',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFacilitiesTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Facility Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage student allocations for hostel and transportation services.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildFacilityCard(
          title: 'Hostel Management',
          subtitle: 'View and manage hostel room allocations',
          icon: Icons.hotel,
          color: Colors.indigo,
          onTap: () => context.push('/hostel-management'),
          count: 'Opted: 0',
        ),
        const SizedBox(height: 16),
        _buildFacilityCard(
          title: 'Transport Management',
          subtitle: 'Manage bus routes and student pickups',
          icon: Icons.directions_bus,
          color: Colors.teal,
          onTap: () => context.push('/transport-management'),
          count: 'Opted: 0',
        ),
      ],
    );
  }

  Widget _buildFacilityCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String count,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadDeadAdmissions() async {
    try {
      final response = await Supabase.instance.client
          .from('dead_admissions')
          .select()
          .order('rejected_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  void _openLeadDetail(Lead lead) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeadDetailScreen(
          leadId: lead.id,
          username: widget.username,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showAssignDialog(Lead lead) async {
    final counsellors =
        await _counsellorService.getCounsellorsWithAvailability();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AssignCounsellorSheet(
        lead: lead,
        counsellors: counsellors,
        onAssign: (counsellorId) async {
          final success = await _leadService.assignLead(
            leadId: lead.id,
            counsellorId: counsellorId,
            assignedBy: widget.username,
          );

          if (success) {
            Navigator.pop(context);
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lead assigned successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showStatusUpdateDialog(Lead lead) {
    final availableStatuses = LeadStatusHelper.getNextStatuses(lead.status);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableStatuses.map((status) {
                return ActionChip(
                  avatar: Text(status.emoji),
                  label: Text(status.label),
                  onPressed: () async {
                    final success = await _leadService.updateLeadStatus(
                      leadId: lead.id,
                      newStatus: status,
                      changedBy: widget.username,
                    );

                    Navigator.pop(context);
                    if (success) {
                      _loadData();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(Lead lead) async {
    final counsellors =
        await _counsellorService.getCounsellorsWithAvailability();

    if (!mounted) return;

    String? selectedCounsellorId;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_calls, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Transfer Lead',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Transfer "${lead.studentName}" to another counsellor',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Current Status: ${lead.status.label} (will be preserved)',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Select New Counsellor',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                ...counsellors.map((c) {
                  final id = c['id'] as String;
                  final name = c['name'] as String;
                  final activeLeads = c['active_leads'] as int? ?? 0;
                  final maxLeads = c['max_leads'] as int? ?? 50;
                  final isSelected = id == selectedCounsellorId;
                  final isCurrentCounsellor = id == lead.assignedCounsellorId;

                  return Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isSelected ? Colors.blue : Colors.grey.shade200,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text('$activeLeads/$maxLeads leads'),
                      trailing: isCurrentCounsellor
                          ? const Chip(
                              label: Text('Current',
                                  style: TextStyle(fontSize: 10)))
                          : isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.blue)
                              : null,
                      onTap: isCurrentCounsellor
                          ? null
                          : () =>
                              setSheetState(() => selectedCounsellorId = id),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for transfer (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: selectedCounsellorId != null
                        ? () async {
                            final success = await _leadService.transferLead(
                              leadId: lead.id,
                              newCounsellorId: selectedCounsellorId!,
                              transferredBy: widget.username,
                              reason: reasonController.text.isNotEmpty
                                  ? reasonController.text
                                  : null,
                            );

                            Navigator.pop(context);
                            if (success) {
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Lead transferred successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to transfer lead'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.swap_calls),
                    label: const Text('Transfer Lead'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddLeadDialog() {
    final formKey = GlobalKey<FormState>();
    String name = '',
        phone = '',
        course = 'BCA',
        email = '',
        city = '',
        state = '';
    String? referralType;
    String referrerName = '';
    String referrerId = '';
    bool isCheckingDuplicate = false;
    Map<String, dynamic>? duplicateLead;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add New Lead (Manual)',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit,
                                size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Manual',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Referral Type Selection
                  const Text(
                    'How did this lead come to you?',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ReferralChip(
                        label: '📞 Website Call',
                        value: 'website_call',
                        selected: referralType == 'website_call',
                        onTap: () =>
                            setSheetState(() => referralType = 'website_call'),
                      ),
                      _ReferralChip(
                        label: '🎓 Student Referral',
                        value: 'student',
                        selected: referralType == 'student',
                        onTap: () =>
                            setSheetState(() => referralType = 'student'),
                      ),
                      _ReferralChip(
                        label: '👨‍🏫 Faculty Referral',
                        value: 'faculty',
                        selected: referralType == 'faculty',
                        onTap: () =>
                            setSheetState(() => referralType = 'faculty'),
                      ),
                      _ReferralChip(
                        label: '📋 Other',
                        value: 'other',
                        selected: referralType == 'other',
                        onTap: () =>
                            setSheetState(() => referralType = 'other'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Referrer Info (conditional)
                  if (referralType == 'student' ||
                      referralType == 'faculty') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: referralType == 'student'
                                  ? 'Student Name'
                                  : 'Faculty Name',
                              border: const OutlineInputBorder(),
                            ),
                            onSaved: (v) => referrerName = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: referralType == 'student'
                                  ? 'Student ID'
                                  : 'Faculty ID',
                              border: const OutlineInputBorder(),
                            ),
                            onSaved: (v) => referrerId = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Student Info
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Student Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    onSaved: (v) => name = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      border: const OutlineInputBorder(),
                      suffixIcon: isCheckingDuplicate
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (duplicateLead != null
                              ? const Icon(Icons.warning, color: Colors.orange)
                              : null),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    onChanged: (value) async {
                      if (value.length >= 10) {
                        setSheetState(() => isCheckingDuplicate = true);
                        final duplicate =
                            await _leadService.checkDuplicateLead(value);
                        setSheetState(() {
                          isCheckingDuplicate = false;
                          duplicateLead = duplicate;
                        });
                      } else {
                        setSheetState(() => duplicateLead = null);
                      }
                    },
                    onSaved: (v) => phone = v ?? '',
                  ),

                  // Duplicate Warning
                  if (duplicateLead != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duplicate Found!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                Text(
                                  '${duplicateLead!['student_name']} - ${duplicateLead!['status']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (v) => email = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Preferred Course',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: course,
                    items: [
                      'BCA',
                      'MCA',
                      'BBA',
                      'MBA',
                      'BTech',
                      'MTech',
                      'Other'
                    ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => course = v ?? 'BCA',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (v) => city = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (v) => state = v ?? '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: duplicateLead != null
                          ? null
                          : () async {
                              if (formKey.currentState?.validate() ?? false) {
                                formKey.currentState?.save();

                                try {
                                  final lead =
                                      await _leadService.createManualLead(
                                    studentName: name,
                                    phone: phone,
                                    email: email.isNotEmpty ? email : null,
                                    city: city.isNotEmpty ? city : null,
                                    state: state.isNotEmpty ? state : null,
                                    preferredCourse: course,
                                    enteredBy: widget.username,
                                    referralType: referralType,
                                    referrerName: referrerName.isNotEmpty
                                        ? referrerName
                                        : null,
                                    referrerId: referrerId.isNotEmpty
                                        ? referrerId
                                        : null,
                                  );

                                  Navigator.pop(context);
                                  if (lead != null) {
                                    _loadData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Lead created successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e
                                              .toString()
                                              .contains('DUPLICATE')
                                          ? 'This phone number already exists!'
                                          : 'Error creating lead'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            duplicateLead != null ? Colors.grey : null,
                      ),
                      child: Text(duplicateLead != null
                          ? 'Cannot Create - Duplicate'
                          : 'Create Lead'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferralChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _ReferralChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.blue.shade400 : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounsellorPerformanceCard extends StatelessWidget {
  final CounsellorPerformance counsellor;
  final int rank;
  final String badge;

  const _CounsellorPerformanceCard({
    required this.counsellor,
    required this.rank,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rank <= 3 ? Colors.amber.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  badge.isNotEmpty ? badge : '#$rank',
                  style: TextStyle(
                    fontSize: badge.isNotEmpty ? 18 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    counsellor.counsellorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    counsellor.specialization ?? 'All Courses',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '${counsellor.conversions}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${counsellor.conversionRate}%',
                  style: TextStyle(
                    color: counsellor.conversionRate >= 30
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignCounsellorSheet extends StatelessWidget {
  final Lead lead;
  final List<Map<String, dynamic>> counsellors;
  final Function(String) onAssign;

  const _AssignCounsellorSheet({
    required this.lead,
    required this.counsellors,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add),
              const SizedBox(width: 8),
              Text(
                'Assign ${lead.studentName}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Course: ${lead.preferredCourse}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Counsellor',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ...counsellors.map((c) {
            final isAvailable = c['is_available'] as bool? ?? true;
            // workload percentage available at c['workload_percentage'] if needed

            return ListTile(
              enabled: isAvailable,
              onTap: isAvailable ? () => onAssign(c['id'] as String) : null,
              leading: CircleAvatar(
                backgroundColor:
                    isAvailable ? Colors.green.shade100 : Colors.grey.shade200,
                child: Text(
                  (c['name'] as String? ?? '?')[0],
                  style: TextStyle(
                    color: isAvailable ? Colors.green.shade700 : Colors.grey,
                  ),
                ),
              ),
              title: Text(c['name'] as String? ?? 'Unknown'),
              subtitle: Text(
                '${c['specialization'] ?? 'All Courses'} • ${c['active_leads']}/${c['max_leads']} leads',
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAvailable ? '${c['conversion_rate']}%' : 'Full',
                  style: TextStyle(
                    color: isAvailable ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
