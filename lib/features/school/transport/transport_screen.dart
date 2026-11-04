import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  final _schoolService = SchoolService();

  bool _isLoading = true;
  String? _errorMessage;

  // Routes and Roster
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _transportRoster = [];
  Map<String, dynamic>? _selectedRoute;
  String _selectedStop = '__all__';
  String _searchQuery = '';

  // Active Trip Shift: 'Morning Pickup' (Aate time) or 'Evening Drop' (Jaate time)
  String _activeShift = 'Morning Pickup';

  // Attendance Logs & Discrepancies
  List<Map<String, dynamic>> _busAttendanceLogs = [];
  List<Map<String, dynamic>> _discrepancies = [];
  List<Map<String, dynamic>> _gatePasses = [];

  // Expanded route index
  int _expandedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final routes = await _schoolService.getTransportRoutes();
      final roster = await _schoolService.getTransportRoster();
      final attLogs = await _schoolService.getBusAttendanceLogs();
      final discrepancies = await _schoolService.getTransportTripDiscrepancies();
      final passes = await _schoolService.getGatePasses();

      if (!mounted) return;
      setState(() {
        _routes = routes;
        _transportRoster = roster;
        _busAttendanceLogs = attLogs;
        _discrepancies = discrepancies;
        _gatePasses = passes;
        if (routes.isNotEmpty && _selectedRoute == null) {
          _selectedRoute = routes.first;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load transport and fleet records. Tap to retry.';
      });
    }
  }

  // Record stop-by-stop boarding or drop
  Future<void> _markStudentTripStatus({
    required Map<String, dynamic> student,
    required String action, // 'Boarded', 'Dropped', 'Absent', 'ParentHandover'
    String? customStop,
    String? note,
  }) async {
    final sid = student['student_id']?.toString() ?? '';
    final sname = student['name']?.toString() ?? 'Student';
    final routeId = student['route_id']?.toString() ?? (_selectedRoute?['route_no'] ?? 'Route 1');
    final stop = customStop ??
        (_activeShift == 'Morning Pickup'
            ? (student['pickup_stop'] ?? 'School Gate')
            : (student['drop_stop'] ?? 'School Gate'));

    await _schoolService.recordBusAttendance(
      routeId: routeId,
      stopName: stop,
      studentId: sid,
      studentName: sname,
      action: action,
      shift: _activeShift,
      notes: note,
      recordedBy: 'Conductor',
    );

    // Refresh logs and discrepancies
    final updatedLogs = await _schoolService.getBusAttendanceLogs();
    final updatedDiscrepancies = await _schoolService.getTransportTripDiscrepancies();

    if (!mounted) return;
    setState(() {
      _busAttendanceLogs = updatedLogs;
      _discrepancies = updatedDiscrepancies;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$sname marked as $action in $_activeShift at $stop'),
        backgroundColor: action == 'Boarded' || action == 'Dropped'
            ? const Color(0xFF10B981)
            : action == 'ParentHandover'
                ? const Color(0xFFD97706)
                : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Resolve safety mismatch (e.g. Parent took child directly from school gate)
  Future<void> _resolveSafetyMismatch(Map<String, dynamic> discrepancy) async {
    final sid = discrepancy['student_id']?.toString() ?? '';
    final sname = discrepancy['name']?.toString() ?? 'Student';
    final routeId = discrepancy['route_id']?.toString() ?? 'Route 1';
    final parent = discrepancy['parent_name'] ?? 'Parent';

    await _schoolService.recordBusAttendance(
      routeId: routeId,
      stopName: 'School Main Gate',
      studentId: sid,
      studentName: sname,
      action: 'ParentHandover',
      shift: 'Evening Drop',
      notes: 'Verified Handover: Parent ($parent) picked up student directly from school gate.',
      recordedBy: 'Gate Security & Transport Incharge',
    );

    final updatedLogs = await _schoolService.getBusAttendanceLogs();
    final updatedDiscrepancies = await _schoolService.getTransportTripDiscrepancies();

    if (!mounted) return;
    setState(() {
      _busAttendanceLogs = updatedLogs;
      _discrepancies = updatedDiscrepancies;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Safety Discrepancy Resolved! Direct parent handover confirmed for $sname.'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddNoteDialog(Map<String, dynamic> student) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.note_alt_outlined, color: Color(0xFF0F172A), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Transport Note for ${student['name']}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Parent called, child staying back for football match, etc.',
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _markStudentTripStatus(
                student: student,
                action: 'ParentHandover',
                note: ctrl.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Record Handover'),
          ),
        ],
      ),
    );
  }

  // Filtered Roster
  List<Map<String, dynamic>> get _filteredRoster {
    final routeNo = _selectedRoute?['route_no']?.toString();
    final q = _searchQuery.trim().toLowerCase();

    return _transportRoster.where((s) {
      final matchesRoute = routeNo == null || s['route_id'] == routeNo;
      final assignedStop = _activeShift == 'Morning Pickup' ? s['pickup_stop'] : s['drop_stop'];
      final matchesStop = _selectedStop == '__all__' || assignedStop == _selectedStop;

      final name = (s['name'] ?? '').toString().toLowerCase();
      final sid = (s['student_id'] ?? '').toString().toLowerCase();
      final roll = (s['roll_number'] ?? '').toString().toLowerCase();
      final matchesQuery = q.isEmpty || name.contains(q) || sid.contains(q) || roll.contains(q);

      return matchesRoute && matchesStop && matchesQuery;
    }).toList();
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final criticalDiscrepancies = _discrepancies.where((d) => d['is_resolved'] == false).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transport & Bus Operations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                'Stop-Wise Attendance • Morning & Evening Reconciliation',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0F172A),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  const Tab(text: '1. Trip Attendance (Aate/Jaate)'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('2. Safety Mismatches'),
                        if (criticalDiscrepancies > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$criticalDiscrepancies',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: '3. Routes & Fleet Master'),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh Transport Data',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _loadData,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? _buildLoadingSkeleton()
            : _errorMessage != null
                ? _buildErrorView()
                : TabBarView(
                    children: [
                      _buildTripAttendanceTab(),
                      _buildSafetyMismatchesTab(),
                      _buildRoutesMasterTab(),
                    ],
                  ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: TRIP ATTENDANCE (AATE & JAATE TIME)
  // ──────────────────────────────────────────────
  Widget _buildTripAttendanceTab() {
    return Column(
      children: [
        _buildShiftToggleHeader(),
        _buildRouteAndStopControls(),
        _buildActiveShiftKpiRibbon(),
        Expanded(child: _buildRosterList()),
      ],
    );
  }

  Widget _buildShiftToggleHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeShift = 'Morning Pickup'),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeShift == 'Morning Pickup' ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wb_sunny_rounded,
                      size: 16,
                      color: _activeShift == 'Morning Pickup' ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '☀️ Morning Pickup (Aate Time)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _activeShift == 'Morning Pickup' ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeShift = 'Evening Drop'),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeShift == 'Evening Drop' ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.nights_stay_rounded,
                      size: 16,
                      color: _activeShift == 'Evening Drop' ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🌙 Evening Drop (Jaate Time)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _activeShift == 'Evening Drop' ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteAndStopControls() {
    final stops = (_selectedRoute?['stops'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              // Route Selector
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedRoute,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                      items: _routes.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(
                            r['route_no'] ?? 'Route',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedRoute = v;
                          _selectedStop = '__all__';
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Stop Filter Selector
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStop,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                      items: [
                        const DropdownMenuItem(value: '__all__', child: Text('All Route Stops', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                        ...stops.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedStop = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Search Input
              Expanded(
                flex: 5,
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Search student…',
                      hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveShiftKpiRibbon() {
    final roster = _filteredRoster;
    final total = roster.length;

    // Count states in the active shift
    int boardedCount = 0;
    int absentCount = 0;
    int parentHandoverCount = 0;

    for (final s in roster) {
      final sid = s['student_id'] as String;
      final log = _busAttendanceLogs.firstWhere(
        (l) => l['student_id'] == sid && l['shift'] == _activeShift,
        orElse: () => <String, dynamic>{},
      );
      final action = log['action']?.toString();
      if (action == 'Boarded' || action == 'Dropped') boardedCount++;
      if (action == 'Absent') absentCount++;
      if (action == 'ParentHandover') parentHandoverCount++;
    }

    final pendingCount = total - (boardedCount + absentCount + parentHandoverCount);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _buildKpiPill(_activeShift == 'Morning Pickup' ? 'Picked Up / Boarded' : 'Dropped / Boarded', '$boardedCount', const Color(0xFF10B981), const Color(0xFFECFDF5)),
          const SizedBox(width: 8),
          _buildKpiPill('Direct Parent Pickup', '$parentHandoverCount', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
          const SizedBox(width: 8),
          _buildKpiPill('Absent on Bus', '$absentCount', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
          const SizedBox(width: 8),
          _buildKpiPill('Pending Marking', '$pendingCount', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildKpiPill(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.9))),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterList() {
    final list = _filteredRoster;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text('No students found for this route and stop filter.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return _buildStudentTransportCard(s, index);
      },
    );
  }

  Widget _buildStudentTransportCard(Map<String, dynamic> student, int index) {
    final sid = student['student_id'] as String;
    final name = student['name'] ?? 'Student';
    final className = student['class_name'] ?? 'Class 10';
    final roll = student['roll_number'] ?? '${index + 1}';
    final pickupStop = student['pickup_stop'] ?? 'School Gate';
    final dropStop = student['drop_stop'] ?? 'School Gate';
    final parentPhone = student['parent_phone'] ?? '';

    // Active log for this shift
    final activeLog = _busAttendanceLogs.firstWhere(
      (l) => l['student_id'] == sid && l['shift'] == _activeShift,
      orElse: () => <String, dynamic>{},
    );
    final activeAction = activeLog['action']?.toString();
    final activeTime = activeLog['time']?.toString() ?? '';
    final activeStop = activeLog['stop']?.toString() ?? '';

    Color statusColor = const Color(0xFF64748B);
    Color statusBg = const Color(0xFFF1F5F9);
    String statusLabel = 'Unrecorded';

    if (activeAction == 'Boarded' || activeAction == 'Dropped') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
      statusLabel = _activeShift == 'Morning Pickup' ? 'Boarded at $activeTime ($activeStop)' : 'Dropped at $activeTime ($activeStop)';
    } else if (activeAction == 'ParentHandover') {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusLabel = 'Parent Direct Pickup';
    } else if (activeAction == 'Absent') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEF2F2);
      statusLabel = 'Absent on Bus Trip';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    roll,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '$className • ID: $sid • Parent: $parentPhone',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Assigned Stops Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  _activeShift == 'Morning Pickup' ? 'Pickup Stop: $pickupStop' : 'Drop Stop: $dropStop',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const Spacer(),
                Text(
                  _activeShift == 'Morning Pickup' ? 'Scheduled: ${student['pickup_time'] ?? '07:20 AM'}' : 'Scheduled: ${student['drop_time'] ?? '02:40 PM'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              if (_activeShift == 'Morning Pickup') ...[
                Expanded(
                  child: _buildActionButton(
                    label: 'Mark Boarded',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF10B981),
                    isSelected: activeAction == 'Boarded',
                    onTap: () => _markStudentTripStatus(student: student, action: 'Boarded'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    label: 'Parent Self-Drop',
                    icon: Icons.directions_walk_rounded,
                    color: const Color(0xFF2563EB),
                    isSelected: activeAction == 'SelfDrop',
                    onTap: () => _markStudentTripStatus(student: student, action: 'SelfDrop', note: 'Parent dropped directly at school'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    label: 'Bus Absent',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFEF4444),
                    isSelected: activeAction == 'Absent',
                    onTap: () => _markStudentTripStatus(student: student, action: 'Absent'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _buildActionButton(
                    label: 'Mark Dropped',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF10B981),
                    isSelected: activeAction == 'Dropped',
                    onTap: () => _markStudentTripStatus(student: student, action: 'Dropped'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    label: 'Handover Parent',
                    icon: Icons.person_pin_circle_outlined,
                    color: const Color(0xFFD97706),
                    isSelected: activeAction == 'ParentHandover',
                    onTap: () => _showAddNoteDialog(student),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    label: 'Return Absent',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFEF4444),
                    isSelected: activeAction == 'Absent',
                    onTap: () => _markStudentTripStatus(student: student, action: 'Absent'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: SAFETY DISCREPANCIES & RETURN TRIP MISMATCHES
  // ──────────────────────────────────────────────
  Widget _buildSafetyMismatchesTab() {
    final activeDiscrepancies = _discrepancies.where((d) => d['is_resolved'] == false).toList();
    final resolvedDiscrepancies = _discrepancies.where((d) => d['is_resolved'] == true).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF0F172A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Safety Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Child Safety Reconciliation Protocol',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Flags any student who boarded the morning bus to school but is NOT aboard or dropped on the evening return bus. Ensures 100% child custody accountability.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Critical Alerts
          Row(
            children: [
              const Text(
                'Safety Anomaly Alerts',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: activeDiscrepancies.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  activeDiscrepancies.isNotEmpty ? '${activeDiscrepancies.length} Action Needed' : '0 Clean',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activeDiscrepancies.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 48),
                  SizedBox(height: 10),
                  Text('100% Student Custody Reconciliation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  SizedBox(height: 4),
                  Text('All students who took the morning bus are properly accounted for in the return trip or gate handover.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            )
          else
            ...activeDiscrepancies.map((d) => _buildDiscrepancyCard(d)),

          const SizedBox(height: 20),

          // Resolved Handover Log
          if (resolvedDiscrepancies.isNotEmpty) ...[
            const Text(
              'Resolved Handovers & Verified Exceptions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            ...resolvedDiscrepancies.map((d) => _buildResolvedCard(d)),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscrepancyCard(Map<String, dynamic> d) {
    final name = d['name'] ?? 'Student';
    final sid = d['student_id'] ?? '';
    final className = d['class_name'] ?? 'Class 10';
    final parentPhone = d['parent_phone'] ?? '';
    final parentName = d['parent_name'] ?? 'Parent';
    final morningStatus = d['morning_status'] ?? '';
    final eveningStatus = d['evening_status'] ?? '';
    final desc = d['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name ($className)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'ID: $sid • Parent: $parentName ($parentPhone)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Text('TRIP MISMATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Morning Pickup: $morningStatus', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.nights_stay_rounded, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Evening Return: $eveningStatus', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resolveSafetyMismatch(d),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 16),
                  label: const Text('Confirm Parent Handover at Gate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedCard(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d['name']} (${d['class_name']}) — Verified',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                Text(
                  d['description'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 3: ROUTES & FLEET MASTER
  // ──────────────────────────────────────────────
  Widget _buildRoutesMasterTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF0F172A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active School Fleet & Bus Routes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              OutlinedButton.icon(
                onPressed: _showAddRouteDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ..._routes.asMap().entries.map((e) => _buildRouteMasterCard(e.key, e.value)),
          const SizedBox(height: 20),

          // Gate Pass Audit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gate Passes & Authorized Pickups',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text('${_gatePasses.length} Logs', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 8),

          if (_gatePasses.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No early exit gate passes filed today.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ),
            )
          else
            ..._gatePasses.take(5).map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['student_name'] ?? 'Student'} • Pass ${p['pass_no'] ?? ''}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Reason: ${p['reason']} • Pickup by: ${p['pickup_person']} (${p['relation']})',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Approved', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRouteMasterCard(int index, Map<String, dynamic> route) {
    final isExpanded = _expandedIndex == index;
    final stops = (route['stops'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : index),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF0F172A), size: 22),
            ),
            title: Text(
              '${route['route_no']} • ${route['name']}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            subtitle: Text(
              'Bus: ${route['bus_no']} • Driver: ${route['driver_name']} (${route['driver_phone']})',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            trailing: Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: const Color(0xFF64748B)),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Route Stops Sequence & Schedule:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: stops.asMap().entries.map((e) {
                      return Chip(
                        label: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Vehicle Fitness: Active', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Speed Governor: OK (40 km/h)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddRouteDialog() {
    final routeNoCtrl = TextEditingController(text: 'Route 3');
    final nameCtrl = TextEditingController(text: 'Route 3 - Dilaram & Ballupur');
    final busNoCtrl = TextEditingController(text: 'UK-07-PA-5521');
    final driverCtrl = TextEditingController(text: 'Vikram Singh');
    final phoneCtrl = TextEditingController(text: '9876543219');
    final stopsCtrl = TextEditingController(text: 'School Main Gate, Dilaram Chowk, Ballupur, Kishan Nagar');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Bus Route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: routeNoCtrl,
                  decoration: const InputDecoration(labelText: 'Route ID (e.g. Route 3)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Route Name & Coverage Area', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: busNoCtrl,
                  decoration: const InputDecoration(labelText: 'Bus Plate Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: driverCtrl, decoration: const InputDecoration(labelText: 'Driver Name', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Driver Phone', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: stopsCtrl,
                  decoration: const InputDecoration(labelText: 'Ordered Stops (Comma-separated)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      final stopsList = stopsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                      await _schoolService.supabase.from('school_transport').insert({
                        'institute_code': 'SHIV-SCH',
                        'route_name': nameCtrl.text.trim(),
                        'bus_number': busNoCtrl.text.trim(),
                        'driver_name': driverCtrl.text.trim(),
                        'driver_phone': phoneCtrl.text.trim(),
                        'pickup_time': '07:15 AM',
                        'stops': stopsList,
                      });
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                    child: const Text('Save Route Master', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // SKELETON & ERROR VIEWS
  // ──────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Failed to load transport records', style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
