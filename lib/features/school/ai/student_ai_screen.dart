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
                    inputHint: 'How can I help you today?',
                    llmAvailable: SchoolAiService.isLlmConfigured,
                    suggestions: const [
                      AiChatSuggestion(
                        label: 'School timings',
                        prompt: 'School timings',
                        icon: Icons.schedule_outlined,
                        dummyReply: 'School runs Monday to Friday:\n'
                            '• Assembly: 7:50 – 8:15 AM\n'
                            '• Classes: 8:15 AM – 2:15 PM\n'
                            '• Lunch break: 11:00 – 11:35 AM\n\n'
                            'Clubs and remedial classes run after 2:30 PM.',
                      ),
                      AiChatSuggestion(
                        label: 'Academic calendar',
                        prompt: 'Academic calendar',
                        icon: Icons.calendar_today_outlined,
                        dummyReply: 'Key dates for this session:\n'
                            '• Unit Test 1: 11 – 16 May 2026\n'
                            '• Summer break: 25 May – 30 June 2026\n'
                            '• Half-yearly exams: 14 – 26 September 2026\n'
                            '• Annual exams: 15 February – 10 March 2027',
                      ),
                      AiChatSuggestion(
                        label: 'My attendance',
                        prompt: 'My attendance',
                        icon: Icons.fact_check_outlined,
                        dummyReply: 'Your attendance this term is 92% (demo data). Open '
                            'the Attendance tab for the subject-wise breakdown and '
                            'leave records.',
                      ),
                      AiChatSuggestion(
                        label: 'My homework',
                        prompt: 'My homework',
                        icon: Icons.menu_book_outlined,
                        dummyReply: 'You have 3 pending homework items (demo data). Open '
                            'the Homework tab to see the questions, attachments and '
                            'due dates.',
                      ),
                    ],
                    onSend: (question) => _ai.askRagAssistant(question: question, userRole: _liveRole == 'sstudent' ? 'student' : _liveRole!, username: _username!),
                  ),
          ),
        ],
      ),
    );
  }
}
