import 'dart:math' as math;

import 'package:flutter/material.dart';

const _kBlue = Color(0xFF2563EB);
const _kBorder = Color(0xFFE3E6EB);
const _kAssistantBg = Color(0xFFF1F5FF);

/// A single starter prompt shown under the composer.
class AiChatSuggestion {
  const AiChatSuggestion({
    required this.label,
    required this.prompt,
    required this.dummyReply,
    this.icon,
  });

  final String label;
  final String prompt;
  final String dummyReply;
  final IconData? icon;
}

class RagChatPanel extends StatefulWidget {
  const RagChatPanel({
    super.key,
    required this.onSend,
    this.suggestions = const [],
    this.inputHint = 'How can I help you today?',
    this.greeting = 'Ask me anything',
    this.llmAvailable = true,
  });

  final Future<String> Function(String question) onSend;
  final List<AiChatSuggestion> suggestions;
  final String inputHint;
  final String greeting;

  /// When false, the panel skips the LLM call and answers with a dummy reply.
  final bool llmAvailable;

  @override
  State<RagChatPanel> createState() => _RagChatPanelState();
}

class _RagChatPanelState extends State<RagChatPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _messages = <(String, bool)>[];
  String? _error;
  bool _sending = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  Future<void> _send([String? prompt]) async {
    final question = (prompt ?? _controller.text).trim();
    if (question.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add((question, true));
      _sending = true;
      _error = null;
    });
    try {
      final answer = widget.llmAvailable
          ? await widget.onSend(question)
          : _dummyReply(question);
      if (mounted) setState(() => _messages.add((answer, false)));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'AI is unavailable right now. Please try again in a few minutes.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _dummyReply(String question) {
    final q = question.trim().toLowerCase();
    for (final s in widget.suggestions) {
      if (s.prompt.trim().toLowerCase() == q || s.label.trim().toLowerCase() == q) {
        return s.dummyReply;
      }
    }
    return "I'm running in offline demo mode right now, so I can't answer that "
        'question yet. Pick one of the suggestions below and I\'ll show you '
        'what the assistant can do.';
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _messages.isEmpty;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(child: isEmpty ? _buildWelcome() : _buildMessageList()),
          if (!isEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) AiErrorState(message: _error!),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _buildComposer(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 26, color: _kBlue),
              const SizedBox(height: 14),
              Text(
                widget.greeting,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.25,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFF1C1F26),
                ),
              ),
              const SizedBox(height: 26),
              _buildComposer(),
              if (widget.suggestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildSuggestions(),
              ],
              if (!widget.llmAvailable) ...[
                const SizedBox(height: 20),
                Text(
                  'Offline demo mode — replies are placeholder messages.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final suggestion in widget.suggestions)
          _SuggestionChip(
            suggestion: suggestion,
            onTap: _sending ? null : () => _send(suggestion.prompt),
          ),
      ],
    );
  }

  Widget _buildComposer() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? const Color(0x262563EB)
                : const Color(0x14000000),
            blurRadius: _focused ? 22 : 16,
            spreadRadius: _focused ? 1 : 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF1C1F26),
              ),
              decoration: InputDecoration(
                hintText: widget.inputHint,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9AA1AC),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final enabled = value.text.trim().isNotEmpty && !_sending;
              return GestureDetector(
                onTap: enabled ? () => _send() : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled ? _kBlue : const Color(0xFFE6EAF1),
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          size: 19,
                          color: enabled ? Colors.white : const Color(0xFFAAB3C0),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final count = _messages.length + (_sending ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i >= _messages.length) return _buildTyping();
        final (text, isUser) = _messages[i];
        return _buildBubble(text, isUser);
      },
    );
  }

  Widget _buildBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.78, 560),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? _kBlue : _kAssistantBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: isUser ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _kAssistantBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          ),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.suggestion, required this.onTap});

  final AiChatSuggestion suggestion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suggestion.icon != null) ...[
                Icon(suggestion.icon, size: 14, color: const Color(0xFF5B6472)),
                const SizedBox(width: 6),
              ],
              Text(
                suggestion.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF39414D),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiErrorState extends StatelessWidget {
  const AiErrorState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
        ),
      );
}
