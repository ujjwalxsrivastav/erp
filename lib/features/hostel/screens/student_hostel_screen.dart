import 'package:flutter/material.dart';
import '../services/hostel_service.dart';
import 'student_grievance_screen.dart';

class StudentHostelScreen extends StatefulWidget {
  final String studentId;
  const StudentHostelScreen({super.key, required this.studentId});

  @override
  State<StudentHostelScreen> createState() => _StudentHostelScreenState();
}

class _StudentHostelScreenState extends State<StudentHostelScreen>
    with SingleTickerProviderStateMixin {
  final _service = HostelService();
  Map<String, dynamic>? _roomDetails;
  bool _isLoading = true;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
          ..forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final details = await _service.getStudentRoomDetails(widget.studentId);
    if (mounted) setState(() { _roomDetails = details; _isLoading = false; });
  }

  String get _studentName {
    if (_roomDetails == null) return 'Student';
    final raw = _roomDetails!['occupants'];
    if (raw == null) return 'Student';
    final list = raw is List
        ? raw.map((o) => Map<String, dynamic>.from(o as Map)).toList()
        : <Map<String, dynamic>>[];
    final me = list.firstWhere(
        (o) => o['student_id'] == widget.studentId,
        orElse: () => {'student_name': 'Student'});
    return me['student_name'] ?? 'Student';
  }

  void _openGrievance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentGrievanceScreen(
          studentId: widget.studentId,
          studentName: _studentName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : FadeTransition(
              opacity: _fadeCtrl,
              child: _roomDetails == null
                  ? _buildNoAllocation()
                  : _buildAllotted(),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NOT ALLOTTED STATE
  // ═══════════════════════════════════════════════════════════
  Widget _buildNoAllocation() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(roomNumber: null, hostelName: null),
        SliverFillRemaining(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.hotel_outlined,
                      size: 50, color: Colors.orange),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Room Not Yet Allotted',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your hostel request is being processed.\nThe warden will assign your room shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 40),
                _buildGrievanceButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ALLOTTED STATE
  // ═══════════════════════════════════════════════════════════
  Widget _buildAllotted() {
    final rawOccupants = _roomDetails!['occupants'];
    final occupants = rawOccupants is List
        ? rawOccupants.map((o) => Map<String, dynamic>.from(o as Map)).toList()
        : <Map<String, dynamic>>[];

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          roomNumber: _roomDetails!['room_number'],
          hostelName: _roomDetails!['hostel_name'],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Room stat cards
              _buildStatRow(),
              const SizedBox(height: 24),

              // Bed visualization
              _buildBedCard(occupants),
              const SizedBox(height: 24),

              // Roommates
              _sectionHeader('👥  Roommates'),
              const SizedBox(height: 14),
              ...occupants.map((o) => _buildOccupantCard(o)),

              const SizedBox(height: 28),

              // Grievance button — large, central
              _buildGrievanceButton(),

              const SizedBox(height: 24),

              // Policies
              _buildPoliciesCard(),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SLIVER APP BAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildSliverAppBar(
      {required String? roomNumber, required String? hostelName}) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
      elevation: 0,
      title: roomNumber != null
          ? Text('Room $roomNumber',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17))
          : const Text('My Hostel',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              left: 24, right: 24, bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hostelName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                      ),
                      child: Text(hostelName,
                          style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    roomNumber != null ? 'Room $roomNumber' : 'My Hostel',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roomNumber != null
                        ? '${_roomDetails!['floor']} Floor • ${_roomDetails!['capacity']}-Seater Room'
                        : 'Awaiting room allocation',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STAT CARDS ROW
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatRow() {
    final occ = _roomDetails?['current_occupancy'] ?? 0;
    final cap = _roomDetails?['capacity'] ?? 3;
    final floor = (_roomDetails?['floor'] ?? '-').toString();

    return Row(
      children: [
        _StatCard(
          icon: Icons.bed_outlined,
          label: 'Room',
          value: _roomDetails?['room_number'] ?? '-',
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.people_outline,
          label: 'Occupied',
          value: '$occ / $cap',
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.layers_outlined,
          label: 'Floor',
          value: floor.substring(0, 1).toUpperCase() + floor.substring(1),
          color: const Color(0xFFA78BFA),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BED VISUALIZATION
  // ═══════════════════════════════════════════════════════════
  Widget _buildBedCard(List<Map<String, dynamic>> occupants) {
    final cap = _roomDetails?['capacity'] as int? ?? 3;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛏️  Bed Status',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            children: List.generate(cap, (i) {
              final filled = i < occupants.length;
              final isMe = filled &&
                  occupants[i]['student_id'] == widget.studentId;
              final initials = filled
                  ? (occupants[i]['student_name'] as String? ?? '?')[0]
                      .toUpperCase()
                  : '';

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < cap - 1 ? 10 : 0),
                  height: 80,
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                        : filled
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFF3B82F6)
                          : filled
                              ? Colors.white12
                              : Colors.white.withValues(alpha: 0.05),
                      width: isMe ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      filled
                          ? Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isMe
                                    ? const Color(0xFF3B82F6)
                                    : Colors.white12,
                              ),
                              child: Center(
                                child: Text(initials,
                                    style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            )
                          : Icon(Icons.bed_outlined,
                              color: Colors.white.withValues(alpha: 0.15),
                              size: 28),
                      const SizedBox(height: 6),
                      Text(
                        isMe
                            ? 'You'
                            : filled
                                ? 'Taken'
                                : 'Empty',
                        style: TextStyle(
                          color: isMe
                              ? const Color(0xFF93C5FD)
                              : filled
                                  ? Colors.white38
                                  : Colors.white12,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // OCCUPANT CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildOccupantCard(Map<String, dynamic> occupant) {
    final isMe = occupant['student_id'] == widget.studentId;
    final name = occupant['student_name'] ?? 'Unknown';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
            : const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
              : Colors.white10,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isMe
                    ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                    : [Colors.white12, Colors.white10],
              ),
            ),
            child: Center(
              child: Text(initials,
                  style: TextStyle(
                      color: isMe ? Colors.white : Colors.white38,
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
                const SizedBox(height: 2),
                Text(occupant['student_id'] ?? '',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (isMe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
              ),
              child: const Text('You',
                  style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // GRIEVANCE BUTTON — large, prominent, centred
  // ═══════════════════════════════════════════════════════════
  Widget _buildGrievanceButton() {
    return GestureDetector(
      onTap: _openGrievance,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.report_problem_outlined,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grievance Portal',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'File a complaint or track your issues',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // POLICIES CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildPoliciesCard() {
    final policies = [
      ('🕘', 'Curfew at 9:00 PM', 'All students must be inside by 9 PM'),
      ('👥', 'Visitor Policy', 'Visitors allowed only in the common room'),
      ('⚡', 'Electrical Appliances', 'Personal appliances are strictly prohibited'),
      ('🔇', 'Quiet Hours', 'Silence maintained after 10 PM'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.policy_outlined,
                      color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Hostel Rules & Policies',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...policies.asMap().entries.map((e) {
            final p = e.value;
            final isLast = e.key == policies.length - 1;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Text(p.$1, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.$2,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(p.$3,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(color: Colors.white10, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16),
      );
}

// ════════════════════════════════════════════
// STAT CARD WIDGET
// ════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
