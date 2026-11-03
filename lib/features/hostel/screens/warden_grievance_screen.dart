import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/grievance_service.dart';

class WardenGrievanceScreen extends StatefulWidget {
  const WardenGrievanceScreen({super.key});

  @override
  State<WardenGrievanceScreen> createState() => _WardenGrievanceScreenState();
}

class _WardenGrievanceScreenState extends State<WardenGrievanceScreen> {
  final _svc = GrievanceService();
  List<Map<String, dynamic>> _grievances = [];
  Map<String, int> _stats = {};
  bool _loading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final gs = await _svc.getAllGrievances(
        statusFilter: _filterStatus == 'all' ? null : _filterStatus);
    final stats = await _svc.getGrievanceStats();
    if (mounted) {
      setState(() {
        _grievances = gs;
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _openRespond(Map<String, dynamic> g) async {
    final responseCtrl = TextEditingController(
        text: g['warden_response'] ?? '');
    String newStatus = g['status'] ?? 'pending';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInnerState) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                Text(
                  g['title'] ?? 'Complaint',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  g['description'] ?? '',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                // Status picker
                const Text('Update Status',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'pending',
                      'acknowledged',
                      'in_progress',
                      'resolved',
                      'dismissed'
                    ].map((s) {
                      final conf = _statusConf(s);
                      final sel = newStatus == s;
                      return GestureDetector(
                        onTap: () => setInnerState(() => newStatus = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? conf.$1.withValues(alpha: 0.2)
                                : const Color(0xFF1E2D3D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: sel ? conf.$1 : Colors.white12,
                                width: 1.5),
                          ),
                          child: Text(conf.$2,
                              style: TextStyle(
                                  color: sel ? conf.$1 : Colors.white38,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // Response text
                const Text('Your Response',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextField(
                  controller: responseCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Write your response to the student...',
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E2D3D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF3B82F6), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await _svc.respondToGrievance(
                        grievanceId: g['id'],
                        status: newStatus,
                        response: responseCtrl.text.trim(),
                      );
                      if (ok && mounted) {
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Response saved'),
                            backgroundColor: Color(0xFF22C55E),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Response',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Grievance Portal',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          )
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF3B82F6),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildStats()),
                  SliverToBoxAdapter(child: _buildFilterBar()),
                  _grievances.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text('No complaints found',
                                style: TextStyle(color: Colors.white38)),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _WardenGrievanceCard(
                                grievance: _grievances[i],
                                onRespond: () =>
                                    _openRespond(_grievances[i]),
                              ),
                              childCount: _grievances.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatChip('Total', _stats['total'] ?? 0, Colors.white70),
          const SizedBox(width: 8),
          _StatChip('Pending', _stats['pending'] ?? 0, Colors.orange),
          const SizedBox(width: 8),
          _StatChip('In Progress', _stats['in_progress'] ?? 0,
              const Color(0xFFA78BFA)),
          const SizedBox(width: 8),
          _StatChip(
              'Resolved', _stats['resolved'] ?? 0, const Color(0xFF22C55E)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all', 'All', Colors.white70),
      ('pending', 'Pending', Colors.orange),
      ('acknowledged', 'Acknowledged', const Color(0xFF3B82F6)),
      ('in_progress', 'In Progress', const Color(0xFFA78BFA)),
      ('resolved', 'Resolved', const Color(0xFF22C55E)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: filters.map((f) {
          final sel = _filterStatus == f.$1;
          return GestureDetector(
            onTap: () {
              setState(() => _filterStatus = f.$1);
              _loadData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    sel ? f.$3.withValues(alpha: 0.2) : const Color(0xFF1E2D3D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? f.$3 : Colors.white12, width: 1.5),
              ),
              child: Text(f.$2,
                  style: TextStyle(
                      color: sel ? f.$3 : Colors.white38,
                      fontWeight:
                          sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
            ),
          );
        }).toList(),
      ),
    );
  }

  (Color, String) _statusConf(String s) {
    switch (s) {
      case 'pending':
        return (Colors.orange, 'Pending');
      case 'acknowledged':
        return (const Color(0xFF3B82F6), 'Acknowledged');
      case 'in_progress':
        return (const Color(0xFFA78BFA), 'In Progress');
      case 'resolved':
        return (const Color(0xFF22C55E), 'Resolved');
      case 'dismissed':
        return (Colors.red, 'Dismissed');
      default:
        return (Colors.grey, s);
    }
  }
}

// ─────────────────────────────────────
// Warden grievance card
// ─────────────────────────────────────
class _WardenGrievanceCard extends StatelessWidget {
  final Map<String, dynamic> grievance;
  final VoidCallback onRespond;
  const _WardenGrievanceCard(
      {required this.grievance, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    final g = grievance;
    final status = g['status'] ?? 'pending';
    final isAnon = g['is_anonymous'] == true;
    final category = g['category'] ?? 'other';
    final priority = g['priority'] ?? 'medium';
    final createdAt = g['created_at'] != null
        ? DateFormat('dd MMM yyyy').format(
            DateTime.parse(g['created_at']).toLocal())
        : '';

    final statusConf = _statusConf(status);
    final priorityColor = _priorityColor(priority);

    return GestureDetector(
      onTap: onRespond,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusConf.$1.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Text(_catEmoji(category),
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g['title'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isAnon)
                            const Row(
                              children: [
                                Icon(Icons.visibility_off,
                                    size: 11, color: Color(0xFFA78BFA)),
                                SizedBox(width: 3),
                                Text('Anonymous',
                                    style: TextStyle(
                                        color: Color(0xFFA78BFA),
                                        fontSize: 11)),
                                SizedBox(width: 8),
                              ],
                            )
                          else ...[
                            Text(g['student_name'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                            const SizedBox(width: 6),
                            Text('•',
                                style: const TextStyle(
                                    color: Colors.white24, fontSize: 11)),
                            const SizedBox(width: 6),
                            Text(g['student_id'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                            const SizedBox(width: 6),
                          ],
                          if (g['room_number'] != null) ...[
                            const Icon(Icons.bed, size: 11, color: Colors.white24),
                            const SizedBox(width: 3),
                            Text(g['room_number'],
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Badge(label: statusConf.$2, color: statusConf.$1),
                    const SizedBox(height: 4),
                    _Badge(label: priority.toUpperCase(), color: priorityColor, small: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              g['description'] ?? '',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: Colors.white24),
                    const SizedBox(width: 4),
                    Text(createdAt,
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 11)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.reply, size: 13, color: Color(0xFF93C5FD)),
                      SizedBox(width: 4),
                      Text('Respond',
                          style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusConf(String s) {
    switch (s) {
      case 'pending':
        return (Colors.orange, 'Pending');
      case 'acknowledged':
        return (const Color(0xFF3B82F6), 'Acknowledged');
      case 'in_progress':
        return (const Color(0xFFA78BFA), 'In Progress');
      case 'resolved':
        return (const Color(0xFF22C55E), 'Resolved');
      case 'dismissed':
        return (Colors.red, 'Dismissed');
      default:
        return (Colors.grey, s);
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'urgent':
        return const Color(0xFF7C3AED);
      default:
        return Colors.grey;
    }
  }

  String _catEmoji(String cat) {
    const map = {
      'maintenance': '🔧',
      'cleanliness': '🧹',
      'food': '🍽️',
      'security': '🛡️',
      'internet': '📡',
      'roommate': '🤝',
      'other': '💬',
    };
    return map[cat] ?? '💬';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;
  const _Badge(
      {required this.label, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 7 : 10, vertical: small ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: small ? 9 : 11,
              fontWeight: FontWeight.bold)),
    );
  }
}
