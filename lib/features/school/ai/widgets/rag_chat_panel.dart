import 'package:flutter/material.dart';

class RagChatPanel extends StatefulWidget {
  const RagChatPanel({super.key, required this.onSend, required this.quickPrompts, this.inputHint = 'Ask a question'});
  final Future<String> Function(String question) onSend;
  final List<String> quickPrompts;
  final String inputHint;

  @override
  State<RagChatPanel> createState() => _RagChatPanelState();
}

class _RagChatPanelState extends State<RagChatPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <(String, bool)>[];
  String? _error;
  bool _sending = false;

  Future<void> _send([String? prompt]) async {
    final question = (prompt ?? _controller.text).trim();
    if (question.isEmpty || _sending) return;
    _controller.clear();
    setState(() { _messages.add((question, true)); _sending = true; _error = null; });
    try {
      final answer = await widget.onSend(question);
      if (mounted) setState(() => _messages.add((answer, false)));
    } catch (_) {
      if (mounted) setState(() => _error = 'AI is unavailable right now. Please try again in a few minutes.');
    } finally {
      if (mounted) setState(() => _sending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() { _controller.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    if (widget.quickPrompts.isNotEmpty)
      SizedBox(height: 48, child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12), scrollDirection: Axis.horizontal,
        itemCount: widget.quickPrompts.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(label: Text(widget.quickPrompts[i], style: const TextStyle(fontSize: 11)), onPressed: _sending ? null : () => _send(widget.quickPrompts[i])),
      )),
    const Divider(height: 1),
    Expanded(child: _messages.isEmpty
        ? const Center(child: Text('Ask a question to start a chat.'))
        : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(16), itemCount: _messages.length,
            itemBuilder: (context, i) {
              final (text, isUser) = _messages[i];
              return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(margin: const EdgeInsets.only(bottom: 12), constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Text(text, style: TextStyle(color: isUser ? Theme.of(context).colorScheme.onPrimary : null)),
                ));
            })),
    if (_error != null) AiErrorState(message: _error!),
    if (_sending) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)),
    SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      Expanded(child: TextField(controller: _controller, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: widget.inputHint, border: const OutlineInputBorder()))),
      IconButton(onPressed: _sending ? null : () => _send(), icon: const Icon(Icons.send)),
    ]))),
  ]);
}

class AiErrorState extends StatelessWidget {
  const AiErrorState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
}
