import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hostel_service.dart';
import '../../../services/auth_service.dart';

class IncidentLogScreen extends StatefulWidget {
  const IncidentLogScreen({super.key});
  @override
  State<IncidentLogScreen> createState() => _IncidentLogScreenState();
}

class _IncidentLogScreenState extends State<IncidentLogScreen>
    with TickerProviderStateMixin {
  final _service = HostelService();
  final _authService = AuthService();
  late AnimationController _fadeCtrl;

  List<Map<String, dynamic>> _incidents = [];
  bool _loading = true;
  String _wardenName = 'Warden';
  String _searchQuery = '';
  String? _selectedSeverity;

  static const _severities = ['low', 'medium', 'high', 'severe'];
  static const _severityColors = {
    'low': Color(0xFF34D399),
    'medium': Color(0xFFFBBF24),
    'high': Color(0xFFF97316),
    'severe': Color(0xFFEF4444),
  };
  static const _severityIcons = {
    'low': Icons.info_outline_rounded,
    'medium': Icons.warning_amber_rounded,
    'high': Icons.error_outline_rounded,
    'severe': Icons.gavel_rounded,
  };

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
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _service.getIncidents();
    if (mounted) setState(() { _incidents = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _incidents;
    if (_selectedSeverity != null) {
      list = list.where((i) => i['severity'] == _selectedSeverity).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((i) {
        final name = (i['student_name'] ?? '').toString().toLowerCase();
        final id = (i['student_id'] ?? '').toString().toLowerCase();
        final title = (i['title'] ?? '').toString().toLowerCase();
        return name.contains(q) || id.contains(q) || title.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in _severities)
        s: _incidents.where((i) => i['severity'] == s).length
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [_buildAppBar(counts)],
          body: Column(
            children: [
              _buildFilters(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFEF4444)))
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _buildIncidentCard(_filtered[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogSheet(),
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Log Incident',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  SliverAppBar _buildAppBar(Map<String, int> counts) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh_rounded), onPressed: _load),
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
                  colors: [Color(0xFF450A0A), Color(0xFF991B1B)],
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Disciplinary Logs',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Incident records & student discipline',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: _severities.map((s) {
                      final color = _severityColors[s]!;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              vertical: 7, horizontal: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: color.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              Text('${counts[s] ?? 0}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 1),
                              Text(s.toUpperCase(),
                                  style: TextStyle(
                                      color: color.withValues(alpha: 0.8),
                                      fontSize: 7,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, ID or title...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E2D3D),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          // Severity chips
          Row(
            children: [
              _filterChip('All', null),
              const SizedBox(width: 8),
              ..._severities
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _filterChip(
                            s[0].toUpperCase() + s.substring(1), s),
                      ))
                  .toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? severity) {
    final selected = _selectedSeverity == severity;
    final color = severity != null
        ? _severityColors[severity]!
        : Colors.white60;
    return GestureDetector(
      onTap: () => setState(() => _selectedSeverity = severity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? color : Colors.white12, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel_rounded, color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          const Text('No incidents logged',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Tap + to log a new incident',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final severity = incident['severity'] as String? ?? 'low';
    final color = _severityColors[severity] ?? const Color(0xFF34D399);
    final icon = _severityIcons[severity] ?? Icons.info_outline_rounded;
    final name = incident['student_name'] ?? 'Unknown';
    final title = incident['title'] ?? '';
    final desc = incident['description'] ?? '';
    final reporter = incident['reported_by'] ?? 'Warden';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    DateTime? incDate;
    try {
      incDate = DateTime.parse(incident['incident_date'].toString());
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
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
                        color: color.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: Text(initials,
                            style: TextStyle(
                                color: color,
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
                          Text(incident['student_id'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Severity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 12),
                          const SizedBox(width: 4),
                          Text(severity.toUpperCase(),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white24, size: 20),
                      onPressed: () => _confirmDelete(incident['id']),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Title
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                const SizedBox(height: 10),
                // Description
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(desc,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13, height: 1.4)),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            color: Colors.white24, size: 14),
                        const SizedBox(width: 4),
                        Text('Reported by $reporter',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    if (incDate != null)
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(incDate),
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2D3D),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Incident?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This action cannot be undone.',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteIncident(id);
              _load();
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogSheet() {
    final studentIdCtrl = TextEditingController();
    final studentNameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String severity = 'low';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
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
                const Text('Log New Incident',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _darkField(studentIdCtrl, 'Student ID')),
                    const SizedBox(width: 10),
                    Expanded(child: _darkField(studentNameCtrl, 'Student Name')),
                  ],
                ),
                const SizedBox(height: 12),
                _darkField(titleCtrl, 'Incident Title'),
                const SizedBox(height: 12),
                _darkField(descCtrl, 'Description (what happened?)', maxLines: 4),
                const SizedBox(height: 16),
                const Text('SEVERITY',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Row(
                  children: _severities.map((s) {
                    final color = _severityColors[s]!;
                    final selected = severity == s;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() => severity = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.25)
                                : const Color(0xFF1E2D3D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: selected ? color : Colors.white12,
                                width: selected ? 2 : 1),
                          ),
                          child: Column(
                            children: [
                              Icon(_severityIcons[s]!, color: color, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                s[0].toUpperCase() + s.substring(1),
                                style: TextStyle(
                                    color: selected ? color : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (studentIdCtrl.text.isEmpty ||
                          studentNameCtrl.text.isEmpty ||
                          titleCtrl.text.isEmpty ||
                          descCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill all fields'),
                              behavior: SnackBarBehavior.floating));
                        return;
                      }
                      Navigator.pop(ctx);
                      final ok = await _service.logIncident(
                        studentId: studentIdCtrl.text.trim(),
                        studentName: studentNameCtrl.text.trim(),
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        severity: severity,
                        reporter: _wardenName,
                      );
                      if (ok) {
                        _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('✅ Incident logged!'),
                                backgroundColor: Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating));
                        }
                      }
                    },
                    icon: const Icon(Icons.gavel_rounded),
                    label: const Text('Log Incident',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

  Widget _darkField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
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
}
