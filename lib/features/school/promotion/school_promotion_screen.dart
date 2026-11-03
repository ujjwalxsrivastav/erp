import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class SchoolPromotionScreen extends StatefulWidget {
  const SchoolPromotionScreen({super.key});

  @override
  State<SchoolPromotionScreen> createState() => _SchoolPromotionScreenState();
}

class _SchoolPromotionScreenState extends State<SchoolPromotionScreen>
    with SingleTickerProviderStateMixin {
  final SchoolService _service = SchoolService();
  late TabController _tabController;

  String _currentSession = '2024-2025';
  String _targetSession = '2025-2026';
  String _selectedSourceClassId = 'cls-9a';
  String _selectedTargetClassId = 'cls-10a';
  String _selectedTargetClassName = 'Class 10-A';

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _archivedSessions = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isPrincipalApproved = false;
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging && _tabController.index == 1) {
        _loadArchivedSessions();
      }
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final classes = await _service.getSchoolClasses();
      _classes = classes.isNotEmpty
          ? classes
          : [
              {'id': 'cls-9a', 'name': 'Class 9', 'section': 'A'},
              {'id': 'cls-10a', 'name': 'Class 10', 'section': 'A'},
              {'id': 'cls-11sci', 'name': 'Class 11', 'section': 'Science'},
              {'id': 'cls-11comm', 'name': 'Class 11', 'section': 'Commerce'},
            ];

      await _loadCandidatesForClass(_selectedSourceClassId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load classes: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCandidatesForClass(String classId) async {
    setState(() => _isLoading = true);
    try {
      final candidates = await _service.getPromotionCandidates(classId: classId);
      if (mounted) {
        setState(() {
          _candidates = candidates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load candidates: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadArchivedSessions() async {
    try {
      final archives = await _service.getArchivedSessions();
      if (mounted) {
        setState(() => _archivedSessions = archives);
      }
    } catch (_) {}
  }

  void _onSourceClassChanged(String? newClassId) {
    if (newClassId == null) return;
    setState(() {
      _selectedSourceClassId = newClassId;
      // Auto-suggest next class
      if (newClassId == 'cls-9a') {
        _selectedTargetClassId = 'cls-10a';
        _selectedTargetClassName = 'Class 10-A';
      } else if (newClassId == 'cls-10a') {
        _selectedTargetClassId = 'cls-11sci';
        _selectedTargetClassName = 'Class 11 Science';
      }
    });
    _loadCandidatesForClass(newClassId);
  }

  Future<void> _executePromotion() async {
    if (!_isPrincipalApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Principal digital confirmation is required before proceeding.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Session Changeover'),
        content: Text(
          'Are you sure you want to promote ${_candidates.where((c) => c['status'] == 'Promoted').length} students '
          'from $_selectedSourceClassId to $_selectedTargetClassName for Session $_targetSession?\n\n'
          'Detained students will remain in the current class and automatic parent retention notices will be issued.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Execute', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _service.executeSessionChangeover(
        currentSession: _currentSession,
        targetSession: _targetSession,
        sourceClassId: _selectedSourceClassId,
        targetClassId: _selectedTargetClassId,
        targetClassName: _selectedTargetClassName,
        studentDecisions: _candidates,
        approvedBy: 'Principal / Academic Committee',
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                const Text('Promotion Complete'),
              ],
            ),
            content: Text(
              'Session Changeover Successful!\n\n'
              '• Promoted: ${result['promotedCount']} students to $_selectedTargetClassName\n'
              '• Retained/Detained: ${result['detainedCount']} students (Parent notices generated)\n'
              '• New Session Q1 fee demands raised in fee ledger.\n'
              '• Previous session record safely archived.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadCandidatesForClass(_selectedSourceClassId);
                  _loadArchivedSessions();
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Execution failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ===== TAB 1: PROMOTION REGISTER & CHANGEOVER =====

  Widget _buildPromotionRegisterTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final promotedCount = _candidates.where((c) => c['status'] == 'Promoted').length;
    final detainedCount = _candidates.where((c) => c['status'] == 'Detained').length;
    final awaitedCount = _candidates.where((c) => c['status'] == 'Result Awaited').length;

    final displayedCandidates = _filterStatus == 'All'
        ? _candidates
        : _candidates.where((c) => c['status'] == _filterStatus).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Session Banner Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF115E59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Annual Session Changeover',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_currentSession ➔ $_targetSession',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Source Class', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSourceClassId,
                              dropdownColor: const Color(0xFF0F766E),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              items: _classes.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['id']?.toString() ?? 'cls-9a',
                                  child: Text('${c['name']} - ${c['section']}'),
                                );
                              }).toList(),
                              onChanged: _onSourceClassChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.arrow_forward, color: Colors.white70, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Target Promoted Class', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTargetClassId,
                              dropdownColor: const Color(0xFF0F766E),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              items: _classes.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['id']?.toString() ?? 'cls-10a',
                                  child: Text('${c['name']} - ${c['section']}'),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  final found = _classes.firstWhere(
                                    (c) => c['id'] == v,
                                    orElse: () => {'name': 'Class 10', 'section': 'A'},
                                  );
                                  setState(() {
                                    _selectedTargetClassId = v;
                                    _selectedTargetClassName = '${found['name']} - ${found['section']}';
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Metrics Row
        Row(
          children: [
            _buildMetricCard('Total Candidates', '${_candidates.length}', Icons.people, Colors.blue),
            const SizedBox(width: 10),
            _buildMetricCard('Promoted', '$promotedCount', Icons.check_circle_outline, Colors.green),
            const SizedBox(width: 10),
            _buildMetricCard('Detained', '$detainedCount', Icons.cancel_outlined, Colors.red),
            const SizedBox(width: 10),
            _buildMetricCard('Awaited', '$awaitedCount', Icons.access_time, Colors.amber),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Promoted', 'Detained', 'Result Awaited'].map((status) {
              final isSel = _filterStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(status),
                  selected: isSel,
                  selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF0F766E),
                  labelStyle: TextStyle(
                    color: isSel ? const Color(0xFF0F766E) : Colors.grey.shade700,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() => _filterStatus = status),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Student Candidates List
        if (displayedCandidates.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No students match the current promotion filter.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...displayedCandidates.map((student) {
            final status = student['status'] ?? 'Promoted';
            final isPromoted = status == 'Promoted';
            final isDetained = status == 'Detained';
            final marks = (student['avg_marks'] as num?)?.toDouble() ?? 0.0;
            final attendance = (student['attendance_pct'] as num?)?.toDouble() ?? 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDetained ? Colors.red.shade300 : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isPromoted
                              ? Colors.green.shade50
                              : (isDetained ? Colors.red.shade50 : Colors.amber.shade50),
                          child: Text(
                            student['roll_number']?.toString() ?? '0',
                            style: TextStyle(
                              color: isPromoted
                                  ? Colors.green.shade800
                                  : (isDetained ? Colors.red.shade800 : Colors.amber.shade800),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name']?.toString() ?? 'Student',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Adm No: ${student['admission_no'] ?? student['id']} • Current: ${student['class_name'] ?? _selectedSourceClassId}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: status,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'Promoted', child: Text('Promoted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Detained', child: Text('Detained', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Result Awaited', child: Text('Result Awaited', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setState(() {
                                student['status'] = newVal;
                                if (newVal == 'Detained') {
                                  student['reason'] = 'Academic retention decision by Academic Head';
                                } else {
                                  student['reason'] = 'Eligible for yearly advancement';
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: marks >= 33.0 ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Score: ${marks.toStringAsFixed(1)}% (${marks >= 33.0 ? "Pass" : "Fail"})',
                            style: TextStyle(
                              fontSize: 12,
                              color: marks >= 33.0 ? Colors.green.shade800 : Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: attendance >= 75.0 ? Colors.blue.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Attendance: ${attendance.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: attendance >= 75.0 ? Colors.blue.shade800 : Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isDetained) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Detained Notice & Counselor Task will be auto-issued to parent upon session changeover.',
                                style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 20),

        // Principal Approval & Execution Box
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF0F766E), size: 22),
                    const SizedBox(width: 8),
                    const Text('Principal Digital Seal & Approval', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPrincipalApproved,
                  activeColor: const Color(0xFF0F766E),
                  title: const Text(
                    'I certify that Class Teacher performance evaluations and annual promotion criteria have been verified. Approved students will advance to the next academic grade.',
                    style: TextStyle(fontSize: 13),
                  ),
                  onChanged: (v) => setState(() => _isPrincipalApproved = v ?? false),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isProcessing ? null : _executePromotion,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Execute Session Changeover & Archive',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ===== TAB 2: ARCHIVED SESSIONS =====

  Widget _buildArchivedSessionsTab() {
    if (_archivedSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              const Text('No previous sessions archived yet.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Archived sessions will appear here after executing annual changeover.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _archivedSessions.length,
      itemBuilder: (context, index) {
        final archive = _archivedSessions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Session: ${archive['currentSession']} ➔ ${archive['targetSession']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Archived',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${archive['sourceClass']} ➔ ${archive['targetClass']}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Promoted: ${archive['promotedCount']} • Retained: ${archive['detainedCount']} • Total: ${archive['totalStudents']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Approved By: ${archive['approvedBy']} • ${archive['timestamp']?.toString().split('T')[0] ?? ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Promotion & Session Changeover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.school, size: 20), text: 'Promotion Register'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'Session Archives'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPromotionRegisterTab(),
          _buildArchivedSessionsTab(),
        ],
      ),
    );
  }
}
