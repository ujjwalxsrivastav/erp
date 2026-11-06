import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_ai_service.dart';
import 'widgets/rag_chat_panel.dart';

/// Learner-only AI surface.  It intentionally renders one capability: chat.
/// Faculty drafting and assessment tools are not built into this widget.
class StudentAiScreen extends StatefulWidget {
  const StudentAiScreen({super.key});

  @override
  State<StudentAiScreen> createState() => _StudentAiScreenState();
}

class _StudentAiScreenState extends State<StudentAiScreen> {
  final _ai = SchoolAiService();
  String? _username;
  String? _liveRole;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final username = await AuthService().getCurrentUsername();
    final role = username == null ? null : await AuthService().getLiveUserRole(username);
    if (!mounted) return;
    if (username == null || username.isEmpty || !{'student', 'sstudent'}.contains(role)) {
      setState(() =>
          _error = 'This student assistant session could not be verified. Please sign in again.');
    } else {
      setState(() { _username = username; _liveRole = role; });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School Assistant')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
                'Ask about your school information. The assistant cannot access staff or other students\' records.'),
          ),
          Expanded(
            child: _username == null || _liveRole == null
                ? Center(child: Text(_error ?? 'Verifying your account…'))
                : RagChatPanel(
                    inputHint: 'Ask about school information or your records',
                    quickPrompts: const ['School timings', 'Academic calendar', 'My attendance', 'My homework'],
                    onSend: (question) => _ai.askRagAssistant(question: question, userRole: _liveRole == 'sstudent' ? 'student' : _liveRole!, username: _username!),
                  ),
          ),
        ],
      ),
    );
  }
}
