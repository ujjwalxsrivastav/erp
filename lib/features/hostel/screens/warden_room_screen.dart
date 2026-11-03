import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/hostel_service.dart';

class WardenRoomScreen extends StatefulWidget {
  const WardenRoomScreen({super.key});

  @override
  State<WardenRoomScreen> createState() => _WardenRoomScreenState();
}

class _WardenRoomScreenState extends State<WardenRoomScreen>
    with TickerProviderStateMixin {
  final _service = HostelService();
  late AnimationController _fadeCtrl;
  late TabController _floorTabCtrl;

  List<Map<String, dynamic>> _hostels = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _unallotted = [];
  String? _selectedHostelId;
  String _selectedHostelName = '';
  bool _loading = true;

  final _floors = ['Ground Floor', 'First Floor', 'Second Floor'];
  final _floorKeys = ['Ground', 'First', 'Second'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
          ..forward();
    _floorTabCtrl = TabController(length: 3, vsync: this);
    _floorTabCtrl.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _floorTabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final hostels = await _service.getHostels();
    final unallotted = await _service.getUnallottedStudents();
    if (hostels.isNotEmpty) {
      _selectedHostelId = hostels.first['id'];
      _selectedHostelName = hostels.first['name'] ?? '';
      final rooms = await _service.getRoomsByHostel(_selectedHostelId!);
      if (mounted) {
        setState(() {
          _hostels = hostels;
          _rooms = rooms;
          _unallotted = unallotted;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchHostel(String? hostelId) async {
    if (hostelId == null) return;
    setState(() => _loading = true);
    final rooms = await _service.getRoomsByHostel(hostelId);
    final hostel = _hostels.firstWhere((h) => h['id'] == hostelId);
    if (mounted) {
      setState(() {
        _selectedHostelId = hostelId;
        _selectedHostelName = hostel['name'] ?? '';
        _rooms = rooms;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    final key = _floorKeys[_floorTabCtrl.index];
    return _rooms.where((r) => r['floor'] == key).toList();
  }

  int get _totalOccupied =>
      _rooms.fold(0, (sum, r) => sum + (r['current_occupancy'] as int? ?? 0));
  int get _totalCapacity =>
      _rooms.fold(0, (sum, r) => sum + (r['capacity'] as int? ?? 3));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : FadeTransition(
              opacity: _fadeCtrl,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  _buildSliverAppBar(innerBoxIsScrolled),
                ],
                body: Column(
                  children: [
                    _buildFloorTabBar(),
                    Expanded(child: _buildRoomGrid()),
                  ],
                ),
              ),
            ),
      floatingActionButton: _unallotted.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showUnallottedSheet,
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: Text(
                '${_unallotted.length} Pending',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  SliverAppBar _buildSliverAppBar(bool innerBoxIsScrolled) {
    final occupied = _totalOccupied;
    final capacity = _totalCapacity;
    final pct = capacity > 0 ? occupied / capacity : 0.0;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      title: innerBoxIsScrolled
          ? Text(_selectedHostelName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18))
          : null,
      actions: [
        if (_hostels.length > 1)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
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
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
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
                  colors: [Color(0xFF0D1B2A), Color(0xFF1E3A8A)],
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedHostelName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Room Occupancy Dashboard',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$occupied / $capacity Beds Occupied',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text('${(pct * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation(
                                  pct > 0.8
                                      ? Colors.redAccent
                                      : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildMiniStat('Rooms', '${_rooms.length}'),
                      const SizedBox(width: 12),
                      _buildMiniStat('Available', '${capacity - occupied}'),
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

  Widget _buildMiniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFloorTabBar() {
    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _floorTabCtrl,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          padding: const EdgeInsets.all(4),
          tabs: _floors.map((f) => Tab(text: f)).toList(),
        ),
      ),
    );
  }

  Widget _buildRoomGrid() {
    final rooms = _filteredRooms;
    if (rooms.isEmpty) {
      return const Center(
        child: Text('No rooms on this floor',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 500 ? 5 : 3;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: rooms.length,
        itemBuilder: (context, i) => _buildRoomCard(rooms[i]),
      );
    });
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final occupancy = room['current_occupancy'] as int? ?? 0;
    final capacity = room['capacity'] as int? ?? 3;
    final isFull = occupancy >= capacity;
    final isEmpty = occupancy == 0;

    final Color glowColor = isFull
        ? const Color(0xFFEF4444)
        : isEmpty
            ? Colors.white12
            : const Color(0xFF22C55E);

    final Color cardColor = isFull
        ? const Color(0xFF2D1B1B)
        : isEmpty
            ? const Color(0xFF1A2332)
            : const Color(0xFF1A2D1A);

    final rawOccupants = room['occupants'];
    final occupants = rawOccupants is List
        ? rawOccupants.map((o) => Map<String, dynamic>.from(o as Map)).toList()
        : <Map<String, dynamic>>[];

    return GestureDetector(
      onTap: () => _showRoomDetail(room, occupants),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: glowColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: isFull || !isEmpty ? 0.2 : 0.0),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Room number
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  room['room_number'] ?? '',
                  style: TextStyle(
                    color: isFull
                        ? const Color(0xFFF87171)
                        : isEmpty
                            ? Colors.white38
                            : const Color(0xFF4ADE80),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Bed slots
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(capacity, (i) {
                      final filled = i < occupancy;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? (isFull
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF3B82F6))
                              : Colors.white10,
                          border: Border.all(
                            color: filled ? Colors.transparent : Colors.white12,
                          ),
                        ),
                        child: filled
                            ? const Icon(Icons.person,
                                size: 11, color: Colors.white)
                            : null,
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$occupancy/$capacity',
                    style: TextStyle(
                      color: isFull
                          ? const Color(0xFFF87171)
                          : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomDetail(
      Map<String, dynamic> room, List<Map<String, dynamic>> occupants) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RoomDetailSheet(
        room: room,
        occupants: occupants,
        unallotted: _unallotted,
        onAllot: (studentId) async {
          Navigator.pop(context);
          final success = await _service.allotRoom(
              studentId, room['room_id'], _selectedHostelId!);
          if (success) {
            _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('✅ Room allotted successfully!'),
                    backgroundColor: Color(0xFF22C55E)),
              );
            }
          }
        },
      ),
    );
  }

  void _showUnallottedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _UnallottedSheet(students: _unallotted),
    );
  }
}

// ============================================================
// ROOM DETAIL BOTTOM SHEET
// ============================================================
class _RoomDetailSheet extends StatelessWidget {
  final Map<String, dynamic> room;
  final List<Map<String, dynamic>> occupants;
  final List<Map<String, dynamic>> unallotted;
  final Future<void> Function(String studentId) onAllot;

  const _RoomDetailSheet({
    required this.room,
    required this.occupants,
    required this.unallotted,
    required this.onAllot,
  });

  @override
  Widget build(BuildContext context) {
    final occupancy = room['current_occupancy'] as int? ?? 0;
    final capacity = room['capacity'] as int? ?? 3;
    final isFull = occupancy >= capacity;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isFull
                            ? [const Color(0xFF7F1D1D), const Color(0xFFEF4444)]
                            : [
                                const Color(0xFF1E3A8A),
                                const Color(0xFF3B82F6)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.meeting_room,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room ${room['room_number']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${room['floor']} Floor  •  ${room['hostel_name']}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isFull
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isFull
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF22C55E)),
                    ),
                    child: Text(
                      '$occupancy / $capacity',
                      style: TextStyle(
                          color: isFull
                              ? const Color(0xFFF87171)
                              : const Color(0xFF4ADE80),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10, height: 1),
            // Occupants list
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    occupants.isEmpty
                        ? 'No students assigned yet'
                        : 'Occupants (${occupants.length})',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  ...occupants.map((o) => _OccupantTile(
                        occupant: o,
                        onTap: () => _showStudentDetail(context, o),
                      )),
                  if (!isFull && unallotted.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    const Text(
                      'ASSIGN A STUDENT',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    ...unallotted.map((s) => _AllotTile(
                          student: s,
                          onAllot: () =>
                              onAllot(s['student_id']),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetail(
      BuildContext context, Map<String, dynamic> occupant) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _StudentDetailSheet(studentId: occupant['student_id']),
    );
  }
}

// ============================================================
// OCCUPANT ROW
// ============================================================
class _OccupantTile extends StatelessWidget {
  final Map<String, dynamic> occupant;
  final VoidCallback onTap;

  const _OccupantTile({required this.occupant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = occupant['student_name'] ?? 'Unknown';
    final id = occupant['student_id'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(id,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right,
                  color: Colors.white38, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ALLOT ROW
// ============================================================
class _AllotTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onAllot;

  const _AllotTile({required this.student, required this.onAllot});

  @override
  Widget build(BuildContext context) {
    final name = student['student_name'] ?? 'Unknown';
    final id = student['student_id'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(id,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAllot,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Allot',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STUDENT DETAIL SHEET (fetches from student_details)
// ============================================================
class _StudentDetailSheet extends StatefulWidget {
  final String studentId;
  const _StudentDetailSheet({required this.studentId});

  @override
  State<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<_StudentDetailSheet> {
  Map<String, dynamic>? _student;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await Supabase.instance.client
          .from('student_details')
          .select()
          .eq('student_id', widget.studentId)
          .maybeSingle();
      if (mounted) setState(() { _student = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : _student == null
              ? const Center(
                  child: Text('Student details not found',
                      style: TextStyle(color: Colors.white38)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final s = _student!;
    final name = s['name'] ?? 'Unknown';
    final initials = name.isNotEmpty
        ? name.split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : '?';

    return SingleChildScrollView(
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          // Header gradient
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 2),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(s['student_id'] ?? '',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _DetailCard(items: [
                  _DetailItem('Department', s['department'] ?? '-'),
                  _DetailItem('Year', '${s['year'] ?? '-'}'),
                  _DetailItem('Semester', '${s['semester'] ?? '-'}'),
                  _DetailItem('Section', s['section'] ?? '-'),
                ]),
                const SizedBox(height: 12),
                _DetailCard(items: [
                  _DetailItem('Father\'s Name', s['father_name'] ?? '-'),
                  _DetailItem('Email', s['email'] ?? '-'),
                  _DetailItem('Phone', s['phone'] ?? '-'),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<_DetailItem> items;
  const _DetailCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          final item = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13)),
                    Text(item.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: Colors.white10),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  const _DetailItem(this.label, this.value);
}

// ============================================================
// UNALLOTTED STUDENTS SHEET
// ============================================================
class _UnallottedSheet extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  const _UnallottedSheet({required this.students});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions,
                      color: Color(0xFF3B82F6), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${students.length} Unallotted Students',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                itemBuilder: (_, i) {
                  final s = students[i];
                  final name = s['student_name'] ?? 'Unknown';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2D3D),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF3B82F6)
                              .withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                              Text(s['student_id'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: const Text('Pending',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
