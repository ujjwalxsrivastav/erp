import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hostel_service.dart';
import '../../../services/auth_service.dart';

class NightAttendanceScreen extends StatefulWidget {
  const NightAttendanceScreen({super.key});
  @override
  State<NightAttendanceScreen> createState() => _NightAttendanceScreenState();
}

class _NightAttendanceScreenState extends State<NightAttendanceScreen>
    with TickerProviderStateMixin {
  final _service = HostelService();
  final _authService = AuthService();
  late AnimationController _fadeCtrl;

  List<Map<String, dynamic>> _hostels = [];
  List<Map<String, dynamic>> _rooms = [];
  String? _selectedHostelId;
  String _selectedHostelName = '';
  String _wardenName = 'Warden';
  bool _loading = true;
  bool _saving = false;

  // roomId -> set of absent student IDs
  final Map<String, Set<String>> _absentMap = {};
  // roomId -> expanded state
  final Map<String, bool> _expandedMap = {};

  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _init();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final name = await _authService.getCurrentUsername();
    if (mounted) setState(() => _wardenName = name ?? 'Warden');
    await _loadHostels();
  }

  Future<void> _loadHostels() async {
    setState(() => _loading = true);
    final hostels = await _service.getHostels();
    if (hostels.isNotEmpty) {
      _selectedHostelId = hostels.first['id'];
      _selectedHostelName = hostels.first['name'] ?? '';
      await _loadRooms(_selectedHostelId!);
    }
    if (mounted) setState(() { _hostels = hostels; _loading = false; });
  }

  Future<void> _loadRooms(String hostelId) async {
    final rooms = await _service.getRoomsForAttendance(hostelId);
    // Load saved attendance for today for each room
    final Map<String, Set<String>> savedAbsent = {};
    for (final room in rooms) {
      final roomId = room['room_id'] as String? ?? '';
      final saved = await _service.getAttendanceForDate(roomId, _today);
      if (saved != null && saved['absent_students'] != null) {
        final list = saved['absent_students'];
        if (list is List) {
          savedAbsent[roomId] = Set<String>.from(list.map((e) => e.toString()));
        }
      }
    }
    if (mounted) {
      setState(() {
        _rooms = rooms;
        _absentMap.clear();
        _absentMap.addAll(savedAbsent);
      });
    }
  }

  Future<void> _switchHostel(String? id) async {
    if (id == null) return;
    setState(() { _loading = true; _rooms = []; });
    final hostel = _hostels.firstWhere((h) => h['id'] == id);
    _selectedHostelId = id;
    _selectedHostelName = hostel['name'] ?? '';
    await _loadRooms(id);
    if (mounted) setState(() => _loading = false);
  }

  void _toggleStudent(String roomId, String studentId) {
    setState(() {
      _absentMap.putIfAbsent(roomId, () => {});
      if (_absentMap[roomId]!.contains(studentId)) {
        _absentMap[roomId]!.remove(studentId);
      } else {
        _absentMap[roomId]!.add(studentId);
      }
    });
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    int saved = 0;
    for (final room in _rooms) {
      final roomId = room['room_id'] as String? ?? '';
      final absent = _absentMap[roomId]?.toList() ?? [];
      final ok = await _service.saveAttendance(
        roomId: roomId,
        date: _today,
        absentStudentIds: absent,
        markedBy: _wardenName,
      );
      if (ok) saved++;
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Attendance saved for $saved rooms'),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  int get _totalAbsent =>
      _absentMap.values.fold(0, (s, set) => s + set.length);

  int get _totalPresent {
    int total = _rooms.fold(
        0, (s, r) => s + (r['current_occupancy'] as int? ?? 0));
    return total - _totalAbsent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [_buildAppBar()],
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _rooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bed_rounded,
                              color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text('No occupied rooms found',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Select a different hostel',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _rooms.length,
                      itemBuilder: (_, i) => _buildRoomAttendanceCard(_rooms[i]),
                    ),
        ),
      ),
      floatingActionButton: _rooms.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _saveAll,
              backgroundColor: const Color(0xFF6366F1),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _saving ? 'Saving...' : 'Save Attendance',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (_hostels.length > 1)
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedHostelId,
                dropdownColor: const Color(0xFF1E2D3D),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                icon: const Icon(Icons.expand_more,
                    color: Colors.white70, size: 18),
                items: _hostels
                    .map((h) => DropdownMenuItem(
                          value: h['id'] as String,
                          child: Text(h['name'] ?? ''),
                        ))
                    .toList(),
                onChanged: _switchHostel,
              ),
            ),
          ),
        IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadRooms(_selectedHostelId ?? '')),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Night Roll Call',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    '$_selectedHostelName  •  $_today',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statBadge('$_totalPresent', 'Present',
                          const Color(0xFF34D399)),
                      const SizedBox(width: 10),
                      _statBadge('$_totalAbsent', 'Absent',
                          const Color(0xFFF87171)),
                      const SizedBox(width: 10),
                      _statBadge('${_rooms.length}', 'Rooms',
                          const Color(0xFF93C5FD)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRoomAttendanceCard(Map<String, dynamic> room) {
    final roomId = room['room_id'] as String? ?? '';
    final roomNo = room['room_number'] ?? '';
    final floor = room['floor'] ?? '';
    final occupancy = room['current_occupancy'] as int? ?? 0;
    final absent = _absentMap[roomId] ?? {};
    final isExpanded = _expandedMap[roomId] ?? false;

    // Parse occupants list from room_occupancy_view
    List<Map<String, dynamic>> occupants = [];
    final rawOccupants = room['occupants'];
    if (rawOccupants is List) {
      occupants = rawOccupants
          .whereType<Map>()
          .map((o) => Map<String, dynamic>.from(o))
          .toList();
    }

    final absentCount = absent.length;
    final presentCount = occupancy - absentCount;
    final allPresent = absentCount == 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allPresent
              ? const Color(0xFF34D399).withValues(alpha: 0.4)
              : const Color(0xFFF87171).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header row — tappable to expand
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () =>
                setState(() => _expandedMap[roomId] = !(isExpanded)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Room icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: allPresent
                          ? const Color(0xFF34D399).withValues(alpha: 0.15)
                          : const Color(0xFFF87171).withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      allPresent
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      color: allPresent
                          ? const Color(0xFF34D399)
                          : const Color(0xFFF87171),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Room $roomNo',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('$floor Floor',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('$presentCount present  •  $absentCount absent',
                            style: TextStyle(
                                color: absentCount > 0
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF34D399),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  // Quick mark-all-present button
                  if (!allPresent)
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded,
                          color: Color(0xFF34D399), size: 20),
                      tooltip: 'Mark all present',
                      onPressed: () =>
                          setState(() => _absentMap[roomId] = {}),
                    ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),

          // Expandable student list
          if (isExpanded) ...[
            const Divider(color: Colors.white10, height: 1),
            if (occupants.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Text(
                  'No student data available — tap Save after marking',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...occupants.map((o) {
                final sid = o['student_id']?.toString() ?? '';
                final sname = o['student_name'] ?? 'Unknown';
                final isAbsent = absent.contains(sid);
                final initials = sname.isNotEmpty
                    ? sname[0].toUpperCase()
                    : '?';

                return InkWell(
                  onTap: () => _toggleStudent(roomId, sid),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isAbsent
                              ? const Color(0xFFF87171).withValues(alpha: 0.2)
                              : const Color(0xFF34D399).withValues(alpha: 0.2),
                          child: Text(initials,
                              style: TextStyle(
                                  color: isAbsent
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFF34D399),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sname,
                                  style: TextStyle(
                                      color: isAbsent
                                          ? const Color(0xFFF87171)
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(sid,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isAbsent
                                ? const Color(0xFFF87171).withValues(alpha: 0.2)
                                : const Color(0xFF34D399).withValues(alpha: 0.2),
                            border: Border.all(
                              color: isAbsent
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFF34D399),
                            ),
                          ),
                          child: Icon(
                            isAbsent ? Icons.close_rounded : Icons.check_rounded,
                            color: isAbsent
                                ? const Color(0xFFF87171)
                                : const Color(0xFF34D399),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
