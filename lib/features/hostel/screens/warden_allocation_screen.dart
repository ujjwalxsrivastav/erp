import 'package:flutter/material.dart';
import '../services/hostel_service.dart';

class WardenAllocationScreen extends StatefulWidget {
  const WardenAllocationScreen({super.key});
  @override
  State<WardenAllocationScreen> createState() => _WardenAllocationScreenState();
}

class _WardenAllocationScreenState extends State<WardenAllocationScreen>
    with TickerProviderStateMixin {
  final _service = HostelService();
  late AnimationController _fadeCtrl;
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _hostels = [];
  List<Map<String, dynamic>> _unallotted = [];
  List<Map<String, dynamic>> _rooms = [];
  String? _selectedHostelId;
  String _selectedHostelName = '';
  bool _loading = true;
  bool _autoAllocating = false;

  // Manual allot
  Map<String, dynamic>? _selectedStudent;
  Map<String, dynamic>? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final hostels = await _service.getHostels();
    final unallotted = await _service.getUnallottedStudents();
    List<Map<String, dynamic>> rooms = [];
    if (hostels.isNotEmpty) {
      _selectedHostelId = hostels.first['id'];
      _selectedHostelName = hostels.first['name'] ?? '';
      rooms = await _service.getRoomsByHostel(_selectedHostelId!);
    }
    if (mounted) {
      setState(() {
        _hostels = hostels;
        _unallotted = unallotted;
        _rooms = rooms.where((r) => (r['current_occupancy'] as int? ?? 0) < (r['capacity'] as int? ?? 3)).toList();
        _loading = false;
      });
    }
  }

  Future<void> _switchHostel(String? id) async {
    if (id == null) return;
    setState(() => _loading = true);
    final rooms = await _service.getRoomsByHostel(id);
    final hostel = _hostels.firstWhere((h) => h['id'] == id);
    if (mounted) {
      setState(() {
        _selectedHostelId = id;
        _selectedHostelName = hostel['name'] ?? '';
        _rooms = rooms.where((r) => (r['current_occupancy'] as int? ?? 0) < (r['capacity'] as int? ?? 3)).toList();
        _loading = false;
        _selectedRoom = null;
      });
    }
  }

  Future<void> _autoAllocate() async {
    setState(() => _autoAllocating = true);
    final result = await _service.autoAllocateRooms();
    if (mounted) {
      setState(() => _autoAllocating = false);
      final allocated = result['allocated'] ?? 0;
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Auto-mapped $allocated student(s) by State & City!'
                : '❌ ${result['message'] ?? 'Auto-allocation failed'}',
          ),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) _loadData();
    }
  }

  Future<void> _manualAllot() async {
    if (_selectedStudent == null || _selectedRoom == null || _selectedHostelId == null) return;
    final occupancy = _selectedRoom!['current_occupancy'] as int? ?? 0;
    final bedLetter = String.fromCharCode(65 + occupancy); // A, B, C...
    final success = await _service.allotRoom(
      _selectedStudent!['student_id'],
      _selectedRoom!['room_id'],
      _selectedHostelId!,
      bedNumber: bedLetter,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? '✅ ${_selectedStudent!['student_name']} → Room ${_selectedRoom!['room_number']}, Bed $bedLetter'
            : '❌ Allocation failed'),
        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
      if (success) {
        setState(() {
          _selectedStudent = null;
          _selectedRoom = null;
        });
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : FadeTransition(
              opacity: _fadeCtrl,
              child: NestedScrollView(
                headerSliverBuilder: (_, __) => [_buildAppBar()],
                body: Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildManualTab(),
                          _buildAutoTab(),
                        ],
                      ),
                    ),
                  ],
                ),
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
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
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
                icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
                items: _hostels.map((h) => DropdownMenuItem(
                  value: h['id'] as String,
                  child: Text(h['name'] ?? ''),
                )).toList(),
                onChanged: _switchHostel,
              ),
            ),
          ),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
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
                  colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Room Allocation',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(_selectedHostelName,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statChip('${_unallotted.length}', 'Unallocated', const Color(0xFFFBBF24)),
                      const SizedBox(width: 10),
                      _statChip('${_rooms.length}', 'Available Rooms', const Color(0xFF34D399)),
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

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)]),
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          padding: const EdgeInsets.all(4),
          tabs: const [
            Tab(text: '⚙ Manual Map'),
            Tab(text: '🤖 Auto Allocate'),
          ],
        ),
      ),
    );
  }

  // ─── MANUAL TAB ─────────────────────────────────────────────

  Widget _buildManualTab() {
    if (_unallotted.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 64),
            SizedBox(height: 16),
            Text('All students are allocated!',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STEP 1: Pick student
          const Text('STEP 1 — SELECT STUDENT',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _unallotted.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _buildStudentChip(_unallotted[i]),
            ),
          ),
          const SizedBox(height: 20),

          // STEP 2: Pick room
          const Text('STEP 2 — SELECT AVAILABLE ROOM',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemCount: _rooms.length,
              itemBuilder: (_, i) => _buildRoomChip(_rooms[i]),
            ),
          ),
          const SizedBox(height: 12),

          // Confirm button
          if (_selectedStudent != null && _selectedRoom != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _manualAllot,
                icon: const Icon(Icons.how_to_reg_rounded),
                label: Text(
                  'Assign ${_selectedStudent!['student_name'].toString().split(' ').first}'
                  ' → Room ${_selectedRoom!['room_number']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentChip(Map<String, dynamic> student) {
    final selected = _selectedStudent?['student_id'] == student['student_id'];
    final name = student['student_name'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () => setState(() => _selectedStudent = selected ? null : student),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? const Color(0xFF10B981) : Colors.white12,
              width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  selected ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name.split(' ').first,
                style: TextStyle(
                    color: selected ? const Color(0xFF10B981) : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomChip(Map<String, dynamic> room) {
    final selected = _selectedRoom?['room_id'] == room['room_id'];
    final occupancy = room['current_occupancy'] as int? ?? 0;
    final capacity = room['capacity'] as int? ?? 3;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoom = selected ? null : room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? const Color(0xFF10B981) : Colors.white12,
              width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(room['room_number'] ?? '',
                style: TextStyle(
                    color: selected ? const Color(0xFF10B981) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(capacity, (i) {
                final filled = i < occupancy;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? const Color(0xFF3B82F6)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text('$occupancy/$capacity',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ─── AUTO TAB ───────────────────────────────────────────────

  Widget _buildAutoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2D3D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Smart Allocation',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text('Groups students by hometown',
                              style:
                                  TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                _featureRow(Icons.location_city_rounded, 'Same City → Same Room',
                    'Students from same city grouped first'),
                const SizedBox(height: 14),
                _featureRow(Icons.map_rounded, 'Same State → Adjacent Rooms',
                    'State-wise grouping as fallback'),
                const SizedBox(height: 14),
                _featureRow(Icons.bed_rounded, 'Bed Labels Auto-Assigned',
                    'Bed A, B, C assigned in order'),
                const SizedBox(height: 14),
                _featureRow(Icons.speed_rounded, 'Instant Bulk Processing',
                    'All unallocated students mapped at once'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Unallocated preview
          if (_unallotted.isNotEmpty) ...[
            Text(
              '${_unallotted.length} Students Awaiting Allocation',
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._unallotted.take(5).map((s) => _unallottedPreviewRow(s)),
            if (_unallotted.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('+${_unallotted.length - 5} more students...',
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Color(0xFF10B981), size: 48),
                  SizedBox(height: 12),
                  Text('All students have been allocated!',
                      style:
                          TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // BIG auto-allocate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _unallotted.isEmpty ? null : (_autoAllocating ? null : _autoAllocate),
              icon: _autoAllocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, size: 24),
              label: Text(
                _autoAllocating ? 'Allocating...' : 'Run Auto Allocation',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                disabledBackgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Text(subtitle,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _unallottedPreviewRow(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFBBF24).withValues(alpha: 0.15),
            child: Text(
              (s['student_name'] ?? 'S')[0].toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s['student_name'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          if (s['state'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${s['city'] ?? ''}, ${s['state'] ?? ''}',
                style:
                    const TextStyle(color: Color(0xFF93C5FD), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
