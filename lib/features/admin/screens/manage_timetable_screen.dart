import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

/// Admin — Manage Timetable.
///
/// Class + day scoped editor over `school_timetable`. Every save goes
/// through [SchoolService.saveTimetableEntry], so teacher / room / class
/// clashes are rejected by the same rules the rest of the app uses.
class ManageTimetableScreen extends StatefulWidget {
  const ManageTimetableScreen({
    super.key,
    this.initialClassId,
    this.initialDay,
  });

  final String? initialClassId;
  final String? initialDay;

  @override
  State<ManageTimetableScreen> createState() => _ManageTimetableScreenState();
}

class _ManageTimetableScreenState extends State<ManageTimetableScreen> {
  final SchoolService _service = SchoolService();
  final AuthService _authService = AuthService();

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const List<Color> _subjectPalette = [
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF059669),
    Color(0xFF4F46E5),
  ];

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _periods = [];
  List<String> _teachers = [];
  String _selectedClassId = '';
  String _selectedClassLabel = '';
  String _selectedDay = 'Monday';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialClassId != null && widget.initialClassId!.isNotEmpty) {
      _selectedClassId = widget.initialClassId!;
    }
    if (widget.initialDay != null && _days.contains(widget.initialDay)) {
      _selectedDay = widget.initialDay!;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final role = await _authService.getCurrentUserRole();
      if (!const {'admin', 'sadmin', 'principal', 'superadmin'}
          .contains(role)) {
        if (!mounted) return;
        setState(() {
          _error = 'Only an administrator can edit the timetable.';
          _isLoading = false;
        });
        return;
      }

      final classes = await _service.getSchoolClasses();
      final seen = <String>{};
      final unique =
          classes.where((c) => seen.add(c['id']?.toString() ?? '')).toList();

      final ids = unique.map((c) => c['id']?.toString() ?? '').toSet();
      if (!ids.contains(_selectedClassId)) {
        _selectedClassId = unique.isNotEmpty
            ? unique.first['id']?.toString() ?? ''
            : _selectedClassId;
      }
      _syncClassLabel(unique);

      final teachers = await _service.getSchoolTeachersList();
      final periods = await _loadPeriods();

      if (!mounted) return;
      setState(() {
        _classes = unique;
        _teachers = teachers;
        _periods = periods;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load timetable: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadPeriods() {
    if (_selectedClassId.isEmpty) return Future.value([]);
    final selected = _classes.firstWhere(
      (c) => (c['id']?.toString() ?? '') == _selectedClassId,
      orElse: () => <String, dynamic>{},
    );
    return _service.getTimetableForClass(
      _selectedClassId,
      day: _selectedDay,
      className: selected['name']?.toString() ?? _selectedClassLabel,
      section: selected['section']?.toString(),
    );
  }

  /// Refreshes just the grid — used by day chips and after a save.
  Future<void> _reloadPeriods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final periods = await _loadPeriods();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load timetable: $e';
        _isLoading = false;
      });
    }
  }

  void _syncClassLabel(List<Map<String, dynamic>> classes) {
    final match = classes
        .where((c) => (c['id']?.toString() ?? '') == _selectedClassId)
        .toList();
    if (match.isNotEmpty) {
      final c = match.first;
      _selectedClassLabel = c['name']?.toString() ?? _selectedClassId;
    }
  }

  Future<void> _onClassChanged(String? id) async {
    if (id == null || id == _selectedClassId) return;
    setState(() => _selectedClassId = id);
    _syncClassLabel(_classes);
    await _reloadPeriods();
  }

  Future<void> _onDayChanged(String day) async {
    if (day == _selectedDay) return;
    setState(() => _selectedDay = day);
    await _reloadPeriods();
  }

  Color _subjectColor(String subject) {
    if (subject.isEmpty) return AppTheme.lightGray;
    final hash = subject.codeUnits.fold(0, (acc, c) => acc + c);
    return _subjectPalette[hash % _subjectPalette.length];
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _deleteSlot(Map<String, dynamic> slot) async {
    final id = slot['id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Text('Delete slot?'),
        content: Text(
          'Period ${slot['period']} (${slot['subject'] ?? '—'}) on '
          '$_selectedDay will be removed from $_selectedClassLabel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _service.deleteTimetableEntry(id);
    if (!mounted) return;
    if (ok) {
      _toast('Slot deleted');
      await _reloadPeriods();
    } else {
      _toast('Could not delete slot', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.adminPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Manage Timetable',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _reloadPeriods,
          ),
        ],
      ),
      body: _isLoading && _classes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(),
                Expanded(child: _buildBody()),
              ],
            ),
      floatingActionButton: _error != null || _classes.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.adminPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Period',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _showSlotEditor(),
            ),
    );
  }

  Widget _buildFilters() {
    final classLabel = _classes
        .where((c) => (c['id']?.toString() ?? '') == _selectedClassId)
        .map((c) => c['name']?.toString() ?? c['id']?.toString() ?? '')
        .firstOrNull;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue:
                _classes.any((c) => c['id']?.toString() == _selectedClassId)
                    ? _selectedClassId
                    : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Class',
              prefixIcon: const Icon(Icons.class_),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            items: _classes
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id']?.toString() ?? '',
                    child: Text(
                      '${c['name'] ?? c['id']}'
                      '${(c['section'] ?? '').toString().isNotEmpty && !(c['name'] ?? '').toString().contains(c['section'].toString()) ? ' · Sec ${c['section']}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _isLoading ? null : _onClassChanged,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _days.map((day) {
                final selected = day == _selectedDay;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(day),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AppTheme.adminPrimary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.mediumGray,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                    onSelected: _isLoading ? null : (_) => _onDayChanged(day),
                  ),
                );
              }).toList(),
            ),
          ),
          if (classLabel != null && classLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$classLabel · $_selectedDay · ${_periods.length} period(s)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _CenteredMessage(
        icon: Icons.lock_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_periods.isEmpty) {
      return _CenteredMessage(
        icon: Icons.event_busy,
        message:
            'No periods scheduled for $_selectedDay in $_selectedClassLabel.\n'
            'Use “Add Period” to build the day.',
      );
    }

    final sorted = List<Map<String, dynamic>>.from(_periods)
      ..sort((a, b) => (int.tryParse(a['period']?.toString() ?? '') ?? 0)
          .compareTo(int.tryParse(b['period']?.toString() ?? '') ?? 0));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildSlotCard(sorted[index]),
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    final subject = slot['subject']?.toString() ?? 'Unassigned';
    final color = _subjectColor(subject);
    final teacher = slot['teacher_username']?.toString() ?? '';
    final teacherName = slot['teacher_name']?.toString() ?? '';
    final room = slot['room']?.toString() ?? '';
    final time = [
      slot['start_time']?.toString() ?? '',
      slot['end_time']?.toString() ?? '',
    ].where((t) => t.isNotEmpty).join(' – ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Text(
              'P${slot['period'] ?? '?'}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    if (time.isNotEmpty) _meta(Icons.schedule, time),
                    if (teacher.isNotEmpty)
                      _meta(
                        Icons.person_outline,
                        teacherName.isNotEmpty ? teacherName : teacher,
                      ),
                    if (room.isNotEmpty)
                      _meta(Icons.meeting_room_outlined, room),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            color: AppTheme.adminPrimary,
            onPressed: () => _showSlotEditor(existingSlot: slot),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            color: AppTheme.error,
            onPressed: () => _deleteSlot(slot),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.lightGray),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.mediumGray),
        ),
      ],
    );
  }

  void _showSlotEditor({Map<String, dynamic>? existingSlot}) {
    final isEdit = existingSlot != null;
    final periodCtrl = TextEditingController(
      text: isEdit
          ? existingSlot['period']?.toString() ?? '1'
          : _suggestNextPeriod().toString(),
    );
    final slotTime = _suggestTime(_suggestNextPeriod());
    final startCtrl = TextEditingController(
      text: isEdit ? existingSlot['start_time']?.toString() ?? '' : slotTime.$1,
    );
    final endCtrl = TextEditingController(
      text: isEdit ? existingSlot['end_time']?.toString() ?? '' : slotTime.$2,
    );
    final subjectCtrl = TextEditingController(
      text: isEdit ? existingSlot['subject']?.toString() ?? '' : '',
    );
    final roomCtrl = TextEditingController(
      text: isEdit ? existingSlot['room']?.toString() ?? '' : 'Room 101',
    );
    final formKey = GlobalKey<FormState>();

    String selectedDay =
        isEdit ? existingSlot['day']?.toString() ?? _selectedDay : _selectedDay;
    String? selectedTeacher = isEdit
        ? existingSlot['teacher_username']?.toString()
        : (_teachers.isNotEmpty ? _teachers.first : null);
    if (selectedTeacher != null &&
        selectedTeacher.isNotEmpty &&
        !_teachers.contains(selectedTeacher)) {
      _teachers = [..._teachers, selectedTeacher]..sort();
    }
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (selectedTeacher == null || selectedTeacher!.isEmpty) {
                setSheetState(() {});
                return;
              }
              setSheetState(() => saving = true);
              try {
                await _service.saveTimetableEntry(
                  id: isEdit ? existingSlot['id']?.toString() : null,
                  classId: _selectedClassId,
                  day: selectedDay,
                  period: int.tryParse(periodCtrl.text.trim()) ?? 1,
                  startTime: startCtrl.text.trim(),
                  endTime: endCtrl.text.trim(),
                  subject: subjectCtrl.text.trim(),
                  teacherUsername: selectedTeacher!,
                  room: roomCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(sheetContext);
                _toast(isEdit ? 'Slot updated' : 'Slot published');
                if (selectedDay != _selectedDay) {
                  setState(() => _selectedDay = selectedDay);
                }
                await _reloadPeriods();
              } catch (e) {
                if (!mounted) return;
                setSheetState(() => saving = false);
                _toast(
                  e.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Edit Period' : 'Add Period',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.dark,
                                  ),
                                ),
                                Text(
                                  _selectedClassLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.lightGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedDay,
                              decoration: _decoration('Day'),
                              items: _days
                                  .map((d) => DropdownMenuItem(
                                      value: d, child: Text(d)))
                                  .toList(),
                              onChanged: saving
                                  ? null
                                  : (v) {
                                      if (v != null) {
                                        setSheetState(() => selectedDay = v);
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: periodCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _decoration('Period (1-8)'),
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 1 || n > 8) {
                                  return 'Enter 1-8';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startCtrl,
                              decoration: _decoration('Start Time'),
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: endCtrl,
                              decoration: _decoration('End Time'),
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: subjectCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration('Subject'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Enter a subject' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedTeacher,
                              isExpanded: true,
                              decoration: _decoration('Teacher'),
                              items: _teachers
                                  .map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(
                                          t,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: saving
                                  ? null
                                  : (v) =>
                                      setSheetState(() => selectedTeacher = v),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: roomCtrl,
                              decoration: _decoration('Room'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.adminPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          onPressed: saving ? null : submit,
                          child: saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEdit
                                      ? 'Update Period'
                                      : 'Publish Period (clash checked)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    );
  }

  int _suggestNextPeriod() {
    final used = _periods
        .map((p) => int.tryParse(p['period']?.toString() ?? '') ?? 0)
        .toSet();
    for (var i = 1; i <= 8; i++) {
      if (!used.contains(i)) return i;
    }
    return 8;
  }

  (String, String) _suggestTime(int period) {
    const startMinutes = 8 * 60;
    final start = startMinutes + (period - 1) * 45;
    String fmt(int minutes) {
      final h24 = (minutes ~/ 60) % 24;
      final m = minutes % 60;
      final suffix = h24 >= 12 ? 'PM' : 'AM';
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      return '${h12.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')} $suffix';
    }

    return (fmt(start), fmt(start + 45));
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.lightGray),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.mediumGray),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
