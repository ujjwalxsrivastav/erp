import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_service.dart';
import '../data/lead_model.dart';
import '../data/lead_status.dart';
import '../data/counsellor_model.dart';
import '../services/lead_service.dart';
import '../services/counsellor_service.dart';
import '../widgets/lead_status_chip.dart';
import '../widgets/analytics_charts.dart';
import 'lead_detail_screen.dart';

/// Counsellor Dashboard - Personal workspace for counsellors
class CounsellorDashboard extends StatefulWidget {
  final String username;

  const CounsellorDashboard({super.key, required this.username});

  @override
  State<CounsellorDashboard> createState() => _CounsellorDashboardState();
}

class _CounsellorDashboardState extends State<CounsellorDashboard>
    with SingleTickerProviderStateMixin {
  final LeadService _leadService = LeadService();
  final CounsellorService _counsellorService = CounsellorService();

  late TabController _tabController;

  // Data
  Counsellor? _counsellor;
  CounsellorPerformance? _performance;
  List<Lead> _assignedLeads = [];
  List<Lead> _todaysFollowups = [];
  List<Lead> _overdueLeads = [];
  Map<String, int> _leadCounts = {};

  bool _isLoading = true;
  String? _error;

  // Current filter
  LeadStatus? _currentFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      // First get counsellor details
      final counsellor =
          await _counsellorService.getCounsellorByUserId(widget.username);

      if (counsellor == null) {
        setState(() {
          _error = 'Counsellor profile not found';
          _isLoading = false;
        });
        return;
      }

      // Then load all related data
      final results = await Future.wait([
        _counsellorService.getCounsellorPerformanceById(counsellor.id),
        _leadService.getCounsellorLeads(counsellor.id),
        _leadService.getTodaysFollowups(counsellor.id),
        _leadService.getOverdueLeads(counsellor.id),
        _leadService.getCounsellorLeadCounts(counsellor.id),
      ]);

      setState(() {
        _counsellor = counsellor;
        _performance = results[0] as CounsellorPerformance?;
        _assignedLeads = results[1] as List<Lead>;
        _todaysFollowups = results[2] as List<Lead>;
        _overdueLeads = results[3] as List<Lead>;
        _leadCounts = results[4] as Map<String, int>;
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
                      _buildStatsRow(),
                      _buildAlerts(),
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
                                const Icon(Icons.list, size: 18),
                                const SizedBox(width: 4),
                                Text('All (${_assignedLeads.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule, size: 18),
                                const SizedBox(width: 4),
                                Text('Today (${_todaysFollowups.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 18,
                                  color: _overdueLeads.isNotEmpty
                                      ? Colors.red
                                      : null,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Overdue (${_overdueLeads.length})',
                                  style: TextStyle(
                                    color: _overdueLeads.isNotEmpty
                                        ? Colors.red
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Tab(text: 'My Stats'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAllLeadsTab(),
                            _buildTodaysFollowupsTab(),
                            _buildOverdueTab(),
                            _buildMyStatsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.support_agent),
          const SizedBox(width: 8),
          Text(_counsellor?.name ?? 'My Leads'),
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
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.assignment,
              value: '${_leadCounts['total'] ?? 0}',
              label: 'Total',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.trending_up,
              value: '${_leadCounts['active'] ?? 0}',
              label: 'Active',
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.check_circle,
              value: '${_leadCounts['converted'] ?? 0}',
              label: 'Converted',
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.percent,
              value: '${_performance?.conversionRate ?? 0}%',
              label: 'Rate',
              color: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlerts() {
    if (_overdueLeads.isEmpty && _todaysFollowups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_overdueLeads.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_overdueLeads.length} leads with overdue follow-ups!',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _tabController.animateTo(2),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
          if (_todaysFollowups.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_todaysFollowups.length} follow-ups scheduled for today',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _tabController.animateTo(1),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllLeadsTab() {
    return Column(
      children: [
        // Quick filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _currentFilter == null,
                  onTap: () => setState(() => _currentFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Assigned',
                  emoji: '📋',
                  isSelected: _currentFilter == LeadStatus.assigned,
                  onTap: () =>
                      setState(() => _currentFilter = LeadStatus.assigned),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Contacted',
                  emoji: '📞',
                  isSelected: _currentFilter == LeadStatus.contacted,
                  onTap: () =>
                      setState(() => _currentFilter = LeadStatus.contacted),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Interested',
                  emoji: '✨',
                  isSelected: _currentFilter == LeadStatus.interested,
                  onTap: () =>
                      setState(() => _currentFilter = LeadStatus.interested),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Follow-up',
                  emoji: '🔄',
                  isSelected: _currentFilter == LeadStatus.followup,
                  onTap: () =>
                      setState(() => _currentFilter = LeadStatus.followup),
                ),
              ],
            ),
          ),
        ),

        // Leads list
        Expanded(
          child: _buildLeadsList(_filteredLeads),
        ),
      ],
    );
  }

  List<Lead> get _filteredLeads {
    if (_currentFilter == null) return _assignedLeads;
    return _assignedLeads.where((l) => l.status == _currentFilter).toList();
  }

  Widget _buildTodaysFollowupsTab() {
    if (_todaysFollowups.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle,
        title: 'No follow-ups for today',
        subtitle: 'You\'re all caught up!',
      );
    }

    return _buildLeadsList(_todaysFollowups);
  }

  Widget _buildOverdueTab() {
    if (_overdueLeads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.celebration,
        title: 'No overdue leads',
        subtitle: 'Great job staying on top of your follow-ups!',
      );
    }

    return _buildLeadsList(_overdueLeads);
  }

  Widget _buildLeadsList(List<Lead> leads) {
    if (leads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox,
        title: 'No leads found',
        subtitle: 'Check back later for new leads',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        return _CounsellorLeadCard(
          lead: lead,
          onTap: () => _openLeadDetail(lead),
          onCall: () => _makeCall(lead.phone),
          onWhatsApp: () => _openWhatsApp(lead.phone),
          onUpdateStatus: () => _showStatusUpdateSheet(lead),
        );
      },
    );
  }

  Widget _buildMyStatsTab() {
    if (_performance == null) {
      return const Center(child: Text('No performance data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Conversion Gauge
        Row(
          children: [
            Expanded(
              child: ConversionGauge(
                rate: _performance!.conversionRate,
                label: 'My Conversion Rate',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StatRow(
                          label: 'Total Assigned',
                          value: '${_performance!.totalAssigned}'),
                      const Divider(),
                      _StatRow(
                          label: 'Leads Worked',
                          value: '${_performance!.leadsWorked}'),
                      const Divider(),
                      _StatRow(
                          label: 'Conversions',
                          value: '${_performance!.conversions}',
                          valueColor: Colors.green),
                      const Divider(),
                      _StatRow(
                          label: 'Active Pipeline',
                          value: '${_performance!.activePipeline}'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Response Time
        if (_performance!.avgResponseHours != null)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.speed, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Avg Response Time',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '${_performance!.avgResponseHours!.toStringAsFixed(1)} hours',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Workload indicator
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Workload',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _performance!.workloadPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _performance!.workloadPercentage >= 80
                        ? Colors.red
                        : _performance!.workloadPercentage >= 50
                            ? Colors.orange
                            : Colors.green,
                  ),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_performance!.activePipeline} / ${_performance!.maxActiveLeads} active leads',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
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

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final formattedPhone =
        cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';

    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showStatusUpdateSheet(Lead lead) {
    final availableStatuses = LeadStatusHelper.getNextStatuses(lead.status);
    final noteController = TextEditingController();
    DateTime? selectedFollowup;

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
                    const Icon(Icons.update),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update: ${lead.studentName}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Current: '),
                    LeadStatusChip(status: lead.status, compact: true),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Select New Status',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableStatuses.map((status) {
                    return ActionChip(
                      avatar: Text(status.emoji),
                      label: Text(status.label),
                      backgroundColor:
                          Color(LeadStatusHelper.getStatusColor(status))
                              .withOpacity(0.1),
                      onPressed: () => _updateStatus(
                          lead, status, noteController.text, selectedFollowup),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Add Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 60)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 10, minute: 0),
                            );
                            if (time != null) {
                              setSheetState(() {
                                selectedFollowup = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          selectedFollowup != null
                              ? '${selectedFollowup!.day}/${selectedFollowup!.month} at ${selectedFollowup!.hour}:${selectedFollowup!.minute.toString().padLeft(2, '0')}'
                              : 'Schedule Follow-up',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(Lead lead, LeadStatus newStatus, String? notes,
      DateTime? followup) async {
    final success = await _leadService.updateLeadStatus(
      leadId: lead.id,
      newStatus: newStatus,
      changedBy: widget.username,
      notes: notes?.isNotEmpty == true ? notes : null,
      nextFollowup: followup,
    );

    Navigator.pop(context);

    if (success) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${newStatus.label}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounsellorLeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onUpdateStatus;

  const _CounsellorLeadCard({
    required this.lead,
    required this.onTap,
    required this.onCall,
    required this.onWhatsApp,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isHot = lead.priority == LeadPriority.high;
    final needsAttention = lead.isFollowupOverdue || lead.needsFollowupToday;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isHot
            ? const BorderSide(color: Colors.red, width: 1.5)
            : needsAttention
                ? BorderSide(color: Colors.amber.shade400, width: 1.5)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  if (isHot)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🔥', style: TextStyle(fontSize: 14)),
                    )
                  else
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                        lead.studentName[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.studentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${lead.preferredCourse} • ${lead.timeSinceCreation}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LeadStatusChip(status: lead.status, compact: true),
                ],
              ),

              const SizedBox(height: 12),

              // Contact info
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(lead.phone,
                      style: TextStyle(color: Colors.grey.shade700)),
                  if (lead.city != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(lead.city!,
                        style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ],
              ),

              // Last remark
              if (lead.lastRemark != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notes, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lead.lastRemark!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Follow-up alert
              if (needsAttention) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lead.isFollowupOverdue
                        ? Colors.red.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        lead.isFollowupOverdue ? Icons.warning : Icons.schedule,
                        size: 14,
                        color: lead.isFollowupOverdue
                            ? Colors.red
                            : Colors.amber.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lead.isFollowupOverdue
                            ? 'Follow-up overdue!'
                            : 'Follow-up today',
                        style: TextStyle(
                          color: lead.isFollowupOverdue
                              ? Colors.red
                              : Colors.amber.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onUpdateStatus,
                      icon: const Icon(Icons.update, size: 16),
                      label: const Text('Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
