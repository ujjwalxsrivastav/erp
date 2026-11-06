import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_discipline_service.dart';
import '../../../services/school_service.dart';

class StudentDisciplineScreen extends StatefulWidget {
  const StudentDisciplineScreen({super.key});

  @override
  State<StudentDisciplineScreen> createState() => _StudentDisciplineScreenState();
}

class _StudentDisciplineScreenState extends State<StudentDisciplineScreen> {
  final _service = SchoolDisciplineService();
  final _school = SchoolService();
  String _username = '';
  String _role = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _child;
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _incidents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _username = await AuthService().getCurrentUsername() ?? '';
      _role = (await AuthService().getLiveUserRole(_username) ?? '').toLowerCase();
      final parent = _role == 'parent' || _role == 'sparent';
      if (parent) {
        _children = await _school.getParentChildren(_username);
        _child ??= _children.isEmpty ? null : _children.first;
      }
      final studentUsername = parent ? (_child?['username']?.toString() ?? '') : _username;
      if (studentUsername.isEmpty) {
        _notices = [];
        _incidents = [];
      } else {
        _notices = await _service.getMyDisciplineNotices(username: _username, role: _role, studentUsername: studentUsername);
        _incidents = await _service.getMyDisciplineIncidents(username: _username, studentUsername: studentUsername);
      }
    } catch (e) {
      _error = 'Discipline notices could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _acknowledge(Map<String, dynamic> notice) async {
    try {
      await _service.acknowledgeDisciplineNotice(noticeId: notice['id'].toString());
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not acknowledge this notice.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discipline Notices'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_role == 'parent' || _role == 'sparent')
                        DropdownButtonFormField<Map<String, dynamic>>(
                          initialValue: _child,
                          decoration: const InputDecoration(labelText: 'Linked child', border: OutlineInputBorder()),
                          items: _children.map((child) => DropdownMenuItem(value: child, child: Text(child['name']?.toString() ?? child['username']?.toString() ?? 'Student'))).toList(),
                          onChanged: (child) async { _child = child; await _load(); },
                        ),
                      const SizedBox(height: 16),
                      Text('Notices (${_notices.length})', style: Theme.of(context).textTheme.titleMedium),
                      if (_notices.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('No discipline notices yet.')),
                      ..._notices.map((notice) => NoticeCard(notice: notice, onAcknowledge: () => _acknowledge(notice))),
                      const SizedBox(height: 18),
                      Text('Incident summaries (${_incidents.length})', style: Theme.of(context).textTheme.titleMedium),
                      if (_incidents.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('No incident records.')),
                      ..._incidents.map((incident) => IncidentSummaryCard(incident: incident)),
                    ],
                  ),
                ),
    );
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice, required this.onAcknowledge});
  final Map<String, dynamic> notice;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final read = notice['parent_read'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(notice['notice_title']?.toString() ?? 'Discipline notice', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(notice['notice_body']?.toString() ?? ''),
          if (notice['scheduled_meeting_date'] != null) ...[
            const SizedBox(height: 8),
            Text('Meeting: ${notice['scheduled_meeting_date']}'),
          ],
          Align(alignment: Alignment.centerRight, child: read ? const Chip(label: Text('Acknowledged')) : TextButton(onPressed: onAcknowledge, child: const Text('Acknowledge'))),
        ]),
      ),
    );
  }
}

class IncidentSummaryCard extends StatelessWidget {
  const IncidentSummaryCard({super.key, required this.incident});
  final Map<String, dynamic> incident;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text(incident['category']?.toString() ?? 'Incident'),
          subtitle: Text('${incident['incident_date'] ?? ''} · ${incident['status'] ?? 'Recorded'}\n${incident['description'] ?? ''}'),
          isThreeLine: true,
        ),
      );
}
