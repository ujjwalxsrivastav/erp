import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

/// Student leave requests.
///
/// Students raise a leave application (dates, type, reason, document note) and
/// track its status. The class teacher of the student's class sees the pending
/// applications for their own classes and approves or rejects them with
/// remarks. Approving a leave marks the covered days `excused` in attendance.
class StudentLeaveScreen extends StatefulWidget {
  const StudentLeaveScreen({super.key});

  @override
  State<StudentLeaveScreen> createState() => _StudentLeaveScreenState();
}

class _StudentLeaveScreenState extends State<StudentLeaveScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();
  late final TabController _tabController;

  static const Color _ink = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);
  static const Color _rose = Color(0xFFE11D48);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFEF4444);

  bool _isLoading = true;
  bool _isStudent = false;
  String _username = '';
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _leaves = [];
  List<String> _teacherClasses = [];

  /// Every known class identity (id, "cls-10a", "class10", "Class 10-A")
  /// mapped to the class name shown in the UI. Leaves stored before the
  /// class refactor only carry a UUID, so the label has to be resolved.
  Map<String, String> _classNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final role = await _authService.getCurrentUserRole() ?? '';
    final username = await _authService.getCurrentUsername() ?? '';

    if (!mounted) return;
    setState(() {
      _username = username;
      _isStudent = role == 'student';
    });

    await _loadClassNames();

    if (_isStudent) {
      final profile = await _schoolService.getSchoolStudentProfile(username);
      if (!mounted) return;
      setState(() => _profile = profile);
    } else {
      final classes = await _schoolService.getClassTeacherClasses(username);
      if (!mounted) return;
      setState(() {
        _teacherClasses = classes
            .map((c) => c['name']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
      });
    }

    await _loadLeaves();
  }

  Future<void> _loadClassNames() async {
    final classes = await _schoolService.getSchoolClasses();
    final map = <String, String>{};
    for (final c in classes) {
      final name = c['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final id = c['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) map[id.toLowerCase()] = name;
      for (final alias in _schoolService.classAliases(
        classId: id,
        className: name,
      )) {
        map.putIfAbsent(alias, () => name);
      }
    }
    if (!mounted) return;
    setState(() => _classNames = map);
  }

  Future<void> _loadLeaves() async {
    setState(() => _isLoading = true);

    final leaves = _isStudent
        ? await _schoolService.getStudentLeaves(studentId: _username)
        : await _schoolService.getLeaveRequestsForClassTeacher(_username);

    if (!mounted) return;
    setState(() {
      _leaves = leaves;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _pending => _leaves
      .where((l) => (l['status']?.toString() ?? '') == 'pending')
      .toList();

  List<Map<String, dynamic>> get _reviewed => _leaves
      .where((l) => (l['status']?.toString() ?? '') != 'pending')
      .toList();

  // ===== APPLY (STUDENT) =====

  Future<void> _showApplyLeaveSheet() async {
    var leaveType = SchoolService.studentLeaveTypes.first;
    var startDate = DateTime.now().add(const Duration(days: 1));
    var endDate = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();
    final documentCtrl = TextEditingController();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final days = endDate.difference(startDate).inDays + 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.event_busy_outlined, color: _rose),
                        SizedBox(width: 8),
                        Text(
                          'Leave Application',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your application goes to the class teacher of your class for approval.',
                      style: TextStyle(fontSize: 12.5, color: _muted),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: leaveType,
                      decoration: InputDecoration(
                        labelText: 'Leave Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: SchoolService.studentLeaveTypes
                          .map((t) =>
                              DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setSheetState(
                          () => leaveType = v ?? leaveType),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _dateField(
                            label: 'From',
                            date: startDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: startDate,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 7)),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 120)),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  startDate = picked;
                                  if (endDate.isBefore(startDate)) {
                                    endDate = startDate;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dateField(
                            label: 'To',
                            date: endDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    endDate.isBefore(startDate) ? startDate : endDate,
                                firstDate: startDate,
                                lastDate:
                                    DateTime.now().add(const Duration(days: 120)),
                              );
                              if (picked != null) {
                                setSheetState(() => endDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$days ${days == 1 ? 'day' : 'days'} of leave',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _rose,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Explain why you need this leave...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: documentCtrl,
                      decoration: InputDecoration(
                        labelText: 'Supporting document (optional)',
                        hintText: 'e.g. Medical certificate submitted to class teacher',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                final reason = reasonCtrl.text.trim();
                                if (reason.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter a reason for the leave.'),
                                      backgroundColor: _red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                final ok = await _submitLeave(
                                  leaveType: leaveType,
                                  startDate: startDate,
                                  endDate: endDate,
                                  reason: reason,
                                  document: documentCtrl.text.trim(),
                                );
                                if (!ctx.mounted) return;
                                if (ok) {
                                  Navigator.pop(ctx);
                                } else {
                                  setSheetState(() => submitting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          submitting ? 'Submitting...' : 'Submit Application',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    reasonCtrl.dispose();
    documentCtrl.dispose();
  }

  Widget _dateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          _formatDate(date.toIso8601String().substring(0, 10)),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<bool> _submitLeave({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String document,
  }) async {
    final profile = _profile;
    final classId = profile?['class_id']?.toString() ?? '';
    final className = profile?['class_name']?.toString();

    try {
      await _schoolService.applyStudentLeave(
        studentId: profile?['id']?.toString() ?? _username,
        studentName: profile?['name']?.toString() ?? _username,
        classId: classId,
        startDate: startDate.toIso8601String().substring(0, 10),
        endDate: endDate.toIso8601String().substring(0, 10),
        leaveType: leaveType,
        reason: reason,
        documentUrl: document.isEmpty ? null : document,
        studentUsername: _username,
        className: className,
        appliedBy: _username,
        appliedByRole: 'student',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not submit the leave application. Please try again.'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Leave application submitted to your class teacher.'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadLeaves();
    return true;
  }

  // ===== REVIEW (CLASS TEACHER) =====

  Future<void> _showReviewDialog(Map<String, dynamic> leave,
      {required bool approve}) async {
    final remarksCtrl = TextEditingController(
      text: approve ? 'Approved by class teacher' : '',
    );
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                approve ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: approve ? _green : _red,
              ),
              const SizedBox(width: 8),
              Text(
                approve ? 'Approve Leave' : 'Reject Leave',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogDetail('Student', leave['student_name']?.toString() ?? '-'),
                _dialogDetail(
                  'Class',
                  _classLabel(leave),
                ),
                _dialogDetail('Type', leave['type']?.toString() ?? '-'),
                _dialogDetail(
                  'Dates',
                  '${_formatDate(leave['start_date']?.toString() ?? '')} → '
                  '${_formatDate(leave['end_date']?.toString() ?? '')}',
                ),
                _dialogDetail(
                  'Reason',
                  leave['reason']?.toString() ?? '-',
                ),
                if ((leave['document_url']?.toString() ?? '').isNotEmpty)
                  _dialogDetail('Document', leave['document_url'].toString()),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: approve
                        ? 'Remarks (optional)'
                        : 'Reason for rejection',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (approve)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Approving marks the covered school days as excused in attendance.',
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final remarks = remarksCtrl.text.trim();
                      if (!approve && remarks.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please state why the leave is rejected.'),
                            backgroundColor: _red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => submitting = true);
                      final ok = await _schoolService.reviewStudentLeave(
                        leaveId: leave['id']?.toString() ?? '',
                        status: approve ? 'approved' : 'rejected',
                        reviewedBy: _username,
                        reviewerName: _username,
                        remarks: remarks,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? (approve
                                  ? 'Leave approved and attendance marked excused.'
                                  : 'Leave rejected.')
                              : 'Could not save the review. Please try again.'),
                          backgroundColor: ok ? _green : _red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      if (ok) await _loadLeaves();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? _green : _red,
                foregroundColor: Colors.white,
              ),
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(approve ? 'Approve' : 'Reject'),
            ),
          ],
        ),
      ),
    );

    remarksCtrl.dispose();
  }

  Widget _dialogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== BUILD =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Leave Requests',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF881337), Color(0xFFBE123C), Color(0xFFFB7185)],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(86),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _isStudent
                      ? 'Apply for leave and track your class teacher’s decision'
                      : _teacherClasses.isEmpty
                          ? 'Review leave applications from your class students'
                          : 'Class teacher of ${_teacherClasses.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFFBE123C),
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    tabs: [
                      Tab(text: 'Pending (${_pending.length})'),
                      Tab(
                        text: _isStudent
                            ? 'History (${_reviewed.length})'
                            : 'Reviewed (${_reviewed.length})',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isStudent
          ? FloatingActionButton.extended(
              onPressed: _showApplyLeaveSheet,
              backgroundColor: _rose,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Apply for Leave',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: _isLoading
          ? _buildLoadingSkeleton()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pending, isPending: true),
                _buildList(_reviewed, isPending: false),
              ],
            ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 132,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool isPending}) {
    if (items.isEmpty) {
      final isTeacherWithoutClass = !_isStudent && _teacherClasses.isEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPending
                      ? Icons.event_available_outlined
                      : Icons.history_toggle_off,
                  size: 72,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  isTeacherWithoutClass
                      ? 'No class assigned to you'
                      : isPending
                          ? (_isStudent
                              ? 'No pending leave applications'
                              : 'No leave applications awaiting review')
                          : (_isStudent
                              ? 'No reviewed applications yet'
                              : 'Nothing reviewed yet'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    isTeacherWithoutClass
                        ? 'Only class teachers can approve or reject student leave requests.'
                        : _isStudent
                            ? 'Tap “Apply for Leave” to send an application to your class teacher.'
                            : 'Reviewed applications will appear here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ),
                if (_isStudent && isPending) ...[
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _showApplyLeaveSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Apply for Leave'),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaves,
      color: _rose,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildLeaveCard(items[index]),
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final status = leave['status']?.toString() ?? 'pending';
    final statusColor = _statusColor(status);
    final isPending = status == 'pending';
    final days = (leave['total_days'] as num?)?.toInt() ??
        _dayCountBetween(
          leave['start_date']?.toString() ?? '',
          leave['end_date']?.toString() ?? '',
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    leave['type']?.toString().toLowerCase().contains('medical') ==
                            true
                        ? Icons.medical_services_outlined
                        : Icons.event_busy_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave['type']?.toString() ?? 'Leave',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${leave['student_name'] ?? _username} • ${_classLabel(leave)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: _muted),
                      ),
                    ],
                  ),
                ),
                _statusChip(status, statusColor),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range_outlined, size: 15, color: _muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_formatDate(leave['start_date']?.toString() ?? '')} → '
                        '${_formatDate(leave['end_date']?.toString() ?? '')}'
                        '  •  $days ${days == 1 ? 'day' : 'days'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  leave['reason']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.35),
                ),
                if ((leave['document_url']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_file, size: 14, color: _muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          leave['document_url'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isPending &&
                    (leave['review_remarks']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teacher remarks',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          leave['review_remarks'].toString(),
                          style: const TextStyle(fontSize: 12, color: _ink),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isStudent && isPending) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showReviewDialog(leave, approve: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: const BorderSide(color: _red),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showReviewDialog(leave, approve: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    final label = status.isEmpty
        ? 'Pending'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return _green;
      case 'rejected':
        return _red;
      case 'cancelled':
        return _muted;
      default:
        return _amber;
    }
  }

  String _classLabel(Map<String, dynamic> leave) {
    final className = leave['class_name']?.toString().trim() ?? '';
    final classId = leave['class_id']?.toString().trim() ?? '';

    // Resolve through every known alias so a raw UUID or "cls-10a" becomes
    // the class name, and "Class 10-A" normalises to "Class 10".
    for (final alias in _schoolService.classAliases(
      classId: classId,
      className: className,
    )) {
      final resolved = _classNames[alias];
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }

    if (className.isNotEmpty) return className;
    final byId = _classNames[classId.toLowerCase()];
    if (byId != null && byId.isNotEmpty) return byId;
    return classId.isNotEmpty ? classId : 'Class not set';
  }

  int _dayCountBetween(String start, String end) {
    try {
      return DateTime.parse(end).difference(DateTime.parse(start)).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '-';
    try {
      final dt = DateTime.parse(value);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return value;
    }
  }
}
