import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/teacher_service.dart';

class CheckSubmissionsScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String teacherId;
  final String year;
  final String section;

  const CheckSubmissionsScreen({
    super.key,
    required this.subject,
    required this.teacherId,
    required this.year,
    required this.section,
  });

  @override
  State<CheckSubmissionsScreen> createState() => _CheckSubmissionsScreenState();
}

class _CheckSubmissionsScreenState extends State<CheckSubmissionsScreen> {
  final _teacherService = TeacherService();
  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic>? _selectedAssignment;
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoadingAssignments = true;
  bool _isLoadingSubmissions = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoadingAssignments = true);

    try {
      final assignments = await _teacherService.getTeacherAssignments(
        widget.teacherId,
        widget.year,
        widget.section,
      );

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _isLoadingAssignments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAssignments = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading assignments: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadSubmissions(Map<String, dynamic> assignment) async {
    setState(() {
      _selectedAssignment = assignment;
      _isLoadingSubmissions = true;
    });

    try {
      final submissions = await _teacherService.getAssignmentSubmissions(
        assignment['id'].toString(),
      );

      if (mounted) {
        setState(() {
          _submissions = submissions;
          _isLoadingSubmissions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSubmissions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading submissions: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(String? fileUrl, String studentName) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file attached'),
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
              content: Text('Opening submission from $studentName'),
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
              Expanded(
                child: _selectedAssignment == null
                    ? _buildAssignmentsList()
                    : _buildSubmissionsList(),
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
        gradient: LinearGradient(
          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_selectedAssignment != null) {
                setState(() {
                  _selectedAssignment = null;
                  _submissions = [];
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAssignment == null
                      ? 'Select Assignment'
                      : 'Submissions',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAssignment == null
                      ? '${_assignments.length} assignments'
                      : _selectedAssignment!['title'] ?? 'Assignment',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedAssignment == null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadAssignments,
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList() {
    if (_isLoadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_assignments.isEmpty) {
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
              'Create an assignment first',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildAssignmentCard(assignment),
        );
      },
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final dueDate = assignment['due_date'] != null
        ? DateTime.parse(assignment['due_date'])
        : null;

    return GlassCard(
      onTap: () => _loadSubmissions(assignment),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.assignment,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment['title'] ?? 'Untitled',
                  style: AppTheme.h4.copyWith(color: AppTheme.dark),
                ),
                const SizedBox(height: 4),
                if (dueDate != null)
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.mediumGray,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppTheme.mediumGray,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    if (_isLoadingSubmissions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: AppTheme.lightGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No submissions yet',
              style: AppTheme.h3.copyWith(color: AppTheme.mediumGray),
            ),
            const SizedBox(height: 8),
            Text(
              'Students haven\'t submitted their work',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _submissions.length,
      itemBuilder: (context, index) {
        final submission = _submissions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSubmissionCard(submission),
        );
      },
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final submittedAt = submission['submitted_at'] != null
        ? DateTime.parse(submission['submitted_at'])
        : null;
    final studentName =
        submission['student_details']?['name'] ?? 'Unknown Student';
    final studentId = submission['student_id'] ?? '';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.studentPrimary.withOpacity(0.1),
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.studentPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: AppTheme.h4.copyWith(color: AppTheme.dark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $studentId',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(
                      'Submitted',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: AppTheme.mediumGray),
              const SizedBox(width: 4),
              Text(
                submittedAt != null
                    ? DateFormat('MMM dd, yyyy • hh:mm a').format(submittedAt)
                    : 'Unknown time',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadFile(
                submission['file_url'],
                studentName,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
              ),
              icon: const Icon(Icons.download, size: 20),
              label: const Text(
                'Download Submission',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
