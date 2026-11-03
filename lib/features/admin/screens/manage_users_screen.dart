import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/user_management_service.dart';

/// Admin — Manage Users.
///
/// Lists every login account in the `users` table with per-role
/// counts, search + role filters, resolved display names (from
/// student_details / teacher_details) and role changes.
/// The users table has no status/active column, so there is no
/// activate/deactivate action here.
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _service = UserManagementService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  Map<String, int> _roleCounts = {'total': 0};
  String _roleFilter = 'all';
  String _search = '';

  static const Map<String, Color> _roleColors = {
    'student': AppTheme.studentPrimary,
    'teacher': AppTheme.teacherPrimary,
    'admin': AppTheme.adminPrimary,
    'staff': AppTheme.accentTeal,
    'HR': AppTheme.accentPink,
    'hod': AppTheme.accentOrange,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getAllUsers(),
      _service.getRoleCounts(),
    ]);
    if (!mounted) return;
    setState(() {
      _users = results[0] as List<Map<String, dynamic>>;
      _roleCounts = results[1] as Map<String, int>;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    return _users.where((u) {
      if (_roleFilter != 'all' && u['role'] != _roleFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        final name = (u['display_name'] ?? '').toString().toLowerCase();
        if (!username.contains(q) && !name.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Color _roleColor(String role) => _roleColors[role] ?? AppTheme.mediumGray;

  String _initials(Map<String, dynamic> user) {
    final name = (user['display_name'] ?? user['username'] ?? '')
        .toString()
        .trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final username = user['username'] as String;
    final current = user['role'] as String;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change role — $username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRoles.all.map((role) {
            return RadioListTile<String>(
              value: role,
              groupValue: current,
              title: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _roleColor(role),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(UserRoles.label(role)),
                ],
              ),
              onChanged: (v) => Navigator.pop(ctx, v),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked == null || picked == current || !mounted) return;

    final ok = await _service.updateUserRole(username, picked);
    if (!mounted) return;
    if (ok) {
      setState(() {
        user['role'] = picked;
        _roleCounts[current] = (_roleCounts[current] ?? 1) - 1;
        _roleCounts[picked] = (_roleCounts[picked] ?? 0) + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$username is now ${UserRoles.label(picked)}'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Role change failed. Please try again.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildFilters(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.adminPrimary),
                      )
                    : RefreshIndicator(
                        color: AppTheme.adminPrimary,
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? ListView(
                                children: [_buildEmptyState()],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  AppTheme.md,
                                  AppTheme.sm,
                                  AppTheme.md,
                                  AppTheme.lg,
                                ),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) =>
                                    _buildUserCard(_filtered[i]),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppTheme.md,
        AppTheme.md,
        AppTheme.md,
        AppTheme.sm,
      ),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        gradient: AppTheme.adminGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Text(
                'Manage Users',
                style: AppTheme.h4.copyWith(color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Text(
                  '${_roleCounts['total'] ?? 0} accounts',
                  style: AppTheme.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Every login account, its role and the person behind it.',
            style: AppTheme.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppTheme.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRoles.all.map((role) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      UserRoles.label(role),
                      style:
                          AppTheme.caption.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_roleCounts[role] ?? 0}',
                      style: AppTheme.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.md,
        AppTheme.sm,
        AppTheme.md,
        AppTheme.sm,
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search username or name…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                borderSide: BorderSide(color: AppTheme.extraLightGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                borderSide: BorderSide(color: AppTheme.extraLightGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                borderSide: const BorderSide(color: AppTheme.adminPrimary),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All'),
                ...UserRoles.all.map(
                  (r) => _filterChip(r, UserRoles.label(r)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _roleFilter == value;
    final color =
        value == 'all' ? AppTheme.adminPrimary : _roleColor(value);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _roleFilter = value),
        selectedColor: color.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? color : AppTheme.mediumGray,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: selected ? color : AppTheme.extraLightGray),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    final color = _roleColor(role);
    final name = (user['display_name'] ?? '').toString();
    final detail = (user['detail'] ?? '').toString();
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.12),
            child: Text(
              _initials(user),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : user['username'].toString(),
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user['username']}',
                  style:
                      AppTheme.caption.copyWith(color: AppTheme.mediumGray),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style:
                        AppTheme.caption.copyWith(color: AppTheme.lightGray),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              UserRoles.label(role),
              style: AppTheme.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded,
                color: AppTheme.adminPrimary),
            tooltip: 'Change role',
            onPressed: () => _changeRole(user),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 56, color: AppTheme.lightGray),
          const SizedBox(height: AppTheme.md),
          Text(
            'No users found',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search or role filter.',
            style: AppTheme.caption.copyWith(color: AppTheme.lightGray),
          ),
        ],
      ),
    );
  }
}
