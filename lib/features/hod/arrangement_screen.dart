import 'package:flutter/material.dart';
import '../../services/arrangement_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArrangementScreen extends StatefulWidget {
  const ArrangementScreen({super.key});

  @override
  State<ArrangementScreen> createState() => _ArrangementScreenState();
}

class _ArrangementScreenState extends State<ArrangementScreen> {
  final _arrangementService = ArrangementService();
  SupabaseClient get _supabase => Supabase.instance.client;

  List<Map<String, dynamic>> _teachersOnLeave = [];
  List<Map<String, dynamic>> _pendingArrangements = [];
  List<Map<String, dynamic>> _allTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final today = DateTime.now();
      final teachersOnLeave =
          await _arrangementService.getTeachersOnLeave(today);
      final pendingArrangements =
          await _arrangementService.getPendingArrangements(today);
      final allTeachers = await _supabase
          .from('teacher_details')
          .select()
          .eq('status', 'Active');

      if (mounted) {
        setState(() {
          _teachersOnLeave = teachersOnLeave;
          _pendingArrangements = pendingArrangements;
          _allTeachers = List<Map<String, dynamic>>.from(allTeachers);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading arrangement data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Teacher Arrangements',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teachers on Leave Today
                    _buildSectionHeader(
                      'Teachers on Leave Today',
                      Icons.event_busy,
                      Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildTeachersOnLeaveList(),

                    const SizedBox(height: 24),

                    // Pending Arrangements
                    _buildSectionHeader(
                      'Pending Arrangements',
                      Icons.assignment_late,
                      Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildPendingArrangementsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildTeachersOnLeaveList() {
    if (_teachersOnLeave.isEmpty) {
      return _buildEmptyCard('No teachers on leave today');
    }

    return Column(
      children: _teachersOnLeave.map((leave) {
        final teacherDetails =
            leave['teacher_details'] as Map<String, dynamic>?;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Text(
                  (teacherDetails?['name'] ?? 'T')[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacherDetails?['name'] ?? 'Unknown Teacher',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${leave['leave_type']} • ${leave['start_date']} to ${leave['end_date']}',
                      style: TextStyle(
                        fontSize: 13,
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'On Leave',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingArrangementsList() {
    if (_pendingArrangements.isEmpty) {
      return _buildEmptyCard('No pending arrangements');
    }

    return Column(
      children: _pendingArrangements.map((arrangement) {
        final originalTeacher =
            arrangement['original_teacher'] as Map<String, dynamic>?;
        final timetable = arrangement['timetable'] as Map<String, dynamic>?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Arrangement Needed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      originalTeacher?['name'] ?? 'Unknown Teacher',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.schedule,
                        '${timetable?['time_slot']} (${timetable?['start_time']} - ${timetable?['end_time']})'),
                    const SizedBox(height: 4),
                    _buildInfoRow(
                        Icons.book,
                        timetable?['subjects']?['subject_name'] ??
                            'Unknown Subject'),
                    const SizedBox(height: 4),
                    _buildInfoRow(
                        Icons.room, timetable?['room_number'] ?? 'TBA'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showAssignSubstituteDialog(arrangement),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Assign Substitute'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0891B2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignSubstituteDialog(Map<String, dynamic> arrangement) {
    String? selectedTeacherId;
    final notesController = TextEditingController();

    // Filter out teachers on leave
    final leaveTeacherIds = _teachersOnLeave
        .map((l) => l['teacher_id'] as String?)
        .whereType<String>()
        .toSet();

    final availableTeachers = _allTeachers
        .where((t) => !leaveTeacherIds.contains(t['teacher_id']))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign Substitute Teacher',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Teacher',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      items: availableTeachers.map((teacher) {
                        return DropdownMenuItem<String>(
                          value: teacher['teacher_id'],
                          child: Text(
                              '${teacher['name']} - ${teacher['department']}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedTeacherId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedTeacherId == null
                            ? null
                            : () async {
                                final success =
                                    await _arrangementService.assignSubstitute(
                                  arrangementId: arrangement['id'],
                                  substituteTeacherId: selectedTeacherId!,
                                  notes: notesController.text.isEmpty
                                      ? null
                                      : notesController.text,
                                  assignedBy: 'HOD',
                                );

                                if (success) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '✓ Substitute assigned successfully'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                  _loadData();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Failed to assign substitute'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0891B2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirm Assignment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
