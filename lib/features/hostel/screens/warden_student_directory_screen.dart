import 'package:flutter/material.dart';
import '../services/hostel_service.dart';

class WardenStudentDirectoryScreen extends StatefulWidget {
  const WardenStudentDirectoryScreen({super.key});
  @override
  State<WardenStudentDirectoryScreen> createState() =>
      _WardenStudentDirectoryScreenState();
}

class _WardenStudentDirectoryScreenState
    extends State<WardenStudentDirectoryScreen>
    with TickerProviderStateMixin {
  final _service = HostelService();
  late AnimationController _fadeCtrl;
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  String _searchQuery = '';
  String? _selectedState;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _loadStudents();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final data = await _service.getAllHostelStudents(
        state: _selectedState, city: _selectedCity);
    if (mounted) setState(() { _students = data; _isLoading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _students;
    final q = _searchQuery.toLowerCase();
    return _students.where((s) {
      final name = (s['student_name'] ?? '').toString().toLowerCase();
      final id = (s['student_id'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  List<String> get _availableStates =>
      _students.map((s) => s['state']?.toString() ?? '')
          .where((s) => s.isNotEmpty).toSet().toList()..sort();

  List<String> get _availableCities =>
      _students.map((s) => s['city']?.toString() ?? '')
          .where((s) => s.isNotEmpty).toSet().toList()..sort();

  // ─── REASSIGN FLOW ─────────────────────────────────────────

  Future<void> _openReassignSheet(Map<String, dynamic> student) async {
    final studentId = student['student_id'] as String? ?? '';
    final studentName = student['student_name'] as String? ?? 'Student';
    final currentRoom = student['room_number'] as String? ?? 'N/A';
    final currentBed = student['bed_number'] as String? ?? 'N/A';

    // State for the bottom sheet
    List<Map<String, dynamic>> hostels = [];
    List<Map<String, dynamic>> availableRooms = [];
    String? selectedHostelId;
    Map<String, dynamic>? selectedRoom;
    String? selectedBed;
    bool loadingRooms = false;
    bool saving = false;

    hostels = await _service.getHostels();
    if (hostels.isEmpty) return;
    selectedHostelId = hostels.first['id'] as String?;
    availableRooms = await _service.getAvailableRooms(selectedHostelId!);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 20, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)]),
                      ),
                      child: Center(
                        child: Text(
                          studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                          Text(studentId,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
                      ),
                      child: Text('$currentRoom / Bed $currentBed',
                          style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 62),
                  child: Text('Current Assignment',
                      style: TextStyle(color: Colors.white24, fontSize: 11)),
                ),

                const SizedBox(height: 24),
                const _SectionLabel('STEP 1 — SELECT HOSTEL'),
                const SizedBox(height: 10),

                // Hostel selector
                if (hostels.length == 1)
                  _InfoTile(hostels.first['name'] ?? '')
                else
                  _DarkDropdown<String>(
                    value: selectedHostelId,
                    hint: 'Select Hostel',
                    items: hostels.map((h) => DropdownMenuItem(
                      value: h['id'] as String,
                      child: Text(h['name'] ?? ''),
                    )).toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      setSheet(() {
                        selectedHostelId = val;
                        selectedRoom = null;
                        selectedBed = null;
                        loadingRooms = true;
                      });
                      final rooms = await _service.getAvailableRooms(val);
                      setSheet(() {
                        availableRooms = rooms;
                        loadingRooms = false;
                      });
                    },
                  ),

                const SizedBox(height: 20),
                const _SectionLabel('STEP 2 — SELECT ROOM'),
                const SizedBox(height: 10),

                loadingRooms
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6), strokeWidth: 2))
                    : availableRooms.isEmpty
                        ? _EmptyHint('No rooms with free beds in this hostel')
                        : Wrap(
                            spacing: 8, runSpacing: 8,
                            children: availableRooms.map((room) {
                              final occ = room['current_occupancy'] as int? ?? 0;
                              final cap = room['capacity'] as int? ?? 0;
                              final free = cap - occ;
                              final isSelected =
                                  selectedRoom?['room_id'] == room['room_id'];
                              return GestureDetector(
                                onTap: () => setSheet(() {
                                  selectedRoom = room;
                                  selectedBed = null; // reset bed on room change
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6D28D9).withValues(alpha: 0.25)
                                        : const Color(0xFF1E2D3D),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF8B5CF6)
                                          : Colors.white12,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text('Room ${room['room_number']}',
                                          style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFFDDD6FE)
                                                  : Colors.white70,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('$free free / $cap',
                                          style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFFA78BFA)
                                                  : Colors.white38,
                                              fontSize: 11)),
                                      if (room['floor'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(room['floor'],
                                            style: const TextStyle(
                                                color: Colors.white24,
                                                fontSize: 10)),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                if (selectedRoom != null) ...[
                  const SizedBox(height: 20),
                  const _SectionLabel('STEP 3 — SELECT BED'),
                  const SizedBox(height: 10),
                  _buildBedPicker(
                    room: selectedRoom!,
                    selectedBed: selectedBed,
                    onSelect: (bed) => setSheet(() => selectedBed = bed),
                  ),
                ],

                const SizedBox(height: 28),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (selectedRoom == null || selectedBed == null || saving)
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            final ok = await _service.reassignRoom(
                              studentId: studentId,
                              newRoomId: selectedRoom!['room_id'],
                              newHostelId: selectedHostelId!,
                              newRoomNumber:
                                  selectedRoom!['room_number'].toString(),
                              newBedNumber: selectedBed!,
                              newBlockName: selectedRoom!['block_name'],
                            );
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? '✅ $studentName transferred to Room '
                                        '${selectedRoom!['room_number']} · Bed $selectedBed'
                                    : '❌ Transfer failed. Please try again.'),
                                backgroundColor: ok
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            if (ok) _loadStudents();
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      saving ? 'Transferring...' : 'Confirm Transfer',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBedPicker({
    required Map<String, dynamic> room,
    required String? selectedBed,
    required ValueChanged<String> onSelect,
  }) {
    final cap = room['capacity'] as int? ?? 3;
    final occ = room['current_occupancy'] as int? ?? 0;
    final beds = List.generate(cap, (i) {
      final label = String.fromCharCode(65 + i); // A, B, C...
      return (label, i < occ); // (bedLabel, isOccupied)
    });

    return Wrap(
      spacing: 10, runSpacing: 10,
      children: beds.map((b) {
        final label = b.$1;
        final occupied = b.$2;
        final isSelected = selectedBed == label;

        return GestureDetector(
          onTap: occupied ? null : () => onSelect(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: occupied
                  ? Colors.white.withValues(alpha: 0.04)
                  : isSelected
                      ? const Color(0xFF6D28D9).withValues(alpha: 0.3)
                      : const Color(0xFF1E2D3D),
              border: Border.all(
                color: occupied
                    ? Colors.white.withValues(alpha: 0.06)
                    : isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  occupied ? Icons.bed_rounded : Icons.bed_outlined,
                  color: occupied
                      ? Colors.white12
                      : isSelected
                          ? const Color(0xFFDDD6FE)
                          : Colors.white38,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  'Bed $label',
                  style: TextStyle(
                      color: occupied
                          ? Colors.white12
                          : isSelected
                              ? const Color(0xFFDDD6FE)
                              : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
                if (occupied)
                  const Text('Taken',
                      style: TextStyle(color: Colors.white12, fontSize: 8)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [_buildAppBar()],
          body: Column(
            children: [
              _buildFilters(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6)))
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _buildStudentCard(_filtered[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Generating Full Batch Report...'),
                behavior: SnackBarBehavior.floating),
          );
        },
        backgroundColor: const Color(0xFF6D28D9),
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text('Export Report',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── APP BAR ───────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    final allocated = _students.where((s) => s['room_id'] != null).length;
    final pending = _students.where((s) => s['room_id'] == null).length;
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStudents),
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
                  colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Student Directory',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('${_students.length} Total  •  Tap allocated to reassign',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statBadge('$allocated', 'Allocated',
                          const Color(0xFF34D399)),
                      const SizedBox(width: 10),
                      _statBadge('$pending', 'Pending',
                          const Color(0xFFFBBF24)),
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
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }

  // ─── FILTERS ───────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or ID...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E2D3D),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DarkDropdown<String>(
                  value: _selectedState,
                  hint: 'All States',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All States')),
                    ..._availableStates.map((s) =>
                        DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedState = val;
                      _selectedCity = null;
                    });
                    _loadStudents();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DarkDropdown<String>(
                  value: _selectedCity,
                  hint: 'All Cities',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Cities')),
                    ..._availableCities.map((c) =>
                        DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCity = val);
                    _loadStudents();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STUDENT CARD ─────────────────────────────────────────

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final isAllocated = student['room_id'] != null;
    final name = student['student_name'] as String? ?? 'Unknown';
    final id = student['student_id'] as String? ?? 'N/A';
    final rRoom = student['room_number'] as String? ?? 'N/A';
    final bed = student['bed_number'] as String? ?? 'N/A';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final accentColor = isAllocated
        ? const Color(0xFF34D399)
        : const Color(0xFFFBBF24);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: accentColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                  child: Text(initials,
                      style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(id,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAllocated ? 'Allocated' : 'Pending',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _infoChip(Icons.location_on_outlined,
                          '${student['city'] ?? '—'}, ${student['state'] ?? '—'}'),
                      const SizedBox(width: 10),
                      if (isAllocated) ...[
                        _infoChip(Icons.bed_outlined, 'Room $rRoom · Bed $bed'),
                      ],
                    ],
                  ),
                ),
                // ─── TRANSFER BUTTON (only for allocated students) ───
                if (isAllocated)
                  GestureDetector(
                    onTap: () => _openReassignSheet(student),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6D28D9)
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Transfer',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white24, size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_search_rounded,
              color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          const Text('No students matched',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      ),
    );
  }
}

// ─── HELPERS ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(text,
            style:
                const TextStyle(color: Colors.white70, fontSize: 14)),
      );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );
}

class _DarkDropdown<T> extends StatelessWidget {
  const _DarkDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          dropdownColor: const Color(0xFF1E2D3D),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
