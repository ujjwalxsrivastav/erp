import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/teacher_lifecycle_service.dart';

/// Subject Allotment (HOD) — allots subjects to department teachers
/// per semester / section / academic year and tracks workload.
/// Teachers above 24 weekly hours are highlighted as overloaded.
class SubjectAllotmentScreen extends StatefulWidget {
  final String username;
  const SubjectAllotmentScreen({super.key, this.username = ''});

  @override
  State<SubjectAllotmentScreen> createState() => _SubjectAllotmentScreenState();
}

class _SubjectAllotmentScreenState extends State<SubjectAllotmentScreen> {
  final _service = TeacherLifecycleService();

  List<String> _departments = [];
  List<Map<String, dynamic>> _workload = [];
  List<Map<String, dynamic>> _allotments = [];
  String? _department;
  int? _semester;
  late String _academicYear;
  bool _isLoading = true;
  bool _isLoadingData = false;

  static const double _overloadHours = 24;

  @override
  void initState() {
    super.initState();
    _academicYear = _currentAcademicYear();
    _loadDepartments();
  }

  /// Indian academic year (June–May), e.g. Oct 2026 -> '2026-27'.
  String _currentAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${(startYear + 1).toString().substring(2)}';
  }

  Future<void> _loadDepartments() async {
    final depts = await _service.getDepartments();
    if (!mounted) return;
    setState(() {
      _departments = depts;
      _isLoading = false;
      if (depts.isNotEmpty) _department = depts.first;
    });
    if (_department != null) _loadData();
  }

  Future<void> _loadData() async {
    final dept = _department;
    if (dept == null) return;
    setState(() => _isLoadingData = true);
    final workload =
        await _service.getTeacherWorkload(dept, academicYear: _academicYear);
    final allotments = await _service.getAllotments(
      department: dept,
      semester: _semester,
      academicYear: _academicYear,
    );
    if (!mounted) return;
    setState(() {
      _workload = workload;
      _allotments = allotments;
      _isLoadingData = false;
    });
  }

  String _fmtNum(num v) => NumberFormat('#,##0.##').format(v);

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.teacherPrimary,
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.teacherPrimary, width: 2),
      ),
    );
  }

  // ---------------- Allot Subject ----------------
  Future<void> _showAllotDialog() async {
    final dept = _department;
    if (dept == null) return;
    final teachers = await _service.getTeachersByDepartment(dept);
    final master = await _service.getSubjectsMaster(department: dept);
    if (!mounted) return;
    if (teachers.isEmpty) {
      _showMessage('No teachers found in $dept', isError: true);
      return;
    }

    final formKey = GlobalKey<FormState>();
    final subjectIdCtrl = TextEditingController();
    final subjectNameCtrl = TextEditingController();
    final sectionCtrl = TextEditingController(text: 'A');
    final hoursCtrl = TextEditingController(text: '4');
    String? teacherUsername =
        teachers.first['teacher_id']?.toString();
    Map<String, dynamic>? selectedSubject;
    int semester = _semester ?? 1;
    String academicYear = _academicYear;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Allot Subject'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: teacherUsername,
                    decoration: _fieldDecoration('Teacher *',
                        icon: Icons.person_outline),
                    isExpanded: true,
                    items: teachers
                        .map((t) => DropdownMenuItem<String>(
                              value: t['teacher_id'].toString(),
                              child: Text(
                                '${t['name']} (${t['designation'] ?? ''})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => teacherUsername = v),
                  ),
                  const SizedBox(height: AppTheme.md),
                  if (master.isNotEmpty) ...[
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedSubject,
                      decoration: _fieldDecoration('Subject (master) *',
                          icon: Icons.book_outlined),
                      isExpanded: true,
                      items: master
                          .map((s) => DropdownMenuItem<Map<String, dynamic>>(
                                value: s,
                                child: Text(
                                  '${s['subject_name']} (${s['subject_id']})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedSubject = v),
                      validator: (v) =>
                          v == null ? 'Select a subject' : null,
                    ),
                  ] else ...[
                    TextFormField(
                      controller: subjectIdCtrl,
                      decoration: _fieldDecoration('Subject Code / ID *',
                          icon: Icons.book_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Subject ID is required'
                          : null,
                    ),
                    const SizedBox(height: AppTheme.md),
                    TextFormField(
                      controller: subjectNameCtrl,
                      decoration: _fieldDecoration('Subject Name',
                          icon: Icons.subject),
                    ),
                  ],
                  const SizedBox(height: AppTheme.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: semester,
                          decoration: _fieldDecoration('Semester'),
                          items: List.generate(
                            8,
                            (i) => DropdownMenuItem(
                                value: i + 1, child: Text('Sem ${i + 1}')),
                          ),
                          onChanged: (v) =>
                              setDialogState(() => semester = v ?? 1),
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: TextFormField(
                          controller: sectionCtrl,
                          decoration: _fieldDecoration('Section'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: hoursCtrl,
                          decoration: _fieldDecoration('Weekly Hours',
                              icon: Icons.schedule_outlined),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.trim()) == null
                                ? 'Invalid number'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: academicYear,
                          decoration: _fieldDecoration('Academic Year'),
                          items: _academicYearOptions()
                              .map((y) => DropdownMenuItem(
                                  value: y, child: Text(y)))
                              .toList(),
                          onChanged: (v) => setDialogState(
                              () => academicYear = v ?? _academicYear),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teacherPrimary),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child:
                  const Text('Allot', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true && teacherUsername != null) {
      final subjectId = master.isNotEmpty
          ? (selectedSubject?['subject_id']?.toString() ?? '')
          : subjectIdCtrl.text.trim();
      final subjectName = master.isNotEmpty
          ? (selectedSubject?['subject_name']?.toString())
          : (subjectNameCtrl.text.trim().isEmpty
              ? null
              : subjectNameCtrl.text.trim());
      final ok = await _service.allotSubject(
        teacherUsername: teacherUsername!,
        subjectId: subjectId,
        subjectName: subjectName,
        department: dept,
        semester: semester,
        section: sectionCtrl.text.trim().isEmpty
            ? null
            : sectionCtrl.text.trim(),
        academicYear: academicYear,
        weeklyHours: double.tryParse(hoursCtrl.text.trim()) ?? 4,
        allottedBy: widget.username.isEmpty ? null : widget.username,
      );
      _showMessage(
        ok
            ? 'Subject allotted'
            : 'Failed to allot (same subject/semester/section may already be allotted)',
        isError: !ok,
      );
      if (ok) _loadData();
    }
    subjectIdCtrl.dispose();
    subjectNameCtrl.dispose();
    sectionCtrl.dispose();
    hoursCtrl.dispose();
  }

  List<String> _academicYearOptions() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return [
      for (var y = startYear - 1; y <= startYear + 1; y++)
        '$y-${(y + 1).toString().substring(2)}',
    ];
  }

  Future<void> _deactivate(Map<String, dynamic> allotment) async {
    final ok = await _service.updateAllotmentStatus(
        allotment['id'].toString(), 'inactive');
    _showMessage(ok ? 'Allotment removed' : 'Failed to remove',
        isError: !ok);
    if (ok) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final totalHours = _workload.fold<double>(
        0, (sum, t) => sum + ((t['total_hours'] as num?)?.toDouble() ?? 0));
    final overloaded =
        _workload.where((t) => ((t['total_hours'] as num?)?.toDouble() ?? 0) > _overloadHours).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: _department == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.teacherPrimary,
              onPressed: _showAllotDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Allot Subject',
                  style: TextStyle(color: Colors.white)),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.teacherPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.teacherGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.lg, 56, AppTheme.lg, AppTheme.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Subject Allotment',
                          style: AppTheme.h3.copyWith(color: AppTheme.white),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'HOD — who teaches what, and teaching workload',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: AppTheme.md),
                        Row(
                          children: [
                            _statMini(
                                'Teachers', _workload.length.toString()),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Allotments',
                                _allotments.length.toString()),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Total Hrs / Week',
                                _fmtNum(totalHours)),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Overloaded', overloaded.toString()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child:
                    CircularProgressIndicator(color: AppTheme.teacherPrimary),
              ),
            )
          else if (_departments.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.business_outlined,
                        size: 64, color: AppTheme.lightGray),
                    const SizedBox(height: AppTheme.md),
                    Text('No departments found',
                        style:
                            AppTheme.h5.copyWith(color: AppTheme.mediumGray)),
                    const SizedBox(height: AppTheme.sm),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.xl),
                      child: Text(
                        'Departments appear here once teachers exist in teacher records.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.lightGray),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildFilters(),
                  const SizedBox(height: AppTheme.lg),
                  if (_isLoadingData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.lg),
                        child: CircularProgressIndicator(
                            color: AppTheme.teacherPrimary),
                      ),
                    )
                  else ...[
                    _buildWorkloadSection(),
                    const SizedBox(height: AppTheme.lg),
                    _buildAllotmentsSection(),
                  ],
                  const SizedBox(height: 80),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statMini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTheme.h4.copyWith(color: AppTheme.white)),
        Text(label, style: AppTheme.caption.copyWith(color: Colors.white70)),
      ],
    );
  }

  Widget _buildFilters() {
    return GlassCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _department,
            decoration: _fieldDecoration('Department', icon: Icons.business),
            isExpanded: true,
            items: _departments
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _department = v);
              _loadData();
            },
          ),
          const SizedBox(height: AppTheme.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _semester,
                  decoration: _fieldDecoration('Semester (list filter)'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('All Semesters')),
                    ...List.generate(
                      8,
                      (i) => DropdownMenuItem<int?>(
                          value: i + 1, child: Text('Semester ${i + 1}')),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _semester = v);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _academicYear,
                  decoration: _fieldDecoration('Academic Year'),
                  isExpanded: true,
                  items: _academicYearOptions()
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _academicYear = v);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Teacher Workload — $_department', style: AppTheme.h5),
        const SizedBox(height: AppTheme.sm),
        Text(
          'Weekly teaching hours from active allotments. Above ${_overloadHours.toInt()} hrs/week is flagged as overload.',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
        ),
        const SizedBox(height: AppTheme.md),
        if (_workload.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text('No teachers in this department yet.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.mediumGray)),
              ),
            ),
          )
        else
          ..._workload.map((t) {
            final hours = (t['total_hours'] as num?)?.toDouble() ?? 0;
            final subjects = (t['subjects_count'] as num?)?.toInt() ?? 0;
            final isOver = hours > _overloadHours;
            final ratio = (hours / 30).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: GlassCard(
                color: isOver ? AppTheme.error.withOpacity(0.04) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppTheme.teacherPrimary.withOpacity(0.12),
                          child: Text(
                            (t['teacher_name']?.toString() ?? '').isNotEmpty
                                ? (t['teacher_name'].toString())[0]
                                    .toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.teacherPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: AppTheme.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['teacher_name']?.toString() ?? '',
                                  style: AppTheme.bodyLarge),
                              Text(
                                '$subjects subject${subjects == 1 ? '' : 's'} • ${_fmtNum(hours)} hrs/week',
                                style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.mediumGray),
                              ),
                            ],
                          ),
                        ),
                        if (isOver)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppTheme.error),
                                const SizedBox(width: 4),
                                Text('OVERLOAD',
                                    style: AppTheme.caption
                                        .copyWith(color: AppTheme.error)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sm),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: AppTheme.extraLightGray,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOver
                              ? AppTheme.error
                              : hours > 18
                                  ? AppTheme.warning
                                  : AppTheme.teacherPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAllotmentsSection() {
    // Group allotments by teacher for display.
    final nameByUsername = <String, String>{
      for (var t in _workload)
        t['teacher_username'].toString():
            t['teacher_name']?.toString() ?? '',
    };
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var a in _allotments) {
      grouped.putIfAbsent(a['teacher_username'].toString(), () => []).add(a);
    }
    final teachers = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Allotments${_semester != null ? ' — Semester $_semester' : ''}',
                style: AppTheme.h5,
              ),
            ),
            GradientButton(
              text: 'Allot',
              icon: Icons.add,
              gradient: AppTheme.teacherGradient,
              height: 40,
              width: 110,
              onPressed: _showAllotDialog,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        if (_allotments.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text(
                  'No allotments for this selection yet. Use Allot Subject to assign the first one.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.mediumGray),
                ),
              ),
            ),
          )
        else
          ...teachers.map((username) {
            final rows = grouped[username]!;
            final totalHours = rows.fold<double>(
                0,
                (sum, a) =>
                    sum + ((a['weekly_hours'] as num?)?.toDouble() ?? 0));
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nameByUsername[username] ?? username,
                            style: AppTheme.bodyLarge,
                          ),
                        ),
                        Text(
                          '${rows.length} subjects • ${_fmtNum(totalHours)} hrs/week',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.mediumGray),
                        ),
                      ],
                    ),
                    const Divider(height: AppTheme.lg),
                    ...rows.map((a) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppTheme.sm),
                          child: Row(
                            children: [
                              const Icon(Icons.book_outlined,
                                  size: 16, color: AppTheme.teacherPrimary),
                              const SizedBox(width: AppTheme.sm),
                              Expanded(
                                child: Text(
                                  '${a['subject_name'] ?? a['subject_id']} (${a['subject_id']})',
                                  style: AppTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                'Sem ${a['semester'] ?? '-'} • Sec ${a['section'] ?? '-'} • ${_fmtNum((a['weekly_hours'] as num?) ?? 0)}h',
                                style: AppTheme.bodySmall
                                    .copyWith(color: AppTheme.mediumGray),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppTheme.error),
                                tooltip: 'Remove allotment',
                                onPressed: () => _deactivate(a),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
