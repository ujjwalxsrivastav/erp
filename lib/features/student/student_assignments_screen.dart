import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/student_service.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  final String studentId;

  const StudentAssignmentsScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  final _studentService = StudentService();
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  String _filterSubject = 'All';
  List<String> _subjects = ['All'];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);

    try {
      final assignments =
          await _studentService.getStudentAssignments(widget.studentId);

      // Extract unique subjects
      final subjectSet = <String>{'All'};
      for (var assignment in assignments) {
        if (assignment['subjects'] != null) {
          subjectSet.add(assignment['subjects']['subject_name']);
        }
      }

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _subjects = subjectSet.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading assignments: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    if (_filterSubject == 'All') return _assignments;
    return _assignments.where((assignment) {
      if (assignment['subjects'] == null) return false;
      return assignment['subjects']['subject_name'] == _filterSubject;
    }).toList();
  }

  Future<void> _downloadFile(String? fileUrl, String title) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file attached to this assignment'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening: $title'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Color _getPriorityColor(DateTime? dueDate) {
    if (dueDate == null) return AppTheme.mediumGray;

    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) return AppTheme.error; // Overdue
    if (difference <= 2) return AppTheme.warning; // Due soon
    return AppTheme.success; // Plenty of time
  }

  String _getDueDateStatus(DateTime? dueDate) {
    if (dueDate == null) return 'No deadline';

    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) return 'Overdue';
    if (difference == 0) return 'Due today';
    if (difference == 1) return 'Due tomorrow';
    return 'Due in $difference days';
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
          child: Column(
            children: [
              _buildAppBar(),
              _buildFilterChips(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredAssignments.isEmpty
                        ? _buildEmptyState()
                        : _buildAssignmentsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: AppTheme.studentGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Assignments',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_filteredAssignments.length} assignments',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAssignments,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          final isSelected = subject == _filterSubject;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(subject),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filterSubject = subject);
              },
              backgroundColor: Colors.white,
              selectedColor: AppTheme.studentPrimary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.dark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              elevation: isSelected ? 4 : 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: AppTheme.lightGray,
          ),
          const SizedBox(height: 16),
          Text(
            'No assignments found',
            style: AppTheme.h3.copyWith(color: AppTheme.mediumGray),
          ),
          const SizedBox(height: 8),
          Text(
            _filterSubject == 'All'
                ? 'You have no pending assignments'
                : 'No assignments for $_filterSubject',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList() {
    return RefreshIndicator(
      onRefresh: _loadAssignments,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _filteredAssignments.length,
        itemBuilder: (context, index) {
          final assignment = _filteredAssignments[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAssignmentCard(assignment),
          );
        },
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final dueDate = assignment['due_date'] != null
        ? DateTime.parse(assignment['due_date'])
        : null;
    final priorityColor = _getPriorityColor(dueDate);
    final dueDateStatus = _getDueDateStatus(dueDate);
    final subjectName = assignment['subjects']?['subject_name'] ?? 'Unknown';
    final teacherName = assignment['teacher_details']?['name'] ?? 'Unknown';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with subject and status
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.studentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subjectName,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.studentPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: priorityColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: priorityColor),
                    const SizedBox(width: 4),
                    Text(
                      dueDateStatus,
                      style: AppTheme.caption.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            assignment['title'] ?? 'Untitled Assignment',
            style: AppTheme.h4.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: 8),

          // Description
          if (assignment['description'] != null &&
              assignment['description'].toString().isNotEmpty) ...[
            Text(
              assignment['description'],
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Teacher and due date info
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: AppTheme.mediumGray),
              const SizedBox(width: 4),
              Text(
                teacherName,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today, size: 16, color: AppTheme.mediumGray),
              const SizedBox(width: 4),
              Text(
                dueDate != null
                    ? DateFormat('MMM dd, yyyy').format(dueDate)
                    : 'No deadline',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
            ],
          ),

          // Download and Submit buttons
          if (assignment['file_url'] != null || assignment['id'] != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Download button
                if (assignment['file_url'] != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadFile(
                        assignment['file_url'],
                        assignment['title'] ?? 'Assignment',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.studentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text(
                        'Download',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                if (assignment['file_url'] != null && assignment['id'] != null)
                  const SizedBox(width: 12),

                // Submit button (only if assignment has ID and not overdue)
                if (assignment['id'] != null)
                  Expanded(
                    child: _buildSubmitButton(assignment, dueDate),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
      Map<String, dynamic> assignment, DateTime? dueDate) {
    final isOverdue = dueDate != null && DateTime.now().isAfter(dueDate);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _studentService.getSubmissionStatus(
        assignment['id'].toString(),
        widget.studentId,
      ),
      builder: (context, snapshot) {
        final hasSubmitted = snapshot.data != null;
        final isDisabled = isOverdue || hasSubmitted;

        return ElevatedButton.icon(
          onPressed: isDisabled ? null : () => _submitAssignment(assignment),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasSubmitted
                ? AppTheme.success
                : isOverdue
                    ? AppTheme.mediumGray
                    : AppTheme.warning,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: isDisabled ? 0 : 2,
            disabledBackgroundColor: AppTheme.lightGray,
            disabledForegroundColor: AppTheme.mediumGray,
          ),
          icon: Icon(
            hasSubmitted
                ? Icons.check_circle
                : isOverdue
                    ? Icons.lock
                    : Icons.upload,
            size: 20,
          ),
          label: Text(
            hasSubmitted
                ? 'Submitted'
                : isOverdue
                    ? 'Overdue'
                    : 'Submit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Future<void> _submitAssignment(Map<String, dynamic> assignment) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading assignment...'),
                  SizedBox(height: 8),
                  Text(
                    'Please wait while we compress and upload your file',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Submit assignment
      final success = await _studentService.submitAssignment(
        assignmentId: assignment['id'].toString(),
        studentId: widget.studentId,
        file: file,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        setState(() {}); // Refresh to show submitted status
      } else {
        throw Exception('Submission failed');
      }
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit assignment: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
