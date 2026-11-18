import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/auth_service.dart';

/// Placeholder landing page for the school `counsellor` role.
///
/// The full counsellor workspace (assigned admission enquiries, follow-ups,
/// conversion) is not built yet — this keeps the role signable-in while the
/// allotment engine assigns applications behind the scenes.
class SchoolCounsellorDashboard extends StatelessWidget {
  const SchoolCounsellorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Counsellor Workspace',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            Text('Admission counselling desk',
                style: TextStyle(fontSize: 11.5, color: Colors.white70)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF14B8A6)],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0FDFA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        size: 42, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your workspace is being set up',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New admission applications are allotted to counsellors in rotation. '
                    'Your assigned enquiries will appear here once the counsellor desk is enabled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, color: Color(0xFF64748B), height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'For now, the school office can see which applications are allotted to you.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
