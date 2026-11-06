import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

class StudentReportCardScreen extends StatefulWidget {
  const StudentReportCardScreen({super.key});

  @override
  State<StudentReportCardScreen> createState() =>
      _StudentReportCardScreenState();
}

class _StudentReportCardScreenState extends State<StudentReportCardScreen> {
  final _service = SchoolService();
  List<Map<String, dynamic>> _marks = [];
  bool _loading = true;
  String? _error;

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
      final username = await AuthService().getCurrentUsername();
      if (username == null || username.isEmpty) {
        throw StateError('Your session could not be verified.');
      }
      final marks = await _service.getStudentMarks(username);
      if (mounted)
        setState(() {
          _marks = marks;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Could not load your report card. Please retry.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Report Card'), actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh)),
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _marks.isEmpty
                    ? const Center(
                        child: Text('No published marks are available yet.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final mark in _marks)
                            Card(
                                child: ListTile(
                              title: Text((mark['subject_name'] ??
                                      mark['subject'] ??
                                      'Subject')
                                  .toString()),
                              subtitle: Text(
                                  (mark['exam_type'] ?? 'Exam').toString()),
                              trailing: Text(
                                  '${mark['marks_obtained'] ?? mark['obtained_marks'] ?? '—'} / ${mark['total_marks'] ?? mark['max_marks'] ?? '—'}'),
                            )),
                        ],
                      ),
      );
}
