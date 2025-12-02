import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/leave_service.dart';

class TeacherLeaveApplyScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String department;

  const TeacherLeaveApplyScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.department,
  });

  @override
  State<TeacherLeaveApplyScreen> createState() =>
      _TeacherLeaveApplyScreenState();
}

class _TeacherLeaveApplyScreenState extends State<TeacherLeaveApplyScreen>
    with SingleTickerProviderStateMixin {
  final _leaveService = LeaveService();
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingBalance = true;
  Map<String, dynamic>? _leaveBalance;
  List<Map<String, dynamic>> _leaveHistory = [];

  String _selectedLeaveType = 'Sick Leave';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _documentUrl;
  int _totalDays = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingBalance = true);
    final balance = await _leaveService.getLeaveBalance(widget.teacherId);
    final history = await _leaveService.getLeaveHistory(widget.teacherId);
    if (mounted) {
      setState(() {
        _leaveBalance = balance;
        _leaveHistory = history;
        _isLoadingBalance = false;
      });
    }
  }

  void _calculateDays() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _totalDays = _endDate!.difference(_startDate!).inDays + 1;
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      setState(() {
        _documentUrl = result.files.first.name;
      });
    }
  }

  Future<void> _submitLeave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please select start and end dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get employee_id from balance data (already fetched in _loadData)
      final employeeId =
          _leaveBalance?['employee_id'] as String? ?? widget.teacherId;

      await _leaveService.applyLeave(
        teacherId: widget.teacherId,
        employeeId: employeeId, // Use actual employee_id
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        documentUrl: _documentUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Leave application submitted successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Futuristic App Bar
          SliverAppBar(
            expandedHeight: 180,
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
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  widget.teacherName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
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
                                    widget.teacherName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.department,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Leave Balance Card
                      _buildLeaveBalanceCard(),
                      const SizedBox(height: 24),

                      // Leave Application Form
                      _buildLeaveForm(),
                      const SizedBox(height: 24),

                      // Leave History
                      _buildLeaveHistory(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCard() {
    if (_isLoadingBalance) {
      return _buildFloatingCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
              color: Color(0xFF10B981),
            ),
          ),
        ),
      );
    }

    final total = _leaveBalance?['sick_leaves_total'] ?? 2;
    final used = _leaveBalance?['sick_leaves_used'] ?? 0;
    final remaining = _leaveBalance?['sick_leaves_remaining'] ?? 2;

    return _buildFloatingCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF10B981).withOpacity(0.1),
          const Color(0xFF059669).withOpacity(0.05),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF059669),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Leave Balance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    'Total',
                    total.toString(),
                    const Color(0xFF3B82F6),
                  ),
                ),
                Expanded(
                  child: _buildBalanceItem(
                    'Used',
                    used.toString(),
                    const Color(0xFFF59E0B),
                  ),
                ),
                Expanded(
                  child: _buildBalanceItem(
                    'Remaining',
                    remaining.toString(),
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$total Sick Leaves / month • Auto-resets monthly',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF059669),
                        fontWeight: FontWeight.w600,
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

  Widget _buildBalanceItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveForm() {
    return _buildFloatingCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apply for Leave',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 20),

              // Leave Type
              _buildFloatingField(
                child: DropdownButtonFormField<String>(
                  value: _selectedLeaveType,
                  decoration: const InputDecoration(
                    labelText: 'Leave Type',
                    prefixIcon:
                        Icon(Icons.category_rounded, color: Color(0xFF10B981)),
                    border: InputBorder.none,
                  ),
                  items: ['Sick Leave', 'Casual Leave', 'Emergency Leave']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedLeaveType = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Date Selection
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF10B981),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                            if (_endDate != null &&
                                _endDate!.isBefore(_startDate!)) {
                              _endDate = _startDate;
                            }
                            _calculateDays();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(
                      label: 'End Date',
                      date: _endDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF10B981),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _endDate = picked;
                            _calculateDays();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Days Display
              if (_totalDays > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.1),
                        const Color(0xFF059669).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.event_available,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Total Days: $_totalDays',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_totalDays > 0) const SizedBox(height: 16),

              // Reason
              _buildFloatingField(
                child: TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Leave',
                    prefixIcon:
                        Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter reason';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Document Upload
              _buildFloatingField(
                child: InkWell(
                  onTap: _pickDocument,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file_rounded,
                            color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _documentUrl ?? 'Upload Document (Optional)',
                            style: TextStyle(
                              color: _documentUrl != null
                                  ? const Color(0xFF1F2937)
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_documentUrl != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                setState(() => _documentUrl = null),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: const Color(0xFF10B981).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Leave Application',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return _buildFloatingField(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date != null
                          ? '${date.day}/${date.month}/${date.year}'
                          : 'Select Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? const Color(0xFF1F2937)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveHistory() {
    if (_leaveHistory.isEmpty) {
      return _buildFloatingCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No leave history',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return _buildFloatingCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            ..._leaveHistory.take(5).map((leave) => _buildHistoryItem(leave)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> leave) {
    final status = leave['status'] as String;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${leave['start_date']} to ${leave['end_date']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${leave['total_days']} days • ${leave['leave_type']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCard({Widget? child, Gradient? gradient}) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? Colors.white : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFloatingField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }
}
