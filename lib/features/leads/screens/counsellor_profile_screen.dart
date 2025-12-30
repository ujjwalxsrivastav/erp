import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/lead_model.dart';
import '../data/lead_status.dart';
import '../data/counsellor_model.dart';
import '../services/lead_service.dart';
import '../services/counsellor_service.dart';
import '../widgets/lead_status_chip.dart';
import 'lead_detail_screen.dart';

/// Counsellor Profile Screen - Detailed view for Dean to see counsellor performance
class CounsellorProfileScreen extends StatefulWidget {
  final String counsellorId;

  const CounsellorProfileScreen({
    super.key,
    required this.counsellorId,
  });

  @override
  State<CounsellorProfileScreen> createState() =>
      _CounsellorProfileScreenState();
}

class _CounsellorProfileScreenState extends State<CounsellorProfileScreen> {
  final LeadService _leadService = LeadService();
  final CounsellorService _counsellorService = CounsellorService();

  CounsellorPerformance? _performance;
  List<Lead> _allLeads = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _regions = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load counsellor performance
      final performance = await _counsellorService
          .getCounsellorPerformanceById(widget.counsellorId);

      // Load all leads assigned to this counsellor
      final leads = await _leadService.getLeads(
        counsellorId: widget.counsellorId,
        limit: 200,
      );

      // Load recent activity for this counsellor
      final activity = await _leadService.getActivityFeed(
        counsellorId: widget.counsellorId,
        limit: 30,
      );

      // Load regions
      final regions =
          await _counsellorService.getCounsellorRegions(widget.counsellorId);

      setState(() {
        _performance = performance;
        _allLeads = leads;
        _recentActivity = activity;
        _regions = regions;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<Lead> get _filteredLeads {
    if (_filterStatus == 'all') return _allLeads;
    return _allLeads.where((l) => l.status.value == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Counsellor Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

  Widget _buildContent() {
    if (_performance == null) {
      return const Center(child: Text('Counsellor not found'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildRegionsSection(),
            const SizedBox(height: 24),
            _buildConversionFunnel(),
            const SizedBox(height: 24),
            _buildLeadsSection(),
            const SizedBox(height: 24),
            _buildActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final p = _performance!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                p.counsellorName.isNotEmpty
                    ? p.counsellorName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.counsellorName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (p.phone != null)
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(p.phone!),
                      ],
                    ),
                  if (p.email != null)
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                            child: Text(p.email!,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  if (p.specialization != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🎯 ${p.specialization}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Status
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    p.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                      5,
                      (index) => Icon(
                            Icons.star,
                            size: 16,
                            color: index < p.performanceRating
                                ? Colors.amber
                                : Colors.grey.shade300,
                          )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final p = _performance!;
    return Row(
      children: [
        _buildStatCard('Total Leads', p.totalAssigned.toString(), Icons.people,
            Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard('Active', p.activePipeline.toString(), Icons.trending_up,
            Colors.orange),
        const SizedBox(width: 12),
        _buildStatCard('Converted', p.conversions.toString(),
            Icons.check_circle, Colors.green),
        const SizedBox(width: 12),
        _buildStatCard('Rate', '${p.conversionRate.toStringAsFixed(1)}%',
            Icons.pie_chart, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionsSection() {
    if (_regions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🌍 Assigned Regions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _regions.map((region) {
            final states = (region['states'] as List?)?.cast<String>() ?? [];
            return Chip(
              avatar: region['is_default'] == true
                  ? const Icon(Icons.star, size: 16, color: Colors.amber)
                  : null,
              label: Text('${region['region_name']} (${states.length} states)'),
              backgroundColor: Colors.blue.shade50,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConversionFunnel() {
    final p = _performance!;

    // Calculate funnel stages
    final funnelData = [
      {
        'label': 'Total Assigned',
        'count': p.totalAssigned,
        'color': Colors.blue
      },
      {
        'label': 'Active Pipeline',
        'count': p.activePipeline,
        'color': Colors.orange
      },
      {'label': 'Leads Worked', 'count': p.leadsWorked, 'color': Colors.amber},
      {'label': 'Converted', 'count': p.conversions, 'color': Colors.green},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Conversion Funnel',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: funnelData.map((data) {
                final maxCount = p.totalAssigned > 0 ? p.totalAssigned : 1;
                final percentage = (data['count'] as int) / maxCount;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['label'] as String),
                          Text(
                            '${data['count']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: data['color'] as Color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 12,
                          backgroundColor:
                              (data['color'] as Color).withOpacity(0.2),
                          valueColor:
                              AlwaysStoppedAnimation(data['color'] as Color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📋 All Leads (${_allLeads.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Filter dropdown
            DropdownButton<String>(
              value: _filterStatus,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All')),
                ...LeadStatus.values.map((s) => DropdownMenuItem(
                      value: s.value,
                      child: Text(s.label),
                    )),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filterStatus = value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_filteredLeads.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No leads found')),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredLeads.length > 10 ? 10 : _filteredLeads.length,
            itemBuilder: (context, index) {
              final lead = _filteredLeads[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Color(LeadStatusHelper.getStatusColor(lead.status))
                            .withOpacity(0.2),
                    child: Text(
                      lead.studentName.isNotEmpty
                          ? lead.studentName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: Color(
                              LeadStatusHelper.getStatusColor(lead.status))),
                    ),
                  ),
                  title: Text(lead.studentName),
                  subtitle: Row(
                    children: [
                      LeadStatusChip(status: lead.status),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text(lead.phone,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  trailing: Text(
                    lead.preferredCourse,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeadDetailScreen(
                          leadId: lead.id,
                          username: _performance!.userId,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        if (_filteredLeads.length > 10)
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: Show all leads in a separate page
              },
              child: Text('View all ${_filteredLeads.length} leads'),
            ),
          ),
      ],
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🕐 Recent Activity',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_recentActivity.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No recent activity')),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  _recentActivity.length > 15 ? 15 : _recentActivity.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final activity = _recentActivity[index];
                return _buildActivityItem(activity);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final changeType = activity['change_type'] as String? ?? '';
    final newStatus = activity['new_status'] as String? ?? '';
    final studentName = activity['student_name'] as String? ?? 'Unknown';
    final notes = activity['notes'] as String?;
    final createdAt =
        DateTime.tryParse(activity['created_at'] as String? ?? '');

    IconData icon;
    Color color;
    String action;

    switch (changeType) {
      case 'status_change':
        icon = Icons.swap_horiz;
        color = Colors.blue;
        action = 'Updated status to $newStatus';
        break;
      case 'assignment':
      case 'auto_assignment':
        icon = Icons.person_add;
        color = Colors.green;
        action = 'Lead assigned';
        break;
      case 'transfer':
        icon = Icons.swap_calls;
        color = Colors.orange;
        action = 'Lead transferred';
        break;
      case 'note':
        icon = Icons.note_add;
        color = Colors.purple;
        action = 'Added note';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        action = changeType;
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, size: 16, color: color),
      ),
      title: Text(studentName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(action),
          if (notes != null && notes.isNotEmpty)
            Text(
              notes,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: createdAt != null
          ? Text(
              _formatTime(createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            )
          : null,
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}
