import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/grievance_service.dart';
import '../services/hostel_service.dart';

class StudentGrievanceScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  const StudentGrievanceScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentGrievanceScreen> createState() => _StudentGrievanceScreenState();
}

class _StudentGrievanceScreenState extends State<StudentGrievanceScreen>
    with SingleTickerProviderStateMixin {
  final _svc = GrievanceService();
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _grievances = [];
  bool _loading = true;

  // Form state
  String _selectedCategory = 'maintenance';
  String _selectedPriority = 'medium';
  bool _isAnonymous = false;
  bool _submitting = false;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Room info (optional enrichment)
  String? _roomNumber;
  String? _hostelName;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final gs = await _svc.getStudentGrievances(widget.studentId);
    // Also try to get room info
    final hostelSvc = HostelService();
    final roomDetails =
        await hostelSvc.getStudentRoomDetails(widget.studentId);
    if (mounted) {
      setState(() {
        _grievances = gs;
        _roomNumber = roomDetails?['room_number'];
        _hostelName = roomDetails?['hostel_name'];
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ok = await _svc.submitGrievance(
      studentId: widget.studentId,
      studentName: widget.studentName,
      category: _selectedCategory,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      isAnonymous: _isAnonymous,
      priority: _selectedPriority,
      roomNumber: _roomNumber,
      hostelName: _hostelName,
    );
    setState(() => _submitting = false);
    if (ok && mounted) {
      _titleCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _isAnonymous = false;
        _selectedCategory = 'maintenance';
        _selectedPriority = 'medium';
      });
      await _loadData();
      _tabCtrl.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Complaint submitted successfully'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    }
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
            style:
                TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF3B82F6),
          indicatorWeight: 3,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'My Complaints'),
            Tab(text: 'New Complaint'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildMyComplaints(),
                _buildNewComplaintForm(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 1: MY COMPLAINTS
  // ═══════════════════════════════════════════════════════════
  Widget _buildMyComplaints() {
    if (_grievances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_outlined,
                  color: Color(0xFF3B82F6), size: 40),
            ),
            const SizedBox(height: 16),
            const Text('No complaints filed yet',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Tap "New Complaint" to raise an issue',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF3B82F6),
      backgroundColor: const Color(0xFF1E2D3D),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _grievances.length,
        itemBuilder: (_, i) => _GrievanceCard(grievance: _grievances[i]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 2: NEW COMPLAINT FORM
  // ═══════════════════════════════════════════════════════════
  Widget _buildNewComplaintForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Anonymous toggle banner
            _buildAnonymousBanner(),
            const SizedBox(height: 24),

            // Category
            _sectionLabel('Category'),
            const SizedBox(height: 10),
            _buildCategoryPicker(),
            const SizedBox(height: 20),

            // Priority
            _sectionLabel('Priority'),
            const SizedBox(height: 10),
            _buildPriorityPicker(),
            const SizedBox(height: 20),

            // Title
            _sectionLabel('Subject'),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _titleCtrl,
              hint: 'e.g., Water leakage in bathroom',
              maxLines: 1,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter a subject' : null,
            ),
            const SizedBox(height: 20),

            // Description
            _sectionLabel('Full Description'),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _descCtrl,
              hint:
                  'Describe the issue in detail. The more information you provide, the faster it will be resolved...',
              maxLines: 6,
              validator: (v) => v == null || v.trim().length < 10
                  ? 'Please describe the issue (min 10 chars)'
                  : null,
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _isAnonymous
                                ? 'Submit Anonymously'
                                : 'Submit Complaint',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousBanner() {
    return GestureDetector(
      onTap: () => setState(() => _isAnonymous = !_isAnonymous),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAnonymous
                ? [
                    const Color(0xFF6D28D9).withValues(alpha: 0.3),
                    const Color(0xFF7C3AED).withValues(alpha: 0.15)
                  ]
                : [
                    const Color(0xFF1E2D3D),
                    const Color(0xFF1A2332)
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isAnonymous
                ? const Color(0xFF7C3AED)
                : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isAnonymous
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isAnonymous ? Icons.visibility_off : Icons.person_outline,
                color: _isAnonymous
                    ? const Color(0xFFA78BFA)
                    : Colors.white54,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAnonymous ? 'Anonymous Mode ON' : 'File Anonymously?',
                    style: TextStyle(
                      color: _isAnonymous
                          ? const Color(0xFFA78BFA)
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isAnonymous
                        ? 'Your identity will be hidden from the warden'
                        : 'Your name & room will be visible to the warden',
                    style: TextStyle(
                      color: _isAnonymous
                          ? const Color(0xFFA78BFA).withValues(alpha: 0.7)
                          : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF7C3AED),
              inactiveTrackColor: Colors.white12,
              inactiveThumbColor: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    final cats = [
      ('maintenance', '🔧', 'Maintenance'),
      ('cleanliness', '🧹', 'Cleanliness'),
      ('food', '🍽️', 'Food'),
      ('security', '🛡️', 'Security'),
      ('internet', '📡', 'Internet'),
      ('roommate', '🤝', 'Roommate'),
      ('other', '💬', 'Other'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cats.map((c) {
        final selected = _selectedCategory == c.$1;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = c.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                  : const Color(0xFF1E2D3D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFF3B82F6)
                    : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.$2, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(c.$3,
                    style: TextStyle(
                      color:
                          selected ? const Color(0xFF93C5FD) : Colors.white54,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityPicker() {
    final priorities = [
      ('low', Colors.green, 'Low'),
      ('medium', Colors.orange, 'Medium'),
      ('high', Colors.red, 'High'),
      ('urgent', const Color(0xFF7C3AED), '🚨 Urgent'),
    ];
    return Row(
      children: priorities.map((p) {
        final selected = _selectedPriority == p.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPriority = p.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? p.$2.withValues(alpha: 0.2)
                    : const Color(0xFF1E2D3D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? p.$2 : Colors.white12,
                  width: 1.5,
                ),
              ),
              child: Text(
                p.$3,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? p.$2 : Colors.white38,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E2D3D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1),
      );
}

// ═══════════════════════════════════════════════════════════════
// GRIEVANCE CARD
// ═══════════════════════════════════════════════════════════════
class _GrievanceCard extends StatelessWidget {
  final Map<String, dynamic> grievance;
  const _GrievanceCard({required this.grievance});

  @override
  Widget build(BuildContext context) {
    final status = grievance['status'] ?? 'pending';
    final isAnon = grievance['is_anonymous'] == true;
    final category = grievance['category'] ?? 'other';
    final createdAt = grievance['created_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(grievance['created_at']).toLocal())
        : '';

    final statusConf = _statusConfig(status);
    final catEmoji = _catEmoji(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusConf.$1.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(catEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  grievance['title'] ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(label: statusConf.$2, color: statusConf.$1),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            grievance['description'] ?? '',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isAnon) ...[
                const Icon(Icons.visibility_off,
                    size: 13, color: Color(0xFFA78BFA)),
                const SizedBox(width: 4),
                const Text('Anonymous',
                    style: TextStyle(
                        color: Color(0xFFA78BFA), fontSize: 11)),
                const SizedBox(width: 12),
              ],
              Icon(Icons.access_time, size: 13, color: Colors.white30),
              const SizedBox(width: 4),
              Text(createdAt,
                  style:
                      const TextStyle(color: Colors.white30, fontSize: 11)),
            ],
          ),
          // Warden response
          if (grievance['warden_response'] != null &&
              (grievance['warden_response'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.reply, color: Color(0xFF4ADE80), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      grievance['warden_response'],
                      style: const TextStyle(
                          color: Color(0xFF4ADE80), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, String) _statusConfig(String status) {
    switch (status) {
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
        return (Colors.grey, status);
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
