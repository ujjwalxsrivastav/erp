import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

/// Counsellor workspace for school admissions.
///
/// Every application submitted through the public admission form (or the admin
/// intake wizard) is allotted to a counsellor in round-robin order. This page
/// shows the signed-in counsellor the applications allotted to them, the
/// current workflow status after any admin action, and the full student
/// details behind each application.
class SchoolCounsellorDashboard extends StatefulWidget {
  const SchoolCounsellorDashboard({super.key});

  @override
  State<SchoolCounsellorDashboard> createState() =>
      _SchoolCounsellorDashboardState();
}

class _SchoolCounsellorDashboardState extends State<SchoolCounsellorDashboard> {
  static const _teal = Color(0xFF0F766E);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  final _schoolService = SchoolService();
  final _authService = AuthService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _counsellor;
  List<Map<String, dynamic>> _applications = [];
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final username = await _authService.getCurrentUsername() ?? '';
      Map<String, dynamic>? counsellor;

      if (username.isNotEmpty) {
        counsellor = await _schoolService.getSchoolCounsellorByUsername(username);
      }

      final applications = counsellor == null
          ? <Map<String, dynamic>>[]
          : await _schoolService.getAdmissionsForCounsellor(
              counsellorId: counsellor['id']?.toString(),
              counsellorName: counsellor['name']?.toString(),
            );

