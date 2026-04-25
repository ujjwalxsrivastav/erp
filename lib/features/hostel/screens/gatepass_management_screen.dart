import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hostel_service.dart';
import '../../../services/auth_service.dart';

class GatepassManagementScreen extends StatefulWidget {
  const GatepassManagementScreen({super.key});
  @override
  State<GatepassManagementScreen> createState() =>
      _GatepassManagementScreenState();
}

class _GatepassManagementScreenState extends State<GatepassManagementScreen>
    with TickerProviderStateMixin {
  final _service = HostelService();
  final _authService = AuthService();
  late TabController _tabCtrl;
  late AnimationController _fadeCtrl;

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String _wardenName = 'Warden';

  static const _tabs = ['pending', 'approved', 'rejected', 'all'];
  static const _tabLabels = ['Pending', 'Approved', 'Rejected', 'All'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _tabCtrl.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final name = await _authService.getCurrentUsername();
    if (mounted) setState(() => _wardenName = name ?? 'Warden');
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _service.getGatepasses();
    if (mounted) setState(() { _all = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    final status = _tabs[_tabCtrl.index];
    if (status == 'all') return _all;
    return _all.where((g) => g['status'] == status).toList();
  }

  Future<void> _updateStatus(String id, String status) async {
    final success = await _service.updateGatepassStatus(id, status, _wardenName);
    if (mounted) {
      final labels = {
        'approved': '✅ Gatepass Approved',
        'rejected': '❌ Gatepass Rejected',
        'completed': '🏠 Student Returned',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(labels[status] ?? 'Updated'),
        backgroundColor: status == 'approved' || status == 'completed'
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
      if (success) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _all.where((g) => g['status'] == 'pending').length;
    final outNow = _all.where((g) => g['status'] == 'approved').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFF0D1B2A),
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _load),
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
                  colors: [Color(0xFF831843), Color(0xFFBE185D)],
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gatepass Management',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Digital leave approval system',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statChip('$pending', 'Pending', const Color(0xFFFBBF24)),
                      const SizedBox(width: 10),
                      _statChip('$outNow', 'Out Now', const Color(0xFFF9A8D4)),
                      const SizedBox(width: 10),
                      _statChip('${_all.length}', 'Total', Colors.white60),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
            ),
          ],
          body: Column(
            children: [
              Container(
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
                          colors: [Color(0xFFEC4899), Color(0xFFBE185D)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
                    padding: const EdgeInsets.all(4),
                    tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFEC4899)))
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _buildGatepassCard(_filtered[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: const Color(0xFFEC4899),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Gatepass',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.door_front_door_outlined,
              color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('No gatepasses found',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGatepassCard(Map<String, dynamic> g) {
    final status = g['status'] as String? ?? 'pending';
    final name = g['student_name'] ?? 'Unknown';
    final reason = g['reason'] ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    DateTime? outTime, expectedIn;
    try {
      outTime = DateTime.parse(g['out_time'].toString());
      expectedIn = DateTime.parse(g['expected_in_time'].toString());
    } catch (_) {}

    final fmt = DateFormat('dd MMM, hh:mm a');
    final statusColor = {
          'pending': const Color(0xFFFBBF24),
          'approved': const Color(0xFF34D399),
          'rejected': const Color(0xFFF87171),
          'completed': const Color(0xFF93C5FD),
        }[status] ??
        Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                        colors: [
                          statusColor.withValues(alpha: 0.3),
                          statusColor.withValues(alpha: 0.1)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text(g['student_id'] ?? '',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('"$reason"',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _timeRow(Icons.logout_rounded, 'OUT',
                        outTime != null ? fmt.format(outTime) : '—')),
                Expanded(
                    child: _timeRow(Icons.login_rounded, 'EXPECTED IN',
                        expectedIn != null ? fmt.format(expectedIn) : '—')),
              ],
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus(g['id'], 'rejected'),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        side: const BorderSide(
                            color: Color(0xFFF87171), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(g['id'], 'approved'),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(g['id'], 'completed'),
                  icon: const Icon(Icons.home_rounded, size: 16),
                  label: const Text('Mark as Returned'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white24, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  void _showCreateSheet() {
    final studentIdCtrl = TextEditingController();
    final studentNameCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime? outTime;
    DateTime? expectedIn;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Create New Gatepass',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _darkField(studentIdCtrl, 'Student ID'),
                const SizedBox(height: 12),
                _darkField(studentNameCtrl, 'Student Name'),
                const SizedBox(height: 12),
                _darkField(reasonCtrl, 'Reason for Leave', maxLines: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dateTimePickerBtn(
                        label: outTime != null
                            ? DateFormat('dd MMM, hh:mm a').format(outTime!)
                            : 'Out Time',
                        icon: Icons.logout_rounded,
                        color: const Color(0xFFFBBF24),
                        onTap: () async {
                          final d = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 30)));
                          if (d != null) {
                            final t = await showTimePicker(
                                context: ctx, initialTime: TimeOfDay.now());
                            if (t != null) {
                              setModalState(() => outTime =
                                  DateTime(d.year, d.month, d.day, t.hour, t.minute));
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateTimePickerBtn(
                        label: expectedIn != null
                            ? DateFormat('dd MMM, hh:mm a').format(expectedIn!)
                            : 'Expected Return',
                        icon: Icons.login_rounded,
                        color: const Color(0xFF34D399),
                        onTap: () async {
                          final d = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 30)));
                          if (d != null) {
                            final t = await showTimePicker(
                                context: ctx, initialTime: TimeOfDay.now());
                            if (t != null) {
                              setModalState(() => expectedIn =
                                  DateTime(d.year, d.month, d.day, t.hour, t.minute));
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (studentIdCtrl.text.isEmpty ||
                          studentNameCtrl.text.isEmpty ||
                          reasonCtrl.text.isEmpty ||
                          outTime == null ||
                          expectedIn == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill all fields'),
                              behavior: SnackBarBehavior.floating));
                        return;
                      }
                      Navigator.pop(ctx);
                      final ok = await _service.createGatepass(
                        studentId: studentIdCtrl.text.trim(),
                        studentName: studentNameCtrl.text.trim(),
                        reason: reasonCtrl.text.trim(),
                        outTime: outTime!,
                        expectedInTime: expectedIn!,
                      );
                      if (ok) {
                        _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('✅ Gatepass created!'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Create Gatepass',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _darkField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1E2D3D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _dateTimePickerBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
