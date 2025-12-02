import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/leave_service.dart';

class HRHolidayControlsScreen extends StatefulWidget {
  const HRHolidayControlsScreen({super.key});

  @override
  State<HRHolidayControlsScreen> createState() =>
      _HRHolidayControlsScreenState();
}

class _HRHolidayControlsScreenState extends State<HRHolidayControlsScreen> {
  final _leaveService = LeaveService();
  final _formKey = GlobalKey<FormState>();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _holidays = [];
  Map<String, int> _monthSummary = {};
  bool _isLoading = true;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'National';

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadHolidays() async {
    setState(() => _isLoading = true);
    final holidays = await _leaveService.getHolidaysForMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    final summary = await _leaveService.getMonthSummary(
      _focusedDay.year,
      _focusedDay.month,
    );
    if (mounted) {
      setState(() {
        _holidays = holidays;
        _monthSummary = summary;
        _isLoading = false;
      });
    }
  }

  bool _isHoliday(DateTime day) {
    return _holidays.any((h) {
      final holidayDate = DateTime.parse(h['holiday_date']);
      return holidayDate.year == day.year &&
          holidayDate.month == day.month &&
          holidayDate.day == day.day &&
          h['is_holiday'] == true;
    });
  }

  bool _isWorkingDay(DateTime day) {
    return _holidays.any((h) {
      final holidayDate = DateTime.parse(h['holiday_date']);
      return holidayDate.year == day.year &&
          holidayDate.month == day.month &&
          holidayDate.day == day.day &&
          h['is_working_day'] == true;
    });
  }

  Map<String, dynamic>? _getHolidayForDay(DateTime day) {
    try {
      return _holidays.firstWhere((h) {
        final holidayDate = DateTime.parse(h['holiday_date']);
        return holidayDate.year == day.year &&
            holidayDate.month == day.month &&
            holidayDate.day == day.day;
      });
    } catch (e) {
      return null;
    }
  }

  void _showAddHolidayDialog() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedType = 'National';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.2),
                            const Color(0xFF059669).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_circle,
                          color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Add New Holiday',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Holiday Name',
                    prefixIcon: const Icon(Icons.celebration),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Holiday Type',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['National', 'Religious', 'College', 'Custom']
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final success = await _leaveService.addHoliday(
                              name: _nameController.text.trim(),
                              date: _selectedDay,
                              description: _descriptionController.text.trim(),
                              type: _selectedType,
                              createdBy: 'hr1',
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('✅ Holiday added successfully'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                                _loadHolidays();
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add Holiday'),
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

  void _showDayOptionsDialog(DateTime day) {
    final holiday = _getHolidayForDay(day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              DateFormat('EEEE, MMMM d, y').format(day),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            if (holiday != null) ...[
              _buildOptionTile(
                icon: Icons.edit,
                title: 'Edit Holiday',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(context);
                  // Show edit dialog
                },
              ),
              _buildOptionTile(
                icon: Icons.delete,
                title: 'Delete Holiday',
                color: const Color(0xFFEF4444),
                onTap: () async {
                  Navigator.pop(context);
                  final success =
                      await _leaveService.deleteHoliday(holiday['holiday_id']);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Holiday deleted'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _loadHolidays();
                  }
                },
              ),
            ] else ...[
              _buildOptionTile(
                icon: Icons.celebration,
                title: 'Mark as Holiday',
                color: const Color(0xFFEF4444),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await _leaveService.toggleDayType(
                    date: day,
                    isHoliday: true,
                    createdBy: 'hr1',
                  );
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Marked as holiday'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _loadHolidays();
                  }
                },
              ),
              _buildOptionTile(
                icon: Icons.work,
                title: 'Mark as Working Day',
                color: const Color(0xFF3B82F6),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await _leaveService.toggleDayType(
                    date: day,
                    isHoliday: false,
                    createdBy: 'hr1',
                  );
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Marked as working day'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _loadHolidays();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF10B981),
                      const Color(0xFF059669),
                      const Color(0xFF047857),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Holiday Controls',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.1),
                        const Color(0xFF059669).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStat(
                            'Holidays',
                            _monthSummary['holidays']?.toString() ?? '0',
                            const Color(0xFFEF4444)),
                      ),
                      Expanded(
                        child: _buildStat(
                            'Working',
                            _monthSummary['working_days']?.toString() ?? '0',
                            const Color(0xFF3B82F6)),
                      ),
                      Expanded(
                        child: _buildStat(
                            'Total',
                            _monthSummary['total_days']?.toString() ?? '0',
                            const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Calendar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onDayLongPressed: (selectedDay, focusedDay) {
                      _showDayOptionsDialog(selectedDay);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                      _loadHolidays();
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981),
                            const Color(0xFF059669)
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6),
                            const Color(0xFF60A5FA)
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        if (_isHoliday(day)) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEF4444).withOpacity(0.2),
                                  const Color(0xFFF87171).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }
                        if (_isWorkingDay(day)) {
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF3B82F6).withOpacity(0.2),
                                  const Color(0xFF60A5FA).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Legend
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegend('Holiday', const Color(0xFFEF4444)),
                      _buildLegend('Working', const Color(0xFF3B82F6)),
                      _buildLegend('Today', const Color(0xFF10B981)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHolidayDialog,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add),
        label: const Text('Add Holiday'),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
