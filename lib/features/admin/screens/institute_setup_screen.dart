import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/superadmin_service.dart';

/// SuperAdmin — Institute Setup.
///
/// The foundation screen of the ERP: department & designation
/// masters, academic years and the institute profile/branding.
/// Everything else (HOD assignment, fee heads, timetables) reads
/// the masters maintained here.
class InstituteSetupScreen extends StatefulWidget {
  const InstituteSetupScreen({super.key});

  @override
  State<InstituteSetupScreen> createState() => _InstituteSetupScreenState();
}

class _InstituteSetupScreenState extends State<InstituteSetupScreen>
    with SingleTickerProviderStateMixin {
  final _service = SuperAdminService();
  late final TabController _tabController;
  Map<String, dynamic> _stats = {};
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _service.getInstituteStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _statsLoading = false;
      });
    }
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: AppTheme.caption.copyWith(color: Colors.white70),
          ),
          Text(
            value,
            style: AppTheme.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ---------- Header ----------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.lg,
                  AppTheme.md,
                  AppTheme.lg,
                  AppTheme.lg,
                ),
                decoration: const BoxDecoration(
                  gradient: AppTheme.adminGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppTheme.radiusXl),
                    bottomRight: Radius.circular(AppTheme.radiusXl),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Institute Setup',
                                style: AppTheme.h4.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'SuperAdmin — departments, designations, '
                                'academic years & profile',
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.md),
                    if (_statsLoading)
                      const LinearProgressIndicator(
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statChip(
                            Icons.account_tree,
                            'Departments',
                            '${_stats['departments'] ?? 0}',
                          ),
                          _statChip(
                            Icons.badge,
                            'Designations',
                            '${_stats['designations'] ?? 0}',
                          ),
                          _statChip(
                            Icons.school,
                            'Students',
                            '${_stats['students'] ?? 0}',
                          ),
                          _statChip(
                            Icons.person,
                            'Teachers',
                            '${_stats['teachers'] ?? 0}',
                          ),
                          _statChip(
                            Icons.calendar_month,
                            'Current Year',
                            (_stats['currentYear'] ?? 'Not set').toString(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // ---------- Tabs ----------
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.adminPrimary,
                unselectedLabelColor: AppTheme.mediumGray,
                indicatorColor: AppTheme.adminPrimary,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(icon: Icon(Icons.account_tree), text: 'Departments'),
                  Tab(icon: Icon(Icons.badge), text: 'Designations'),
                  Tab(icon: Icon(Icons.calendar_month), text: 'Acad. Years'),
                  Tab(icon: Icon(Icons.business), text: 'Institute Profile'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DepartmentsTab(service: _service, onChanged: _loadStats),
                    _DesignationsTab(service: _service, onChanged: _loadStats),
                    _AcademicYearsTab(service: _service, onChanged: _loadStats),
                    _ProfileTab(service: _service),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Shared helpers
// ============================================================
String _prettyLabel(String value) => value
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _fmtDate(dynamic value) {
  if (value == null) return '-';
  final dt = DateTime.tryParse(value.toString());
  if (dt == null) return value.toString();
  return DateFormat('dd MMM yyyy').format(dt);
}

Widget _emptyState(IconData icon, String title, String subtitle) {
  return ListView(
    children: [
      const SizedBox(height: 80),
      Icon(icon, size: 56, color: AppTheme.lightGray),
      const SizedBox(height: AppTheme.md),
      Text(
        title,
        textAlign: TextAlign.center,
        style: AppTheme.h5.copyWith(color: AppTheme.mediumGray),
      ),
      const SizedBox(height: AppTheme.sm),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightGray),
      ),
    ],
  );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ============================================================
// TAB 1: DEPARTMENTS
// ============================================================
class _DepartmentsTab extends StatefulWidget {
  final SuperAdminService service;
  final VoidCallback onChanged;
  const _DepartmentsTab({required this.service, required this.onChanged});

  @override
  State<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<_DepartmentsTab> {
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.service.getDepartments();
    if (mounted) {
      setState(() {
        _departments = data;
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> dept, bool value) async {
    final ok =
        await widget.service.setDepartmentActive(dept['id'].toString(), value);
    if (!mounted) return;
    if (ok) {
      _load();
      widget.onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update department status')),
      );
    }
  }

  Future<void> _showDepartmentDialog([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final codeCtrl =
        TextEditingController(text: existing?['code']?.toString() ?? '');
    final emailCtrl =
        TextEditingController(text: existing?['email']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?['phone']?.toString() ?? '');
    final hodCustomCtrl = TextEditingController();
    List<Map<String, dynamic>> teachers = [];
    bool teachersLoading = isEdit;
    bool initialLoadStarted = false;
    String? hodValue = existing?['hod_username']?.toString();
    bool hodCustom = false;

    Future<void> loadTeachers(StateSetter setInner) async {
      final deptName = nameCtrl.text.trim();
      if (deptName.isEmpty) return;
      try {
        setInner(() => teachersLoading = true);
      } catch (_) {
        return; // dialog already closed
      }
      final rows = await widget.service.getTeachersForHod(deptName);
      try {
        setInner(() {
          teachers = rows;
          teachersLoading = false;
        });
      } catch (_) {
        // dialog closed while loading — nothing to update
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          if (isEdit && !initialLoadStarted) {
            // First build in edit mode: fetch this department's teachers.
            initialLoadStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadTeachers(setInner);
            });
          }
          final teacherIds = teachers
              .map((t) => t['teacher_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          // Keep the dropdown value valid even when the stored HOD is
          // not in the fetched teacher list (falls back to custom mode).
          if (hodValue != null &&
              hodValue!.isNotEmpty &&
              !teacherIds.contains(hodValue) &&
              !hodCustom) {
            hodCustom = true;
            hodCustomCtrl.text = hodValue!;
            hodValue = '__custom__';
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            title: Text(isEdit ? 'Edit Department' : 'Add Department'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Department Name *',
                        prefixIcon: Icon(Icons.account_tree),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: AppTheme.md),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Code * (e.g. CSE)',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      inputFormatters: [_UpperCaseFormatter()],
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Code is required'
                          : null,
                    ),
                    const SizedBox(height: AppTheme.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: hodValue,
                            decoration: InputDecoration(
                              labelText: 'Head of Department',
                              prefixIcon: const Icon(Icons.person),
                              suffixIcon: teachersLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Not assigned'),
                              ),
                              ...teachers.map(
                                (t) => DropdownMenuItem<String>(
                                  value: t['teacher_id'].toString(),
                                  child: Text(
                                    '${t['name'] ?? t['teacher_id']} '
                                    '(${t['teacher_id']})',
                                  ),
                                ),
                              ),
                              const DropdownMenuItem<String>(
                                value: '__custom__',
                                child: Text('Enter username manually…'),
                              ),
                            ],
                            onChanged: (v) => setInner(() {
                              hodValue = v;
                              hodCustom = v == '__custom__';
                            }),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Load teachers of this department',
                          onPressed: () => loadTeachers(setInner),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (hodCustom) ...[
                      const SizedBox(height: AppTheme.md),
                      TextFormField(
                        controller: hodCustomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'HOD Username',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.md),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Department Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (v) {
                        final text = (v ?? '').trim();
                        if (text.isEmpty) return null;
                        return text.contains('@')
                            ? null
                            : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: AppTheme.md),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final hodUsername = hodCustom
                      ? hodCustomCtrl.text.trim()
                      : (hodValue ?? '');
                  bool ok;
                  if (isEdit) {
                    ok = await widget.service.updateDepartment(
                      existing['id'].toString(),
                      {
                        'name': nameCtrl.text.trim(),
                        'code': codeCtrl.text.trim(),
                        'hod_username':
                            hodUsername.isEmpty ? null : hodUsername,
                        'email': emailCtrl.text.trim().isEmpty
                            ? null
                            : emailCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                      },
                    );
                  } else {
                    ok = await widget.service.createDepartment(
                      name: nameCtrl.text,
                      code: codeCtrl.text,
                      hodUsername: hodUsername.isEmpty ? null : hodUsername,
                      email: emailCtrl.text,
                      phone: phoneCtrl.text,
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(ok);
                },
                child: Text(isEdit ? 'Save Changes' : 'Add Department'),
              ),
            ],
          );
        },
      ),
    );

    nameCtrl.dispose();
    codeCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    hodCustomCtrl.dispose();

    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Department updated' : 'Department created',
          ),
        ),
      );
      _load();
      widget.onChanged();
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save department — name/code may already exist',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.md),
          child: GradientButton(
            text: 'Add Department',
            icon: Icons.add,
            gradient: AppTheme.adminGradient,
            height: 48,
            onPressed: () => _showDepartmentDialog(),
          ),
        ),
        Expanded(
          child: _departments.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: _emptyState(
                    Icons.account_tree,
                    'No departments yet',
                    'Create the first department to start '
                        'mapping teachers and students.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.md,
                      0,
                      AppTheme.md,
                      AppTheme.md,
                    ),
                    itemCount: _departments.length,
                    itemBuilder: (ctx, i) {
                      final d = _departments[i];
                      final active = d['is_active'] == true;
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: AppTheme.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppTheme.adminPrimary.withOpacity(0.12),
                                  child: Text(
                                    (d['code'] ?? '?').toString(),
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.adminPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['name']?.toString() ?? '-',
                                        style: AppTheme.h5,
                                      ),
                                      Text(
                                        'Code: ${d['code'] ?? '-'}',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.mediumGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _showDepartmentDialog(d),
                                  icon: const Icon(
                                    Icons.edit,
                                    color: AppTheme.adminPrimary,
                                  ),
                                ),
                                Switch(
                                  value: active,
                                  activeColor: AppTheme.adminPrimary,
                                  onChanged: (v) => _toggleActive(d, v),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.sm),
                            _infoRow(
                              Icons.person,
                              'HOD',
                              (d['hod_username'] ?? 'Not assigned').toString(),
                            ),
                            if ((d['email'] ?? '').toString().isNotEmpty)
                              _infoRow(
                                Icons.email,
                                'Email',
                                d['email'].toString(),
                              ),
                            if ((d['phone'] ?? '').toString().isNotEmpty)
                              _infoRow(
                                Icons.phone,
                                'Phone',
                                d['phone'].toString(),
                              ),
                            if (!active)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppTheme.sm,
                                ),
                                child: Text(
                                  'Inactive — hidden from new mappings',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.lightGray),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.mediumGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGray),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 2: DESIGNATIONS
// ============================================================
class _DesignationsTab extends StatefulWidget {
  final SuperAdminService service;
  final VoidCallback onChanged;
  const _DesignationsTab({required this.service, required this.onChanged});

  @override
  State<_DesignationsTab> createState() => _DesignationsTabState();
}

class _DesignationsTabState extends State<_DesignationsTab> {
  List<Map<String, dynamic>> _designations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.service.getDesignations();
    if (mounted) {
      setState(() {
        _designations = data;
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> d, bool value) async {
    final ok = await widget.service.updateDesignation(
      d['id'].toString(),
      {'is_active': value},
    );
    if (!mounted) return;
    if (ok) {
      _load();
      widget.onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update designation')),
      );
    }
  }

  Future<void> _showDesignationDialog([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final levelCtrl = TextEditingController(
      text: (existing?['level'] ?? 1).toString(),
    );
    String category =
        existing?['category']?.toString() ?? SuperAdminService.designationCategories.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Text(isEdit ? 'Edit Designation' : 'Add Designation'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title * (e.g. Assistant Professor)',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: AppTheme.md),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: SuperAdminService.designationCategories
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(_prettyLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setInner(() => category = v ?? category),
                ),
                const SizedBox(height: AppTheme.md),
                TextFormField(
                  controller: levelCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Level (seniority, higher = senior)',
                    prefixIcon: Icon(Icons.leaderboard),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1 || n > 10) {
                      return 'Enter a level between 1 and 10';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final level = int.tryParse(levelCtrl.text.trim()) ?? 1;
                bool ok;
                if (isEdit) {
                  ok = await widget.service.updateDesignation(
                    existing['id'].toString(),
                    {
                      'title': titleCtrl.text.trim(),
                      'category': category,
                      'level': level,
                    },
                  );
                } else {
                  ok = await widget.service.createDesignation(
                    title: titleCtrl.text,
                    category: category,
                    level: level,
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop(ok);
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Designation'),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    levelCtrl.dispose();

    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Designation updated' : 'Designation created',
          ),
        ),
      );
      _load();
      widget.onChanged();
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save designation — title may already exist'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Group by category, in the canonical order.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final c in SuperAdminService.designationCategories) {
      grouped[c] = [];
    }
    for (final d in _designations) {
      final c = d['category']?.toString() ?? 'teaching';
      grouped.putIfAbsent(c, () => []).add(d);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.md),
          child: GradientButton(
            text: 'Add Designation',
            icon: Icons.add,
            gradient: AppTheme.adminGradient,
            height: 48,
            onPressed: () => _showDesignationDialog(),
          ),
        ),
        Expanded(
          child: _designations.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: _emptyState(
                    Icons.badge,
                    'No designations yet',
                    'Add the posts your institute hires against.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.md,
                      0,
                      AppTheme.md,
                      AppTheme.md,
                    ),
                    children: [
                      for (final entry in grouped.entries)
                        if (entry.value.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTheme.sm,
                              bottom: AppTheme.sm,
                            ),
                            child: Text(
                              _prettyLabel(entry.key),
                              style: AppTheme.h5.copyWith(
                                color: AppTheme.adminPrimary,
                              ),
                            ),
                          ),
                          ...entry.value.map(
                            (d) => GlassCard(
                              margin: const EdgeInsets.only(
                                bottom: AppTheme.md,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        AppTheme.adminPrimary.withOpacity(0.12),
                                    child: const Icon(
                                      Icons.badge,
                                      color: AppTheme.adminPrimary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d['title']?.toString() ?? '-',
                                          style: AppTheme.bodyLarge.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Level ${d['level'] ?? 1}',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.mediumGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () =>
                                        _showDesignationDialog(d),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: AppTheme.adminPrimary,
                                    ),
                                  ),
                                  Switch(
                                    value: d['is_active'] == true,
                                    activeColor: AppTheme.adminPrimary,
                                    onChanged: (v) => _toggleActive(d, v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================
// TAB 3: ACADEMIC YEARS
// ============================================================
class _AcademicYearsTab extends StatefulWidget {
  final SuperAdminService service;
  final VoidCallback onChanged;
  const _AcademicYearsTab({required this.service, required this.onChanged});

  @override
  State<_AcademicYearsTab> createState() => _AcademicYearsTabState();
}

class _AcademicYearsTabState extends State<_AcademicYearsTab> {
  List<Map<String, dynamic>> _years = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.service.getAcademicYears();
    if (mounted) {
      setState(() {
        _years = data;
        _loading = false;
      });
    }
  }

  Future<void> _setCurrent(Map<String, dynamic> year) async {
    final ok =
        await widget.service.setCurrentAcademicYear(year['id'].toString());
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${year['label']} is now the current academic year'),
        ),
      );
      _load();
      widget.onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not set current year')),
      );
    }
  }

  Future<void> _showYearDialog() async {
    final formKey = GlobalKey<FormState>();
    final labelCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool markCurrent = false;

    Future<void> pickDate(
      StateSetter setInner,
      bool isStart,
    ) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: (isStart ? startDate : endDate) ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        setInner(() {
          if (isStart) {
            startDate = picked;
          } else {
            endDate = picked;
          }
        });
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Text('Add Academic Year'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label * (e.g. 2026-27)',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Label is required'
                      : null,
                ),
                const SizedBox(height: AppTheme.md),
                _dateField(
                  'Start Date',
                  startDate,
                  () => pickDate(setInner, true),
                ),
                const SizedBox(height: AppTheme.md),
                _dateField(
                  'End Date',
                  endDate,
                  () => pickDate(setInner, false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as current year'),
                  value: markCurrent,
                  activeColor: AppTheme.adminPrimary,
                  onChanged: (v) =>
                      setInner(() => markCurrent = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (startDate != null &&
                    endDate != null &&
                    endDate!.isBefore(startDate!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End date must be after start date'),
                    ),
                  );
                  return;
                }
                final ok = await widget.service.createAcademicYear(
                  label: labelCtrl.text,
                  startDate: startDate,
                  endDate: endDate,
                  isCurrent: markCurrent,
                );
                if (ctx.mounted) Navigator.of(ctx).pop(ok);
              },
              child: const Text('Add Year'),
            ),
          ],
        ),
      ),
    );

    labelCtrl.dispose();

    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Academic year added')),
      );
      _load();
      widget.onChanged();
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add year — label may already exist'),
        ),
      );
    }
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.date_range),
        ),
        child: Text(
          value == null
              ? 'Select date'
              : DateFormat('dd MMM yyyy').format(value),
          style: value == null
              ? AppTheme.bodyMedium.copyWith(color: AppTheme.lightGray)
              : AppTheme.bodyMedium,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.md),
          child: GradientButton(
            text: 'Add Academic Year',
            icon: Icons.add,
            gradient: AppTheme.adminGradient,
            height: 48,
            onPressed: _showYearDialog,
          ),
        ),
        Expanded(
          child: _years.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: _emptyState(
                    Icons.calendar_month,
                    'No academic years yet',
                    'Add the current academic year so sessions, '
                        'fees and exams can be tagged to it.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.md,
                      0,
                      AppTheme.md,
                      AppTheme.md,
                    ),
                    itemCount: _years.length,
                    itemBuilder: (ctx, i) {
                      final y = _years[i];
                      final isCurrent = y['is_current'] == true;
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: AppTheme.md),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isCurrent
                                  ? AppTheme.adminPrimary
                                  : AppTheme.adminPrimary.withOpacity(0.12),
                              child: Icon(
                                Icons.calendar_month,
                                color: isCurrent
                                    ? Colors.white
                                    : AppTheme.adminPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        y['label']?.toString() ?? '-',
                                        style: AppTheme.h5,
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: AppTheme.sm),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(
                                              AppTheme.radiusFull,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.success
                                                  .withOpacity(0.4),
                                            ),
                                          ),
                                          child: Text(
                                            'CURRENT',
                                            style: AppTheme.caption.copyWith(
                                              color: AppTheme.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${_fmtDate(y['start_date'])}'
                                    '  →  ${_fmtDate(y['end_date'])}',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.mediumGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isCurrent)
                              TextButton(
                                onPressed: () => _setCurrent(y),
                                child: const Text('Set Current'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================
// TAB 4: INSTITUTE PROFILE + BRANDING
// ============================================================
class _ProfileTab extends StatefulWidget {
  final SuperAdminService service;
  const _ProfileTab({required this.service});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _affiliationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _establishedCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _colorCtrl.addListener(_onColorChanged);
    _load();
  }

  @override
  void dispose() {
    _colorCtrl.removeListener(_onColorChanged);
    _nameCtrl.dispose();
    _affiliationCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _establishedCtrl.dispose();
    _logoCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  void _onColorChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await widget.service.getSettings(SuperAdminService.profileKey);
    final branding =
        await widget.service.getSettings(SuperAdminService.brandingKey);
    if (!mounted) return;
    _nameCtrl.text = profile['name']?.toString() ?? '';
    _affiliationCtrl.text = profile['affiliation']?.toString() ?? '';
    _addressCtrl.text = profile['address']?.toString() ?? '';
    _phoneCtrl.text = profile['phone']?.toString() ?? '';
    _emailCtrl.text = profile['email']?.toString() ?? '';
    _websiteCtrl.text = profile['website']?.toString() ?? '';
    _establishedCtrl.text = profile['established_year']?.toString() ?? '';
    _logoCtrl.text = branding['logo_url']?.toString() ?? '';
    _colorCtrl.text = branding['primary_color']?.toString() ?? '';
    setState(() => _loading = false);
  }

  Color? get _previewColor {
    var hex = _colorCtrl.text.trim().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final profileOk = await widget.service.saveSettings(
      SuperAdminService.profileKey,
      {
        'name': _nameCtrl.text.trim(),
        'affiliation': _affiliationCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'established_year':
            int.tryParse(_establishedCtrl.text.trim()) ??
                _establishedCtrl.text.trim(),
      },
    );
    final brandingOk = await widget.service.saveSettings(
      SuperAdminService.brandingKey,
      {
        'logo_url': _logoCtrl.text.trim(),
        'primary_color': _colorCtrl.text.trim(),
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          profileOk && brandingOk
              ? 'Institute profile saved'
              : 'Could not save the profile — please try again',
        ),
        backgroundColor:
            profileOk && brandingOk ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Institute Profile', style: AppTheme.h5),
                    const SizedBox(height: AppTheme.md),
                    _field(
                      _nameCtrl,
                      'Institute Name *',
                      Icons.business,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Institute name is required'
                          : null,
                    ),
                    _field(
                      _affiliationCtrl,
                      'Affiliation / University',
                      Icons.school,
                    ),
                    _field(
                      _addressCtrl,
                      'Address',
                      Icons.location_on,
                      maxLines: 2,
                    ),
                    _field(
                      _phoneCtrl,
                      'Phone',
                      Icons.phone,
                      keyboard: TextInputType.phone,
                    ),
                    _field(
                      _emailCtrl,
                      'Email',
                      Icons.email,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        final text = (v ?? '').trim();
                        if (text.isEmpty) return null;
                        return text.contains('@')
                            ? null
                            : 'Enter a valid email';
                      },
                    ),
                    _field(
                      _websiteCtrl,
                      'Website',
                      Icons.language,
                      keyboard: TextInputType.url,
                    ),
                    _field(
                      _establishedCtrl,
                      'Established Year',
                      Icons.history,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final text = (v ?? '').trim();
                        if (text.isEmpty) return null;
                        final year = int.tryParse(text);
                        if (year == null || year < 1800 || year > 2100) {
                          return 'Enter a valid year';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.md),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branding', style: AppTheme.h5),
                    const SizedBox(height: AppTheme.md),
                    _field(
                      _logoCtrl,
                      'Logo URL',
                      Icons.image,
                      keyboard: TextInputType.url,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field(
                            _colorCtrl,
                            'Primary Color (hex, e.g. #7C3AED)',
                            Icons.palette,
                            validator: (v) {
                              final text = (v ?? '').trim();
                              if (text.isEmpty) return null;
                              final hex = text.replaceAll('#', '');
                              final valid = (hex.length == 6 ||
                                      hex.length == 8) &&
                                  int.tryParse(hex, radix: 16) != null;
                              return valid ? null : 'Enter a valid hex color';
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.md),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _previewColor ?? Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: AppTheme.extraLightGray,
                            ),
                          ),
                          child: _previewColor == null
                              ? const Icon(
                                  Icons.palette_outlined,
                                  color: AppTheme.lightGray,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.md),
              GradientButton(
                text: _saving ? 'Saving…' : 'Save Institute Profile',
                icon: Icons.save,
                gradient: AppTheme.adminGradient,
                height: 52,
                isLoading: _saving,
                onPressed: _saving ? () {} : _save,
              ),
              const SizedBox(height: AppTheme.lg),
            ],
          ),
        ),
      ),
    );
  }
}
