import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/leave_service.dart';

class HRLeaveRequestsScreen extends StatefulWidget {
  const HRLeaveRequestsScreen({super.key});

  @override
  State<HRLeaveRequestsScreen> createState() => _HRLeaveRequestsScreenState();
}

class _HRLeaveRequestsScreenState extends State<HRLeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _leaveService = LeaveService();

  List<Map<String, dynamic>> _pendingLeaves = [];
  List<Map<String, dynamic>> _allLeaves = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
    _loadLeaves();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    setState(() => _isLoading = true);
    final pending = await _leaveService.getPendingLeaves();
    final all = await _leaveService.getAllLeaves();

    // Fetch balance for each leave request
    for (var leave in pending) {
      final teacherId = leave['teacher_id'];
      if (teacherId != null) {
        final balance = await _leaveService.getLeaveBalance(teacherId);
        leave['_balance_info'] = balance;
      }
    }

    for (var leave in all) {
      final teacherId = leave['teacher_id'];
      if (teacherId != null) {
        final balance = await _leaveService.getLeaveBalance(teacherId);
        leave['_balance_info'] = balance;
      }
    }

    if (mounted) {
      setState(() {
        _pendingLeaves = pending;
        _allLeaves = all;
        _isLoading = false;
      });
    }
  }

  Future<void> _approveLeave(int leaveId, bool deductSalary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to approve this leave request?'),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: deductSalary,
                  onChanged: (value) {
                    Navigator.pop(context);
                    _approveLeave(leaveId, value ?? false);
                  },
                ),
                const Expanded(
                  child: Text(
                    'Deduct salary for this leave',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _leaveService.approveLeave(
        leaveId: leaveId,
        approvedBy: 'hr1', // TODO: Get from session
        deductSalary: deductSalary,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Leave approved successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadLeaves();
      }
    }
  }

  Future<void> _rejectLeave(int leaveId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      final success = await _leaveService.rejectLeave(
        leaveId: leaveId,
        rejectedBy: 'hr1', // TODO: Get from session
        reason: reasonController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Leave rejected'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        _loadLeaves();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF10B981),
                      const Color(0xFF059669),
                      const Color(0xFF047857),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Leave Requests',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${_pendingLeaves.length} pending',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'All Requests'),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate([
                      if (_selectedTab == 0)
                        ..._buildLeaveCards(_pendingLeaves, showActions: true)
                      else
                        ..._buildLeaveCards(_allLeaves, showActions: false),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLeaveCards(List<Map<String, dynamic>> leaves,
      {required bool showActions}) {
    if (leaves.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No leave requests',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return leaves
        .map((leave) => _buildLeaveCard(leave, showActions: showActions))
        .toList();
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave,
      {required bool showActions}) {
    final teacherDetails = leave['teacher_details'] as Map<String, dynamic>?;
    final status = leave['status'] as String;

    Color statusColor;
    switch (status) {
      case 'Approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.2),
                        const Color(0xFF059669).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      teacherDetails?['name']?[0].toUpperCase() ?? 'T',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacherDetails?['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${teacherDetails?['department']} • ${teacherDetails?['designation']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.event, 'Dates',
                      '${leave['start_date']} to ${leave['end_date']}'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.calendar_today, 'Duration',
                      '${leave['total_days']} days'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.category, 'Type', leave['leave_type']),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.description, 'Reason', leave['reason']),

                  // Show balance info if available
                  if (leave['_balance_info'] != null) ...[
                    const SizedBox(height: 12),
                    _buildBalanceInfo(leave),
                  ],
                ],
              ),
            ),
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectLeave(leave['leave_id']),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveLeave(leave['leave_id'], false),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF059669)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceInfo(Map<String, dynamic> leave) {
    final balanceInfo = leave['_balance_info'] as Map<String, dynamic>?;
    final totalDays = leave['total_days'] as int;
    final remaining = balanceInfo?['sick_leaves_remaining'] as int? ?? 0;
    final isInsufficient = remaining < totalDays;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isInsufficient ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInsufficient
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isInsufficient ? Icons.warning_amber : Icons.check_circle,
            size: 16,
            color: isInsufficient
                ? const Color(0xFFEF4444)
                : const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isInsufficient
                  ? 'Leave Balance: $remaining days (Requested: $totalDays days)'
                  : 'Leave Balance: $remaining days available',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isInsufficient
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
