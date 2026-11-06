import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../features/transport/screens/student_transport_screen.dart'
    as transport;

/// School-route entry point for a learner's transport record.
///
/// The identifier always comes from the authenticated user's school profile;
/// it is never accepted from a URL query parameter.
class SchoolStudentTransportScreen extends StatefulWidget {
  const SchoolStudentTransportScreen({super.key});

  @override
  State<SchoolStudentTransportScreen> createState() =>
      _SchoolStudentTransportScreenState();
}

class _SchoolStudentTransportScreenState
    extends State<SchoolStudentTransportScreen> {
  Map<String, dynamic>? _profile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final username = await AuthService().getCurrentUsername();
      if (username == null || username.isEmpty)
        throw StateError('No active user');
      final profile = await SchoolService().getSchoolStudentProfile(username);
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Transport')),
        body: Center(child: Text('Could not load your transport profile.')),
      );
    }
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final studentId = (profile['username'] ?? profile['id'] ?? '').toString();
    if (studentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Transport')),
        body: const Center(
            child: Text('No student profile is linked to this account.')),
      );
    }
    return transport.StudentTransportScreen(
      studentId: studentId,
      studentName: (profile['name'] ?? 'Student').toString(),
    );
  }
}