      if (!mounted) return;
      setState(() {
        _counsellor = counsellor;
        _applications = applications;
        _isLoading = false;
        if (counsellor == null) {
          _errorMessage =
              'No counsellor profile is linked to "$username". Ask the school '
              'office to add you to the counsellor directory.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load your allotted applications. Please try again.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------------

  List<String> get _statusOptions {
    final base = <String>[
      'Under Review',
      'Interview Scheduled',
      'Approved',
      'Offer Letter Issued',
      'Enrolled',
      'Rejected',
    ];
    for (final a in _applications) {
      final s = (a['status'] ?? '').toString().trim();
      if (s.isNotEmpty && !base.contains(s)) base.add(s);
    }
    return ['all', ...base];
  }

  int _countFor(String status) {
    if (status == 'all') return _applications.length;
    return _applications
        .where((a) => (a['status'] ?? '').toString() == status)
        .length;
  }

  List<Map<String, dynamic>> get _visibleApplications {
    var list = _applications;
    if (_selectedStatus != 'all') {
      list = list
          .where((a) => (a['status'] ?? '').toString() == _selectedStatus)
          .toList();
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((a) {
        final haystack = [
          a['applicant_name'],
          a['parent_name'],
          a['parent_phone'],
          a['email'],
          a['application_no'],
          a['grade_applying'],
          a['referral'],
        ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');
        return haystack.contains(query);
      }).toList();
    }
    return list;
  }

  int _countWhere(bool Function(Map<String, dynamic>) test) =>
      _applications.where(test).length;

  // ---------------------------------------------------------------------------
  // Styling helpers
  // ---------------------------------------------------------------------------

  ({Color fg, Color bg}) _statusColors(String status) {
    switch (status.toLowerCase()) {
      case 'enrolled':
        return (fg: const Color(0xFF059669), bg: const Color(0xFFECFDF5));
      case 'offer letter issued':
        return (fg: const Color(0xFF7C3AED), bg: const Color(0xFFF5F3FF));
      case 'approved':
        return (fg: const Color(0xFF2563EB), bg: const Color(0xFFEFF6FF));
      case 'interview scheduled':
        return (fg: const Color(0xFF0284C7), bg: const Color(0xFFF0F9FF));
      case 'rejected':
        return (fg: const Color(0xFFDC2626), bg: const Color(0xFFFEF2F2));
      default:
        return (fg: const Color(0xFFD97706), bg: const Color(0xFFFFFBEB));
    }
  }

  String _shortDate(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) return '—';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _text(dynamic value, {String fallback = '—'}) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static const _docLabels = <String, String>{
    'birth_cert': 'Birth certificate',
    'student_aadhaar': 'Student Aadhaar',
    'parent_aadhaar': 'Parent Aadhaar',
    'transfer_cert': 'Transfer certificate',
    'previous_report_card': 'Previous report card',
    'medical_fitness': 'Medical fitness',
    'rte_income_cert': 'RTE income certificate',
  };

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : RefreshIndicator(
              color: _teal,
              onRefresh: _loadData,
              child: _buildBody(),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final name = _text(_counsellor?['name'], fallback: 'Counsellor');
    return AppBar(
      backgroundColor: _teal,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Counsellor Workspace',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          Text(
            '$name • ${_applications.length} allotted application${_applications.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded),
          onPressed: () async {
            await _authService.logout();
            if (context.mounted) context.go('/login');
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody() {
    if (_counsellor == null && _errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          _emptyState(
            icon: Icons.person_off_outlined,
            title: 'Counsellor profile not found',
            message: _errorMessage!,
            actionLabel: 'Retry',
            onAction: _loadData,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildCounsellorCard(),
        const SizedBox(height: 14),
        _buildMetricGrid(),
        const SizedBox(height: 14),
        _buildSearchField(),
        const SizedBox(height: 10),
        _buildStatusFilters(),
        const SizedBox(height: 12),
        if (_visibleApplications.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: _emptyState(
              icon: Icons.inbox_outlined,
              title: _applications.isEmpty
                  ? 'No applications allotted yet'
                  : 'No matching applications',
              message: _applications.isEmpty
                  ? 'When a parent submits the admission form, the school office '
                      'allots the application to a counsellor in rotation. '
                      'Pull down to refresh.'
                  : 'Try a different search term or status filter.',
            ),
          )
        else
          ..._visibleApplications.map(_buildApplicationCard),
      ],
    );
  }

  Widget _buildCounsellorCard() {
    final name = _text(_counsellor?['name'], fallback: 'Counsellor');
    final username = _text(_counsellor?['username'], fallback: '');
    final phone = _text(_counsellor?['phone'], fallback: '');
    final load = (_counsellor?['assignments_count'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'C',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (username.isNotEmpty) '@$username',
                    if (phone.isNotEmpty) phone,
                  ].join(' • '),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Lifetime allotments: $load',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    final inProgress = _countWhere((a) {
      final s = (a['status'] ?? '').toString().toLowerCase();
      return s == 'under review' ||
          s == 'interview scheduled' ||
          s == 'pending';
    });
    final approved = _countWhere((a) {
      final s = (a['status'] ?? '').toString().toLowerCase();
      return s == 'approved' || s == 'enrolled' || s == 'offer letter issued';
    });
    final rejected = _countWhere(
        (a) => (a['status'] ?? '').toString().toLowerCase() == 'rejected');

    final tiles = [
      _metricTile('Allotted', _applications.length, const Color(0xFF0F766E),
          const Color(0xFFF0FDFA)),
      _metricTile('In progress', inProgress, const Color(0xFFD97706),
          const Color(0xFFFFFBEB)),
      _metricTile('Approved', approved, const Color(0xFF2563EB),
          const Color(0xFFEFF6FF)),
      _metricTile('Rejected', rejected, const Color(0xFFDC2626),
          const Color(0xFFFEF2F2)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tiles.map((tile) {
            return SizedBox(width: width, child: tile);
          }).toList(),
        );
      },
    );
  }

  Widget _metricTile(String label, int value, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search student, parent, phone or application no.',
        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statusOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statusOptions[index];
          final selected = status == _selectedStatus;
          final count = _countFor(status);
          final label = status == 'all' ? 'All' : status;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _selectedStatus = status),
            label: Text('$label ($count)'),
            labelStyle: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
            selectedColor: _teal,
            backgroundColor: Colors.white,
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: selected ? _teal : const Color(0xFFE2E8F0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> a) {
    final status = _text(a['status'], fallback: 'Under Review');
    final colors = _statusColors(status);
    final name = _text(a['applicant_name'], fallback: 'Applicant');
    final grade = _text(a['grade_applying']);
    final appNo = _text(a['application_no'], fallback: _text(a['id']));
    final parent = _text(a['parent_name']);
    final phone = _text(a['parent_phone'], fallback: '');
    final referral = _text(a['referral'], fallback: '');
    final docStatus = _text(a['doc_status'], fallback: 'Pending');
    final testScore = (a['test_score'] as num?)?.toInt() ?? 0;
    final lastAction = _shortDate(a['last_action_at'] ?? a['date']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showApplicationDetails(a),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                        style: TextStyle(
                          color: colors.fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$grade • $appNo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: colors.fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _infoItem(Icons.family_restroom_outlined,
                        'Parent: $parent'),
                    if (phone.isNotEmpty)
                      _infoItem(Icons.phone_outlined, phone),
                    _infoItem(Icons.verified_user_outlined,
                        'Docs: $docStatus',
                        color: docStatus.toLowerCase().contains('verif')
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706)),
                    if (testScore > 0)
                      _infoItem(Icons.grade_rounded, 'Test: $testScore/50',
                          color: const Color(0xFF2563EB)),
                    if (referral.isNotEmpty)
                      _infoItem(Icons.share_rounded, 'Referral: $referral',
                          color: const Color(0xFF7C3AED)),
                    _infoItem(Icons.update_rounded, 'Updated: $lastAction',
                        color: _muted),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'View student details',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: _teal),
                    const Spacer(),
                    if (a['counsellor_assigned_at'] != null)
                      Text(
                        'Allotted ${_shortDate(a['counsellor_assigned_at'])}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? _muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color ?? _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: _teal),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Detail sheet
  // ---------------------------------------------------------------------------

  void _showApplicationDetails(Map<String, dynamic> a) {
    final status = _text(a['status'], fallback: 'Under Review');
    final colors = _statusColors(status);
    final documents =
        (a['documents'] as Map?)?.cast<String, dynamic>() ?? const {};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _text(a['applicant_name'],
                                          fallback: 'Applicant'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_text(a['grade_applying'])} • ${_text(a['application_no'], fallback: _text(a['id']))}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        _detailSection(
                          icon: Icons.person_outline_rounded,
                          title: 'Student details',
                          rows: [
                            ('Full name', _text(a['applicant_name'])),
                            ('Date of birth', _text(a['dob'])),
                            ('Gender', _text(a['gender'])),
                            ('Applying for', _text(a['grade_applying'])),
                            ('Stream', _text(a['stream'], fallback: 'General')),
                            (
                              'Previous school',
                              _text(a['previous_school'], fallback: 'Not specified')
                            ),
                            ('Address', _text(a['address'])),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _detailSection(
                          icon: Icons.family_restroom_rounded,
                          title: 'Parent / guardian',
                          rows: [
                            ('Name', _text(a['parent_name'])),
                            ('Mobile', _text(a['parent_phone'])),
                            ('Email', _text(a['email'])),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _detailSection(
                          icon: Icons.share_rounded,
                          title: 'Referral & allotment',
                          rows: [
                            (
                              'Referred by',
                              _text(a['referral'], fallback: 'Not provided')
                            ),
                            (
                              'Counsellor',
                              _text(a['counsellor_name'],
                                  fallback: _text(_counsellor?['name']))
                            ),
                            (
                              'Allotted on',
                              _shortDate(a['counsellor_assigned_at'])
                            ),
                            (
                              'Application source',
                              _text(a['source'], fallback: 'public_form')
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _detailSection(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Documents & verification',
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Verification status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _text(a['doc_status'], fallback: 'Pending'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _text(a['doc_status'])
                                            .toLowerCase()
                                            .contains('verif')
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._docLabels.entries.map((entry) {
                              final received =
                                  documents[entry.key] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      received
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked,
                                      size: 15,
                                      color: received
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: received
                                              ? _ink
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      received ? 'Received' : 'Pending',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: received
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _detailSection(
                          icon: Icons.psychology_outlined,
                          title: 'Assessment & interaction',
                          rows: [
                            (
                              'Test score',
                              ((a['test_score'] as num?)?.toInt() ?? 0) > 0
                                  ? '${a['test_score']}/50'
                                  : 'Not recorded'
                            ),
                            (
                              'Interview notes',
                              _text(a['interview_notes'],
                                  fallback: 'No notes recorded')
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _detailSection(
                          icon: Icons.timeline_rounded,
                          title: 'Application status',
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.bg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: colors.fg,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Updated by the school office',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _statusFact(
                                    'Applied on',
                                    _shortDate(a['date']),
                                  ),
                                ),
                                Expanded(
                                  child: _statusFact(
                                    'Last action',
                                    _shortDate(a['last_action_at']),
                                  ),
                                ),
                              ],
                            ),
                            if (((a['fee_demanded'] as num?)?.toDouble() ?? 0) >
                                0) ...[
                              const SizedBox(height: 8),
                              _statusFact(
                                'Fee demanded',
                                '₹${((a['fee_demanded'] as num).toDouble()).toStringAsFixed(0)}',
                              ),
                            ],
                            if (_text(a['offer_valid_till'],
                                    fallback: '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _statusFact(
                                'Offer valid till',
                                _text(a['offer_valid_till']),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Close'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailSection({
    required IconData icon,
    required String title,
    List<(String, String)> rows = const [],
    List<Widget> children = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: _teal),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      row.$1,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _statusFact(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: _muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    );
  }
}
