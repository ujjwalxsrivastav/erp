import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = SchoolService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _username;
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
      if (username == null || username.isEmpty)
        throw StateError('No active user');
      final items = await _service.getNotificationsForUser(username: username);
      if (mounted)
        setState(() {
          _username = username;
          _items = items;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Could not load notifications.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: [
          TextButton(
              onPressed: _username == null
                  ? null
                  : () async {
                      await _service.markAllNotificationsRead(
                          username: _username!);
                      await _load();
                    },
              child: const Text('Mark all read')),
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                    ? const Center(child: Text('No notifications yet.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final unread = item['is_read'] != true;
                              return ListTile(
                                  title: Text(
                                      item['title']?.toString() ?? 'Notice',
                                      style: TextStyle(
                                          fontWeight: unread
                                              ? FontWeight.w700
                                              : FontWeight.w400)),
                                  subtitle:
                                      Text(item['body']?.toString() ?? ''),
                                  onTap: () async {
                                    final id = item['id']?.toString();
                                    if (id != null && unread) {
                                      await _service.markNotificationRead(
                                          notificationId: id);
                                      await _load();
                                    }
                                  });
                            })),
      );
}
