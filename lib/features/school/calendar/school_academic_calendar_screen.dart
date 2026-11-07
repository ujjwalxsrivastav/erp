import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../services/school_calendar_service.dart';
import '../../../services/school_export_service.dart';

class SchoolAcademicCalendarScreen extends StatefulWidget {
  const SchoolAcademicCalendarScreen({super.key});

  @override
  State<SchoolAcademicCalendarScreen> createState() =>
      _SchoolAcademicCalendarScreenState();
}

class _SchoolAcademicCalendarScreenState
    extends State<SchoolAcademicCalendarScreen>
    with SingleTickerProviderStateMixin {
  final SchoolCalendarService _calendarService = SchoolCalendarService();

  late TabController _tabController;
  bool _isLoading = true;
  String? _loadError;
  late String _selectedYear;
  String _selectedCategory = 'All';
  String _selectedAudience = 'all';
  String _instituteName = '';
  String _role = '';
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildUsername;

  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic> _metrics = {};

  // Month grid navigation state
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.month >= 4 ? '${now.year}-${now.year + 1}' : '${now.year - 1}-${now.year}';
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _tabController = TabController(length: 4, vsync: this);
    _checkPermissions().then((_) => _loadCalendarData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final username = await AuthService().getCurrentUsername() ?? '';
    final role = username.isEmpty ? '' : (await AuthService().getLiveUserRole(username) ?? '').toLowerCase();
    final normalizedRole = role == 'sadmin' ? 'admin' : role;
    List<Map<String, dynamic>> children = [];
    if (normalizedRole == 'parent' && username.isNotEmpty) {
      children = await SchoolService().getParentChildren(username);
    }
    if (!mounted) return;
    setState(() {
      _role = normalizedRole;
      _canManage = {'admin', 'principal', 'superadmin'}.contains(normalizedRole);
      _children = children;
      if (children.isNotEmpty) {
        _selectedChildUsername = children.first['username']?.toString() ?? children.first['id']?.toString();
      }
    });
  }
  Future<void> _loadCalendarData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final name = await SchoolService().getSchoolInstituteName();
      if (name != null && name.isNotEmpty) {
        _instituteName = name;
      }

      final events = await _calendarService.getEventsForScope(
        academicYear: _selectedYear,
        category: _selectedCategory,
        targetAudience: _canManage ? _selectedAudience : null,
        studentUsername: _selectedChildUsername,
      );

      final metrics = _calendarService.calculateMetrics(events);

      setState(() {
        _events = events;
        _metrics = metrics;
        _isLoading = false;
        if (_selectedDay == null && events.isNotEmpty) {
          try {
            _selectedDay =
                DateTime.parse(events.first['start_date'].toString());
          } catch (_) {
            _selectedDay = DateTime.now();
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Calendar could not be loaded. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadCalendarData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
              children: [
                if (_role == 'parent') _buildChildPicker(),
                _buildMetricsRibbon(),
                _buildFilterChipsBar(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMonthGridView(),
                      _buildAgendaTimelineView(),
                      _buildTermMilestonesView(),
                      _buildHolidayRegisterView(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEventDialog(),
              backgroundColor: const Color(0xFF0F766E),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Event',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Academic Calendar & Milestones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedYear,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          Text(
            '$_instituteName • Session Schedule & Compliance',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF115E59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            dropdownColor: const Color(0xFF115E59),
            value: _selectedYear,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            items: _availableAcademicYears.map((year) {
              final now = DateTime.now();
              final currentSession = now.month >= 4
                  ? '${now.year}-${now.year + 1}'
                  : '${now.year - 1}-${now.year}';
              final label = year == currentSession
                  ? '$year (Current)'
                  : year == _selectedYear
                      ? '$year (Active)'
                      : year;
              return DropdownMenuItem(
                value: year,
                child: Text(label),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null && val != _selectedYear) {
                final startYear =
                    int.tryParse(val.split('-').first) ?? DateTime.now().year;
                setState(() {
                  _selectedYear = val;
                  _focusedMonth = DateTime(startYear, 4, 1);
                  _selectedDay = DateTime(startYear, 4, 1);
                });
                _loadCalendarData();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined, color: Colors.white),
          tooltip: 'Sync & Export Options',
          onSelected: (val) {
            if (val == 'excel') {
              SchoolExportService.exportSchoolAcademicCalendarExcel(
                context: context,
                events: _events,
                academicYear: _selectedYear,
                instituteName: _instituteName,
              );
            } else if (val == 'ics') {
              _calendarService.downloadIcsFile(
                context: context,
                events: _events,
                filename: 'Academic_Calendar_$_selectedYear.ics',
              );
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'excel',
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined,
                      color: Color(0xFF0F766E), size: 18),
                  SizedBox(width: 10),
                  Text('Export Dual-Sheet Excel (.xlsx)'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'ics',
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF3B82F6), size: 18),
                  SizedBox(width: 10),
                  Text('Sync iCal / Google Calendar (.ics)'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  List<String> get _availableAcademicYears {
    final now = DateTime.now();
    final currentBase = now.month >= 4 ? now.year : now.year - 1;
    final years = <String>{};
    for (int offset = -4; offset <= 3; offset++) {
      final start = currentBase + offset;
      years.add('$start-${start + 1}');
    }
    years.add(_selectedYear);
    final list = years.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  Widget _buildChildPicker() {
    if (_children.isEmpty) return const ListTile(title: Text('No linked students found.'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedChildUsername,
        decoration: const InputDecoration(labelText: 'Calendar for child', border: OutlineInputBorder()),
        items: _children.map((child) {
          final username = child['username']?.toString() ?? child['id']?.toString() ?? '';
          final name = child['name']?.toString() ?? child['student_name']?.toString() ?? username;
          return DropdownMenuItem(value: username, child: Text(name));
        }).where((item) => item.value?.isNotEmpty == true).toList(),
        onChanged: (value) {
          setState(() => _selectedChildUsername = value);
          _loadCalendarData();
        },
      ),
    );
  }
  Widget _buildMetricsRibbon() {
    final total = _metrics['total_events'] ?? _events.length;
    final workingDays = _metrics['working_instructional_days'] ?? '—';
    final exams = _metrics['examinations'] ?? 0;
    final holidays = _metrics['holidays'] ?? 0;
    final upcoming = _metrics['upcoming_next_30_days'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMetricTile(
              label: 'Total Milestones',
              value: '$total',
              icon: Icons.event_note,
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(width: 12),
            _buildMetricTile(
              label: 'Instructional Days',
              value: '$workingDays',
              icon: Icons.school_outlined,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(width: 12),
            _buildMetricTile(
              label: 'Examinations',
              value: '$exams',
              icon: Icons.quiz_outlined,
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 12),
            _buildMetricTile(
              label: 'Official Holidays',
              value: '$holidays',
              icon: Icons.beach_access_outlined,
              color: const Color(0xFFEF4444),
            ),
            const SizedBox(width: 12),
            _buildMetricTile(
              label: 'Upcoming (30d)',
              value: '$upcoming',
              icon: Icons.notifications_active_outlined,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: color),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Filter: ',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black54),
            ),
            const SizedBox(width: 6),
            ...['All', ...SchoolCalendarService.categories].map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor:
                      const Color(0xFF0F766E).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF0F766E),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? const Color(0xFF0F766E) : Colors.black87,
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedCategory = cat);
                    _loadCalendarData();
                  },
                ),
              );
            }),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: Colors.grey.shade300),
            const SizedBox(width: 12),
            if (_canManage) ...SchoolCalendarService.audiences.map((aud) {
              final isSelected = _selectedAudience == aud;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(aud.toUpperCase()),
                  selected: isSelected,
                  selectedColor:
                      const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? const Color(0xFF3B82F6) : Colors.black54,
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedAudience = aud);
                    _loadCalendarData();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF0F766E),
        unselectedLabelColor: Colors.black54,
        indicatorColor: const Color(0xFF0F766E),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.calendar_month, size: 18), text: 'Month Grid'),
          Tab(
              icon: Icon(Icons.view_timeline_outlined, size: 18),
              text: 'Agenda'),
          Tab(
              icon: Icon(Icons.stairs_outlined, size: 18),
              text: 'Term Milestones'),
          Tab(
              icon: Icon(Icons.beach_access_outlined, size: 18),
              text: 'Holidays Register'),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: MONTH CALENDAR GRID VIEW
  // ===========================================================================

  void _changeMonth(int delta) {
    final newMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    _onMonthChanged(newMonth);
  }

  void _changeYear(int delta) {
    final newMonth =
        DateTime(_focusedMonth.year + delta, _focusedMonth.month, 1);
    _onMonthChanged(newMonth);
  }

  String _calcAcademicYearForDate(DateTime dt) {
    final startYear = dt.month >= 4 ? dt.year : dt.year - 1;
    return '$startYear-${startYear + 1}';
  }

  void _onMonthChanged(DateTime newMonth) {
    final newAcadYear = _calcAcademicYearForDate(newMonth);
    final bool yearChanged = newAcadYear != _selectedYear;
    setState(() {
      _focusedMonth = newMonth;
      if (_selectedDay != null) {
        final daysInMonth =
            DateTime(newMonth.year, newMonth.month + 1, 0).day;
        final clampedDay = _selectedDay!.day.clamp(1, daysInMonth);
        _selectedDay = DateTime(newMonth.year, newMonth.month, clampedDay);
      }
      if (yearChanged) {
        _selectedYear = newAcadYear;
      }
    });
    if (yearChanged) {
      _loadCalendarData();
    }
  }

  void _jumpToToday() {
    final now = DateTime.now();
    final todayMonth = DateTime(now.year, now.month, 1);
    final newAcadYear = _calcAcademicYearForDate(now);
    final bool yearChanged = newAcadYear != _selectedYear;
    setState(() {
      _focusedMonth = todayMonth;
      _selectedDay = DateTime(now.year, now.month, now.day);
      if (yearChanged) {
        _selectedYear = newAcadYear;
      }
    });
    if (yearChanged) {
      _loadCalendarData();
    }
  }

  void _jumpToSessionStart() {
    final startYear =
        int.tryParse(_selectedYear.split('-').first) ?? DateTime.now().year;
    setState(() {
      _focusedMonth = DateTime(startYear, 4, 1);
      _selectedDay = DateTime(startYear, 4, 1);
    });
  }

  void _showMonthYearPicker() {
    int pickerYear = _focusedMonth.year;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jump to Month & Year',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Academic Session: $_selectedYear',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Year Selector Bar with << Year >>
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Color(0xFF0F766E)),
                          tooltip: 'Previous Year',
                          onPressed: () {
                            setPickerState(() => pickerYear--);
                          },
                        ),
                        Text(
                          '$pickerYear',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: Color(0xFF0F766E)),
                          tooltip: 'Next Year',
                          onPressed: () {
                            setPickerState(() => pickerYear++);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 12 Months Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 12,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2.0,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, i) {
                      final monthIndex = i + 1;
                      final isSelected = pickerYear == _focusedMonth.year &&
                          monthIndex == _focusedMonth.month;
                      final isSessionStart = monthIndex == 4;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _onMonthChanged(DateTime(pickerYear, monthIndex, 1));
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0F766E)
                                : isSessionStart
                                    ? const Color(0xFFCCFBF1)
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0F766E)
                                  : isSessionStart
                                      ? const Color(0xFF14B8A6)
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getMonthName(monthIndex).substring(0, 3),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              if (isSessionStart && !isSelected)
                                const Text(
                                  'Session Start',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNavIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0F766E)),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickJumpChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF0F766E)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F766E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthKpiPill({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarDayCell({
    required int dayNumber,
    required DateTime cellDate,
    required bool isSelected,
    required bool isToday,
    required bool isSunday,
    required bool isHoliday,
    required bool isExam,
    required List<Map<String, dynamic>> dayEvents,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDay = cellDate;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : isToday
                  ? const Color(0xFFECFDF5)
                  : isHoliday
                      ? const Color(0xFFFFF1F2)
                      : isExam
                          ? const Color(0xFFFAF5FF)
                          : isSunday
                              ? const Color(0xFFFAFAFA)
                              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : isToday
                    ? const Color(0xFF10B981)
                    : isHoliday
                        ? const Color(0xFFFECDD3)
                        : isExam
                            ? const Color(0xFFE9D5FF)
                            : const Color(0xFFE2E8F0),
            width: isToday || isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top indicator row (TODAY badge or icon)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isToday)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: isSelected ? Colors.white : Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 4),
                if (isHoliday && !isSelected)
                  const Icon(Icons.beach_access,
                      size: 10, color: Color(0xFFE11D48))
                else if (isExam && !isSelected)
                  const Icon(Icons.assignment,
                      size: 10, color: Color(0xFF8B5CF6))
                else
                  const SizedBox(width: 4),
              ],
            ),
            // Day Number
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday || isHoliday || isExam
                    ? FontWeight.bold
                    : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isHoliday || isSunday
                        ? const Color(0xFFE11D48)
                        : isExam
                            ? const Color(0xFF7C3AED)
                            : isToday
                                ? const Color(0xFF047857)
                                : const Color(0xFF1E293B),
              ),
            ),
            // Event Dots Row
            SizedBox(
              height: 8,
              child: dayEvents.isEmpty
                  ? const SizedBox()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...dayEvents.take(3).map((e) {
                          final cat = e['category']?.toString() ?? 'Academic';
                          final dotColor = isSelected
                              ? Colors.white
                              : SchoolCalendarService.getCategoryColor(cat);
                          return Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                        if (dayEvents.length > 3)
                          Text(
                            '+',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F766E),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGridView() {
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1)
        .weekday; // 1 = Mon, 7 = Sun
    final monthName = _getMonthName(_focusedMonth.month);

    // Calculate month statistics
    int holidaysCount = 0;
    int examsCount = 0;
    int eventsCount = 0;
    int sundaysCount = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      if (cellDate.weekday == DateTime.sunday) {
        sundaysCount++;
      }
      final dayEvents = _events.where((e) {
        try {
          final start = DateTime.parse(e['start_date'].toString());
          final end = DateTime.parse(e['end_date'].toString());
          return !cellDate
                  .isBefore(DateTime(start.year, start.month, start.day)) &&
              !cellDate.isAfter(DateTime(end.year, end.month, end.day));
        } catch (_) {
          return false;
        }
      }).toList();

      if (dayEvents.any(
          (e) => e['is_holiday'] == true || e['category'] == 'Holiday')) {
        holidaysCount++;
      }
      if (dayEvents.any((e) => e['category'] == 'Examination')) {
        examsCount++;
      }
      eventsCount += dayEvents.length;
    }

    final workingDays =
        (daysInMonth - sundaysCount - holidaysCount).clamp(0, daysInMonth);

    final selectedDayEvents = _events.where((e) {
      if (_selectedDay == null) return false;
      try {
        final start = DateTime.parse(e['start_date'].toString());
        final end = DateTime.parse(e['end_date'].toString());
        final sel = DateTime(
            _selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
        return !sel.isBefore(DateTime(start.year, start.month, start.day)) &&
            !sel.isAfter(DateTime(end.year, end.month, end.day));
      } catch (_) {
        return false;
      }
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month navigation header card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildNavIconButton(
                          icon: Icons.keyboard_double_arrow_left,
                          tooltip: 'Previous Academic Year (-1 Yr)',
                          onPressed: () => _changeYear(-1),
                        ),
                        const SizedBox(width: 6),
                        _buildNavIconButton(
                          icon: Icons.chevron_left,
                          tooltip: 'Previous Month',
                          onPressed: () => _changeMonth(-1),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showMonthYearPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF99F6E4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month,
                                size: 18, color: Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Text(
                              '$monthName ${_focusedMonth.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down,
                                size: 18, color: Color(0xFF0F766E)),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildNavIconButton(
                          icon: Icons.chevron_right,
                          tooltip: 'Next Month',
                          onPressed: () => _changeMonth(1),
                        ),
                        const SizedBox(width: 6),
                        _buildNavIconButton(
                          icon: Icons.keyboard_double_arrow_right,
                          tooltip: 'Next Academic Year (+1 Yr)',
                          onPressed: () => _changeYear(1),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Quick jump chips row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQuickJumpChip(
                      label: 'Today',
                      icon: Icons.today,
                      onTap: _jumpToToday,
                    ),
                    const SizedBox(width: 10),
                    _buildQuickJumpChip(
                      label: 'Session Start (Apr)',
                      icon: Icons.flight_takeoff,
                      onTap: _jumpToSessionStart,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Month KPI Statistics Strip
          Row(
            children: [
              _buildMonthKpiPill(
                title: 'Working Days',
                value: '$workingDays Days',
                icon: Icons.work_outline,
                color: const Color(0xFF0F766E),
                bgColor: const Color(0xFFF0FDFA),
              ),
              const SizedBox(width: 8),
              _buildMonthKpiPill(
                title: 'Holidays',
                value: '$holidaysCount Days',
                icon: Icons.beach_access_outlined,
                color: const Color(0xFFE11D48),
                bgColor: const Color(0xFFFFF1F2),
              ),
              const SizedBox(width: 8),
              _buildMonthKpiPill(
                title: 'Examinations',
                value: '$examsCount Days',
                icon: Icons.assignment_outlined,
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFFAF5FF),
              ),
              const SizedBox(width: 8),
              _buildMonthKpiPill(
                title: 'Milestones',
                value: '$eventsCount Events',
                icon: Icons.flag_outlined,
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calendar Card (7-day header + Day Grid)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 7-day header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ].map((day) {
                      final isSun = day == 'Sun';
                      final isSat = day == 'Sat';
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isSun
                                  ? const Color(0xFFE11D48)
                                  : isSat
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // Day Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: (firstWeekday - 1) + daysInMonth,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    if (index < firstWeekday - 1) {
                      return const SizedBox();
                    }
                    final dayNumber = index - (firstWeekday - 2);
                    final cellDate = DateTime(
                        _focusedMonth.year, _focusedMonth.month, dayNumber);
                    final isSelected = _selectedDay != null &&
                        _selectedDay!.year == cellDate.year &&
                        _selectedDay!.month == cellDate.month &&
                        _selectedDay!.day == cellDate.day;

                    final now = DateTime.now();
                    final isToday = now.year == cellDate.year &&
                        now.month == cellDate.month &&
                        now.day == cellDate.day;

                    // Find events on this date
                    final dayEvents = _events.where((e) {
                      try {
                        final start =
                            DateTime.parse(e['start_date'].toString());
                        final end = DateTime.parse(e['end_date'].toString());
                        return !cellDate.isBefore(DateTime(
                                start.year, start.month, start.day)) &&
                            !cellDate.isAfter(
                                DateTime(end.year, end.month, end.day));
                      } catch (_) {
                        return false;
                      }
                    }).toList();

                    final isHoliday = dayEvents.any((e) =>
                        e['is_holiday'] == true || e['category'] == 'Holiday');
                    final isExam =
                        dayEvents.any((e) => e['category'] == 'Examination');
                    final isSunday = cellDate.weekday == DateTime.sunday;

                    return _buildCalendarDayCell(
                      dayNumber: dayNumber,
                      cellDate: cellDate,
                      isSelected: isSelected,
                      isToday: isToday,
                      isSunday: isSunday,
                      isHoliday: isHoliday,
                      isExam: isExam,
                      dayEvents: dayEvents,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category Legend Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(
                    color: const Color(0xFF10B981), label: 'Academic'),
                _buildLegendItem(
                    color: const Color(0xFFEF4444), label: 'Holiday'),
                _buildLegendItem(
                    color: const Color(0xFF8B5CF6), label: 'Examination'),
                _buildLegendItem(
                    color: const Color(0xFF3B82F6),
                    label: 'Sports & Activities'),
                _buildLegendItem(
                    color: const Color(0xFFF59E0B), label: 'Parent / Meeting'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selected Day Event Detail Card
          if (_selectedDay != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0F766E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event_available,
                            color: Color(0xFF0F766E), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedDay!.day} ${_getMonthName(_selectedDay!.month)} ${_selectedDay!.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${selectedDayEvents.length} scheduled item${selectedDayEvents.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canManage)
                        FilledButton.tonalIcon(
                          onPressed: () => _showAddEventDialog(
                              prefilledDate: _selectedDay),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Event',
                              style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF0F766E).withValues(alpha: 0.1),
                            foregroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (selectedDayEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_note_outlined,
                                size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'No special events or exams scheduled for this date.',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...selectedDayEvents.map((e) => _buildEventCard(e)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: AGENDA TIMELINE VIEW
  // ===========================================================================

  Widget _buildAgendaTimelineView() {
    if (_events.isEmpty) {
      return const Center(child: Text('No events matching selected filters.'));
    }

    // Group events by month
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final e in _events) {
      try {
        final dt = DateTime.parse(e['start_date'].toString());
        final key = '${_getMonthName(dt.month)} ${dt.year}';
        grouped.putIfAbsent(key, () => []).add(e);
      } catch (_) {}
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final monthKey = grouped.keys.elementAt(index);
        final monthEvents = grouped[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      monthKey,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${monthEvents.length} Milestones',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ...monthEvents.map((e) => _buildEventCard(e)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: TERM MILESTONES VIEW
  // ===========================================================================

  Widget _buildTermMilestonesView() {
    final term1Events = _events.where((e) => e['term'] == 'Term 1').toList();
    final term2Events = _events.where((e) => e['term'] == 'Term 2').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTermBlock(
            termTitle: 'TERM 1: Foundation & Formative Cycle',
            dateRange: 'April 2026 — September 2026',
            events: term1Events,
            accentColor: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 20),
          _buildTermBlock(
            termTitle: 'TERM 2: Summative & Board Evaluation Cycle',
            dateRange: 'October 2026 — March 2027',
            events: term2Events,
            accentColor: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildTermBlock({
    required String termTitle,
    required String dateRange,
    required List<Map<String, dynamic>> events,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom:
                      BorderSide(color: accentColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      termTitle,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: accentColor),
                    ),
                    Text(dateRange,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor),
                  ),
                  child: Text(
                    '${events.length} Milestones',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accentColor),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: events.map((e) => _buildEventCard(e)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: STATUTORY HOLIDAYS REGISTER
  // ===========================================================================

  Widget _buildHolidayRegisterView() {
    final holidays = _events
        .where((e) => e['is_holiday'] == true || e['category'] == 'Holiday')
        .toList();

    if (holidays.isEmpty) {
      return const Center(
          child: Text('No holidays listed for this selection.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: holidays.length,
      itemBuilder: (context, index) {
        final h = holidays[index];
        int dayCount = 1;
        try {
          final s = DateTime.parse(h['start_date'].toString());
          final e = DateTime.parse(h['end_date'].toString());
          dayCount = e.difference(s).inDays + 1;
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.beach_access, color: Colors.red, size: 20),
                      Text(
                        '$dayCount d',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: Colors.red),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h['title']?.toString() ?? 'Holiday',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${h['start_date']} to ${h['end_date']}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if ((h['description']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          h['description']?.toString() ?? '',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OFFICIAL',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // EVENT CARD COMPONENT
  // ===========================================================================

  Widget _buildEventCard(Map<String, dynamic> e) {
    final cat = e['category']?.toString() ?? 'Academic';
    final color = SchoolCalendarService.getCategoryColor(cat);
    final icon = SchoolCalendarService.getCategoryIcon(cat);
    final audience = e['target_audience']?.toString().toUpperCase() ?? 'ALL';
    final venue = e['venue']?.toString() ?? 'Main Campus';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        e['title']?.toString() ?? 'Untitled Event',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${e['start_date']}${e['end_date'] != e['start_date'] ? ' to ${e['end_date']}' : ''}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.access_time,
                        size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      e['is_all_day'] == true
                          ? 'All Day'
                          : '${e['start_time']} - ${e['end_time']}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      venue,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.people_outline,
                        size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Audience: $audience',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                if ((e['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    e['description'].toString(),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          if (_canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
              onSelected: (action) async {
                if (action == 'delete') {
                  final id = e['id']?.toString() ?? '';
                  if (id.isNotEmpty) {
                    await _calendarService.deleteAcademicEvent(id);
                    _loadCalendarData();
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete Event', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ADD EVENT DIALOG
  // ===========================================================================

  void _showAddEventDialog({DateTime? prefilledDate}) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    String category = 'Academic';
    String term = 'Term 1';
    String audience = 'all';
    DateTime startDate = prefilledDate ?? DateTime.now();
    DateTime endDate = prefilledDate ?? DateTime.now();
    bool isAllDay = true;
    bool isHoliday = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.event, color: Color(0xFF0F766E)),
                  SizedBox(width: 10),
                  Text('Add Academic Calendar Event',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Event Title *',
                          hintText:
                              'e.g. Periodic Assessment 2 / Science Exhibition',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder()),
                              items: SchoolCalendarService.categories
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() {
                                    category = v;
                                    isHoliday = v == 'Holiday';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: term,
                              decoration: const InputDecoration(
                                  labelText: 'Term',
                                  border: OutlineInputBorder()),
                              items: SchoolCalendarService.terms
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => term = v ?? term),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2028),
                                );
                                if (d != null) {
                                  setDialogState(() {
                                    startDate = d;
                                    if (endDate.isBefore(startDate))
                                      endDate = startDate;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.date_range, size: 18),
                                ),
                                child: Text(
                                    '${startDate.toLocal()}'.split(' ')[0]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime(2028),
                                );
                                if (d != null)
                                  setDialogState(() => endDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.date_range, size: 18),
                                ),
                                child:
                                    Text('${endDate.toLocal()}'.split(' ')[0]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: audience,
                              decoration: const InputDecoration(
                                  labelText: 'Target Audience',
                                  border: OutlineInputBorder()),
                              items: SchoolCalendarService.audiences
                                  .map((a) => DropdownMenuItem(
                                      value: a, child: Text(a.toUpperCase())))
                                  .toList(),
                              onChanged: (v) => setDialogState(
                                  () => audience = v ?? audience),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: venueCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Venue',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: isAllDay,
                            onChanged: (v) =>
                                setDialogState(() => isAllDay = v ?? true),
                          ),
                          const Text('All Day Event'),
                          const SizedBox(width: 16),
                          Checkbox(
                            value: isHoliday,
                            onChanged: (v) =>
                                setDialogState(() => isHoliday = v ?? false),
                          ),
                          const Text('Official Holiday'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description / Remarks',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E)),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _calendarService.createAcademicEvent(
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: category,
                      term: term,
                      startDate: '${startDate.toLocal()}'.split(' ')[0],
                      endDate: '${endDate.toLocal()}'.split(' ')[0],
                      isAllDay: isAllDay,
                      isHoliday: isHoliday,
                      targetAudience: audience,
                      venue: venueCtrl.text.trim(),
                      academicYear: _selectedYear,
                    );
                    _loadCalendarData();
                  },
                  child: const Text('Publish Event',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }
}
