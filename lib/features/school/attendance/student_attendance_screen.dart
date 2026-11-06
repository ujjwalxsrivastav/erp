import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final _service = SchoolService();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  String _name = 'My Attendance';

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
      final results = await Future.wait([
        _service.getStudentAttendanceRecords(username),
        _service.getSchoolStudentProfile(username),
      ]);
      if (!mounted) return;
      setState(() {
        _records = results[0] as List<Map<String, dynamic>>;
        final profile = results[1] as Map<String, dynamic>?;
        _name = profile?['name']?.toString() ?? 'My Attendance';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your attendance records. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final counted = _records
        .where((r) => r['status'] != 'excused' && r['status'] != 'leave')
        .toList();
    final attended = counted
        .where((r) => r['status'] == 'present' || r['status'] == 'late')
        .length;
    final percent = counted.isEmpty ? null : attended / counted.length * 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _records.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text('No attendance records yet.')),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Card(
                              child: ListTile(
                                title: const Text('Attendance recorded'),
                                subtitle: Text(
                                  '${counted.length} attendance days',
                                ),
                                trailing: Text(
                                  percent == null
                                      ? '—'
                                      : '${percent.toStringAsFixed(1)}%',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final record in _records)
                              ListTile(
                                leading: Icon(_iconFor(record['status'])),
                                title: Text(_label(record['status'])),
                                subtitle: Text(
                                  record['date']?.toString() ?? '',
                                ),
                              ),
                          ],
                        ),
                ),
    );
  }

  IconData _iconFor(dynamic status) => switch (status?.toString()) {
        'present' => Icons.check_circle_outline,
        'late' => Icons.schedule,
        'absent' => Icons.cancel_outlined,
        'leave' || 'excused' => Icons.event_busy_outlined,
        _ => Icons.help_outline,
      };

  String _label(dynamic status) =>
      (status?.toString() ?? 'unmarked').replaceFirstMapped(
        RegExp(r'^[a-z]'),
        (m) => m.group(0)!.toUpperCase(),
      );
}
