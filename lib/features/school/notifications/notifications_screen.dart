import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../circulars/circular_components.dart';

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
  String? _role;
  String? _selectedStudent;
  List<Map<String, dynamic>> _children = [];
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
      final role = await AuthService().getLiveUserRole(username);
      if (role == null || role.isEmpty) throw StateError('No verified role');
      final normalizedRole = role == 'sparent' ? 'parent' : role;
      if (normalizedRole == 'parent' && _children.isEmpty) {
        _children = await _service.getParentChildren(username);
        _selectedStudent ??= _children.isEmpty
            ? null
            : _children.first['username']?.toString() ??
                _children.first['id']?.toString();
      }
      final items = await _service.getNotificationsForUser(
          username: username,
          role: role,
          studentUsername:
              normalizedRole == 'parent' ? _selectedStudent : null);
      if (mounted)
        setState(() {
          _username = username;
          _role = normalizedRole;
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
        appBar: AppBar(
            title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications'),
                  Text(
                      'In-app only • SMS, WhatsApp and push are not configured',
                      style: TextStyle(fontSize: 10))
                ]),
            actions: [
              if (_role == 'parent' && _children.isNotEmpty)
                DropdownButton<String>(
                  value: _selectedStudent,
                  hint: const Text('Child',
                      style: TextStyle(color: Colors.white)),
                  dropdownColor: Colors.white,
                  items: _children
                      .map((child) {
                        final username = child['username']?.toString() ??
                            child['id']?.toString() ??
                            '';
                        final name = child['name']?.toString() ??
                            child['student_name']?.toString() ??
                            username;
                        return DropdownMenuItem(
                            value: username, child: Text(name));
                      })
                      .where((item) => item.value?.isNotEmpty == true)
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedStudent = value);
                    _load();
                  },
                ),
              Stack(alignment: Alignment.topRight, children: [
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.notifications_outlined)),
                UnreadBadge(
                    count:
                        _items.where((item) => item['is_read'] != true).length),
              ]),
              TextButton(
                  onPressed: _username == null
                      ? null
                      : () async {
                          await _service.markAllNotificationsRead(
                              username: _username!,
                              studentUsername:
                                  _role == 'parent' ? _selectedStudent : null);
                          await _load();
                        },
                  child: Text({'admin', 'sadmin', 'principal', 'superadmin'}
                          .contains(_role)
                      ? 'Mark my alerts read'
                      : 'Mark all read')),
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                    ? const Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.notifications_none, size: 44),
                        SizedBox(height: 8),
                        Text('No notifications yet.'),
                        Text(
                            'In-app notifications only. SMS, WhatsApp and push delivery are not configured.',
                            textAlign: TextAlign.center)
                      ]))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: Column(children: [
                          if ({'admin', 'sadmin', 'principal', 'superadmin'}
                              .contains(_role))
                            const ListTile(
                                leading: Icon(Icons.security),
                                title: Text(
                                    'Security denial alerts are unavailable because the current audit log does not record denied attempts.')),
                          Expanded(
                              child: NotificationFeedList(
                            items: _items,
                            onRead: (item) async {
                              final id = item['id']?.toString();
                              final isAdmin = {
                                'admin',
                                'sadmin',
                                'principal',
                                'superadmin'
                              }.contains(_role);
                              if (id != null &&
                                  item['is_read'] != true &&
                                  (!isAdmin ||
                                      item['user_id']?.toString() ==
                                          _username)) {
                                await _service.markNotificationRead(
                                    notificationId: id);
                                await _load();
                              }
                            },
                          )),
                        ]),
                      ),
      );
}
