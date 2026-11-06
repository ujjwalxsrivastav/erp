import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import 'widgets/homework_components.dart';

/// A student's homework diary, scoped to the class resolved from their account.
class StudentHomeworkScreen extends StatefulWidget {
  const StudentHomeworkScreen({super.key});

  @override
  State<StudentHomeworkScreen> createState() => _StudentHomeworkScreenState();
}

class _StudentHomeworkScreenState extends State<StudentHomeworkScreen> {
  final _auth = AuthService();
  final _school = SchoolService();
  bool _loading = true;
  String? _error;
  String _studentUsername = '';
  bool _isParent = false;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _homework = [];
  Map<String, Map<String, dynamic>> _submissions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final username = await _auth.getCurrentUsername() ?? '';
      final role = await _auth.getCurrentUserRole() ?? '';
      final isParent = role == 'parent' || role == 'sparent';
      final children = isParent && username.isNotEmpty
          ? await _school.getParentChildren(username)
          : <Map<String, dynamic>>[];
      final selected = isParent
          ? (children.isEmpty ? null : children.first)
          : await _school.getSchoolStudentProfile(username);
      final studentUsername = selected?['username']?.toString() ?? '';
      final homework = await _school.getHomeworkForStudent(
        studentUsername: studentUsername,
      );
      final rows = studentUsername.isEmpty
          ? <Map<String, dynamic>>[]
          : await _school.getHomeworkSubmissions(
              studentUsername: studentUsername,
            );
      if (!mounted) return;
      setState(() {
        _studentUsername = studentUsername;
        _isParent = isParent;
        _children = children;
        _profile = selected;
        _homework = homework;
        _submissions = {
          for (final row in rows)
            if (row['homework_id'] != null) row['homework_id'].toString(): row,
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Homework could not be loaded. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isLate(Map<String, dynamic> homework) {
    if (_submissions.containsKey(homework['id']?.toString())) return false;
    final raw = homework['due_date']?.toString();
    if (raw == null || raw.isEmpty) return false;
    final due = DateTime.tryParse(raw);
    if (due == null) return false;
    final dueDay = DateTime(due.year, due.month, due.day);
    final today = DateTime.now();
    return dueDay.isBefore(DateTime(today.year, today.month, today.day));
  }

  Future<void> _submitWork(Map<String, dynamic> homework) async {
    if (_isParent) return;
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit homework'),
        content: TextField(
          controller: note,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Your work',
            hintText: 'Write your answer or submission note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (accepted != true || note.text.trim().isEmpty) {
      note.dispose();
      return;
    }
    bool ok;
    try {
      ok = await _school.submitHomework(
        homeworkId: homework['id'].toString(),
        studentUsername: _studentUsername,
        studentId: _profile?['id']?.toString(),
        studentName: _profile?['name']?.toString(),
        note: note.text,
      );
    } catch (_) {
      ok = false;
    }
    note.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Submission recorded.' : 'Submission failed. Try again.')),
    );
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final className = _profile?['class_name']?.toString() ?? '';
    final section = _profile?['section']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Homework'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isParent && _children.length > 1)
                        DropdownButtonFormField<String>(
                          initialValue: _studentUsername,
                          decoration: const InputDecoration(
                            labelText: 'Child',
                            border: OutlineInputBorder(),
                          ),
                          items: _children
                              .map((child) => DropdownMenuItem(
                                    value: child['username']?.toString(),
                                    child: Text(child['name']?.toString() ??
                                        child['username']?.toString() ??
                                        'Student'),
                                  ))
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            final child = _children.firstWhere(
                              (row) => row['username']?.toString() == value,
                            );
                            final work = await _school.getHomeworkForStudent(
                              studentUsername: value,
                            );
                            final submissions =
                                await _school.getHomeworkSubmissions(
                              studentUsername: value,
                            );
                            if (!mounted) return;
                            setState(() {
                              _studentUsername = value;
                              _profile = child;
                              _homework = work;
                              _submissions = {
                                for (final row in submissions)
                                  if (row['homework_id'] != null)
                                    row['homework_id'].toString(): row,
                              };
                            });
                          },
                        ),
                      const Icon(Icons.cloud_off, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (className.isNotEmpty || section.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            [className, section]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      if (_studentUsername.isEmpty || _profile == null)
                        const _EmptyMessage(
                          icon: Icons.person_search,
                          message:
                              'Student class information is not available.',
                        )
                      else if (_homework.isEmpty)
                        const _EmptyMessage(
                          icon: Icons.assignment_outlined,
                          message:
                              'No homework has been assigned to your class.',
                        )
                      else
                        ..._homework.map(_homeworkCard),
                    ],
                  ),
                ),
    );
  }

  Widget _homeworkCard(Map<String, dynamic> homework) {
    final id = homework['id']?.toString() ?? '';
    final submission = _submissions[id];
    final late = _isLate(homework);
    final due = homework['due_date']?.toString();
    final status = submission != null
        ? (submission['status']?.toString() == 'graded'
            ? 'Graded'
            : 'Submitted')
        : late
            ? 'Late'
            : 'Missing';
    final color = submission != null
        ? Colors.green
        : late
            ? Colors.red
            : Colors.orange;
    return HomeworkCard(
      title: homework['title']?.toString() ?? 'Homework',
      status: status,
      statusColor: color,
      children: [
        if ((homework['subject']?.toString() ?? '').isNotEmpty)
          Text(homework['subject'].toString()),
        if ((homework['description']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(homework['description'].toString()),
        ],
        const SizedBox(height: 8),
        Text('Due: ${due ?? 'Not specified'}'),
        if (submission != null) ...[
          if ((submission['note']?.toString() ?? '').isNotEmpty)
            Text('Your work: ${submission['note']}'),
          GradeFeedbackPanel(
            grade: submission['marks']?.toString(),
            feedback: submission['teacher_feedback']?.toString(),
          ),
        ] else if (!_isParent)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () => _submitWork(homework),
              child: const Text('Submit work'),
            ),
          ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      );
}
