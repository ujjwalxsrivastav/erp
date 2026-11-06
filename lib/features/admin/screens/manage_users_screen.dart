import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../services/auth_service.dart';
import '../services/user_management_service.dart';

/// Admin — Manage Users.
///
/// Lists every login account filtered by institution (school / college), its
/// role and the person's name. Names come from school_students,
/// teacher_details and staff; accounts without a profile show their user ID.
class ManageUsersScreen extends StatefulWidget {
  final String initialInstitution;

  const ManageUsersScreen({super.key, this.initialInstitution = 'school'});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _service = UserManagementService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _institutionFilterAvailable = true;
  String? _loadError;
  List<Map<String, dynamic>> _users = [];
  Map<String, int> _roleCounts = {'total': 0};
  late String _institution = widget.initialInstitution;
  String _roleFilter = 'all';
  String _search = '';

  static const Map<String, Color> _roleColors = {
    UserRoles.student: AppTheme.studentPrimary,
    UserRoles.teacher: AppTheme.teacherPrimary,
    UserRoles.admin: AppTheme.adminPrimary,
    'parent': AppTheme.accentOrange,
  };

  static const List<MapEntry<String, String>> _institutions = [
    MapEntry('school', 'School'),
    MapEntry('college', 'College'),
  ];

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
    try {
      final result = await _service.getUsers(institution: _institution);
      if (!mounted) return;
      final counts = <String, int>{'total': 0};
      for (final user in result.users) {
        final role = (user['role'] ?? '').toString();
        counts[role] = (counts[role] ?? 0) + 1;
        counts['total'] = (counts['total'] ?? 0) + 1;
      }
      setState(() {
        _users = result.users;
        _roleCounts = counts;
        _institutionFilterAvailable = result.institutionFilterAvailable;
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading Manage Users: $e');
      if (!mounted) return;
      setState(() {
        _loadError =
            'Could not load users. Check your connection and try again.';
        _users = [];
        _roleCounts = {'total': 0};
        _isLoading = false;
      });
    }
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

  Future<void> _addUser() async {
    final kept = await context.push<String>(
      '/admin/add-user?institution=$_institution',
    );
    if (!mounted) return;
    if (kept == _institution) await _load();
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
      await _load();
      if (!mounted) return;
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

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final username = (user['username'] ?? '').toString();
    final name = (user['display_name'] ?? '').toString();
    final newPassCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Reset Password for $username'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty) ...[
                Text('User: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: newPassCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password (min 6 chars)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (newPassCtrl.text.trim().length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Set New Password'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final res = await AuthService().adminResetPassword(
        targetUsername: username,
        newPassword: newPassCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Password updated!'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to reset password'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        backgroundColor: AppTheme.adminPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add User'),
      ),
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
              if (!_institutionFilterAvailable) _buildInstitutionWarning(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.adminPrimary),
                      )
                    : _loadError != null
                        ? _buildLoadError()
                        : RefreshIndicator(
                            color: AppTheme.adminPrimary,
                            onRefresh: _load,
                            child: _filtered.isEmpty
                                ? ListView(children: [_buildEmptyState()])
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppTheme.md,
                                      AppTheme.sm,
                                      AppTheme.md,
                                      96,
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

  Widget _buildInstitutionWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppTheme.md,
        0,
        AppTheme.md,
        AppTheme.sm,
      ),
      padding: const EdgeInsets.all(AppTheme.sm),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(
        'The backend does not have the institution field yet. Showing all '
        'accounts; run database/users_institution_setup.sql to enable '
        'institution filters.',
        style: AppTheme.caption.copyWith(color: AppTheme.dark),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppTheme.error,
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
            ),
            const SizedBox(height: AppTheme.sm),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
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
              const Icon(Icons.people_alt_rounded,
                  color: Colors.white, size: 26),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.35)),
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
          Row(
            children: _institutions.map((e) {
              final selected = _institution == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    if (selected) return;
                    setState(() {
                      _institution = e.key;
                      _roleFilter = 'all';
                    });
                    _load();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      e.value,
                      style: AppTheme.caption.copyWith(
                        color: selected ? AppTheme.adminPrimary : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRoles.all.map((role) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      UserRoles.label(role),
                      style: AppTheme.caption.copyWith(color: Colors.white70),
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
              hintText: 'Search by name or user ID…',
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
    final color = value == 'all' ? AppTheme.adminPrimary : _roleColor(value);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _roleFilter = value),
        selectedColor: color.withValues(alpha: 0.15),
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
    final name = (user['display_name'] ?? '').toString().trim();
    final username = (user['username'] ?? '').toString();
    final detail = (user['detail'] ?? '').toString();
    final hasName = name.isNotEmpty;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              role == UserRoles.student
                  ? Icons.school_rounded
                  : role == UserRoles.teacher
                      ? Icons.person_rounded
                      : role == 'parent'
                          ? Icons.family_restroom_rounded
                          : Icons.shield_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? name : username,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${UserRoles.label(role)} ID: $username',
                  style: AppTheme.caption.copyWith(color: AppTheme.mediumGray),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppTheme.caption.copyWith(color: AppTheme.lightGray),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.lock_reset_rounded,
                color: AppTheme.adminPrimary),
            tooltip: 'Reset Password',
            onPressed: () => _resetPassword(user),
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
