import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_ai_service.dart';

/// Learner-only AI surface.  It intentionally renders one capability: chat.
/// Faculty drafting and assessment tools are not built into this widget.
class StudentAiScreen extends StatefulWidget {
  const StudentAiScreen({super.key});

  @override
  State<StudentAiScreen> createState() => _StudentAiScreenState();
}

class _StudentAiScreenState extends State<StudentAiScreen> {
  final _input = TextEditingController();
  final _ai = SchoolAiService();
  final _messages = <_ChatMessage>[];
  bool _sending = false;
  String? _username;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final username = await AuthService().getCurrentUsername();
    if (!mounted) return;
    if (username == null || username.isEmpty) {
      setState(() =>
          _error = 'Your session could not be verified. Please sign in again.');
    } else {
      setState(() => _username = username);
    }
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    final username = _username;
    if (question.isEmpty || username == null || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(question, true));
      _input.clear();
      _sending = true;
      _error = null;
    });
    try {
      final answer = await _ai.askRagAssistant(
        question: question,
        userRole: 'student',
        username: username,
      );
      if (mounted) setState(() => _messages.add(_ChatMessage(answer, false)));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'AI is unavailable right now. Please try again in a few minutes.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
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
            child: _messages.isEmpty
                ? const Center(child: Text('Ask a question to start a chat.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Card(
                          color: message.isUser
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(message.text)),
                        ),
                      );
                    },
                  ),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _input,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                            hintText: 'Type your question'))),
                IconButton(
                    onPressed: _sending || _username == null ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage(this.text, this.isUser);
  final String text;
  final bool isUser;
}
