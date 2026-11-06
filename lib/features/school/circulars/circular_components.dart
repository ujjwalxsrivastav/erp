import 'package:flutter/material.dart';

class CircularCard extends StatelessWidget {
  const CircularCard(
      {super.key,
      required this.circular,
      this.onRead,
      this.onRetract,
      this.isRead = false});
  final Map<String, dynamic> circular;
  final VoidCallback? onRead;
  final VoidCallback? onRetract;
  final bool isRead;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onRead,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(circular['title']?.toString() ?? 'Notice',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16))),
                if (!isRead)
                  const Icon(Icons.circle, color: Color(0xFF7C3AED), size: 9),
                if (onRetract != null)
                  IconButton(
                      tooltip: 'Retract circular',
                      onPressed: onRetract,
                      icon: const Icon(Icons.delete_outline)),
              ]),
              Text(
                  '${circular['category'] ?? 'General'} • ${circular['target_audience'] ?? 'All'}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 8),
              Text(circular['content']?.toString() ?? ''),
              const SizedBox(height: 8),
              Text(circular['published_at']?.toString() ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ]),
          ),
        ),
      );
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => count <= 0
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: const BoxDecoration(
              color: Color(0xFFDC2626), shape: BoxShape.circle),
          child: Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)));
}

class NotificationFeedList extends StatelessWidget {
  const NotificationFeedList(
      {super.key, required this.items, required this.onRead});
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onRead;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const Center(child: Text('No notifications yet.'));
    return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final unread = item['is_read'] != true;
          final createdAt = item['created_at']?.toString() ?? '';
          return ListTile(
              onTap: () => onRead(item),
              leading: unread
                  ? const Icon(Icons.markunread, color: Color(0xFF7C3AED))
                  : const Icon(Icons.drafts_outlined),
              title: Text(item['title']?.toString() ?? 'Notice',
                  style: TextStyle(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w400)),
              subtitle: Text(item['body']?.toString() ?? ''),
              trailing: Text(
                  createdAt.length >= 10
                      ? createdAt.substring(0, 10)
                      : createdAt,
                  style: const TextStyle(fontSize: 11)));
        });
  }
}
