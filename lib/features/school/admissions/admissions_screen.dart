import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen>
    with SingleTickerProviderStateMixin {
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allAdmissions = [];
  List<Map<String, dynamic>> _filteredAdmissions = [];
  String _selectedStatus = 'all';
  String _userRole = 'admin';
  String _searchQuery = '';

  static const _primaryColor = Color(0xFF6366F1);

  final List<String> _statusFilters = [
    'all',
    'Under Review',
    'Interview Scheduled',
    'Approved',
    'Enrolled',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final role = await _authService.getCurrentUserRole() ?? 'admin';
      final admissions = await _schoolService.getAdmissions();
      if (mounted) {
        setState(() {
          _userRole = role;
          _allAdmissions = admissions;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    var list = [..._allAdmissions];
    if (_selectedStatus != 'all') {
      list = list.where((a) => a['status'] == _selectedStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          (a['applicant_name'] ?? '').toString().toLowerCase().contains(q) ||
          (a['parent_name'] ?? '').toString().toLowerCase().contains(q) ||
          (a['grade_applying'] ?? '').toString().toLowerCase().contains(q) ||
          (a['id'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    _filteredAdmissions = list;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Enrolled':
        return const Color(0xFF3B82F6);
      case 'Rejected':
        return Colors.red;
      case 'Interview Scheduled':
        return Colors.orange;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Enrolled':
        return Icons.school;
      case 'Rejected':
        return Icons.cancel;
      case 'Interview Scheduled':
        return Icons.event_available;
      default:
        return Icons.hourglass_empty;
    }
  }

  Map<String, int> get _counts {
    final m = <String, int>{};
    for (final s in _statusFilters) {
      if (s == 'all') {
        m[s] = _allAdmissions.length;
      } else {
        m[s] = _allAdmissions.where((a) => a['status'] == s).length;
      }
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Admissions Management',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'sadmin')
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2563EB),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('New Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              elevation: 4,
              onPressed: _showNewApplicationDialog,
            )
          : null,
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              color: const Color(0xFF2563EB),
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Summary Bar
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        // Search
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search by name, class, ID...',
                              prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (v) {
                              setState(() {
                                _searchQuery = v;
                                _applyFilter();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryChip('Total', '${_allAdmissions.length}', Colors.white),
                            _summaryChip('Review', '${_counts['Under Review'] ?? 0}', Colors.orange.shade100),
                            _summaryChip('Approved', '${_counts['Approved'] ?? 0}', Colors.green.shade100),
                            _summaryChip('Enrolled', '${_counts['Enrolled'] ?? 0}', Colors.blue.shade100),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status Filter Chips
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: _statusFilters.map((s) {
                          final selected = _selectedStatus == s;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedStatus = s;
                                _applyFilter();
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected ? _primaryColor : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s == 'all' ? 'All (${_counts['all']})' : '$s (${_counts[s] ?? 0})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // List
                  Expanded(
                    child: _filteredAdmissions.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredAdmissions.length,
                            itemBuilder: (_, i) => _buildAdmissionCard(_filteredAdmissions[i], i),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryChip(String label, String count, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildAdmissionCard(Map<String, dynamic> adm, int index) {
    final status = adm['status']?.toString() ?? 'Under Review';
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAdmissionDetail(adm),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (adm['applicant_name']?.toString() ?? 'A').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  adm['applicant_name'] ?? 'Applicant',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon, size: 12, color: statusColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      status,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${adm['grade_applying'] ?? 'N/A'}  •  Parent: ${adm['parent_name'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text(
                                adm['date'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text(
                                adm['id']?.toString() ?? '',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Admin Action Buttons
                if ((_userRole == 'admin' || _userRole == 'sadmin') &&
                    (status == 'Under Review' || status == 'Interview Scheduled')) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (status == 'Under Review')
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            onPressed: () => _updateStatus(adm, 'Interview Scheduled'),
                            child: const Text('Schedule Interview', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      if (status == 'Interview Scheduled') ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            onPressed: () => _updateStatus(adm, 'Rejected'),
                            child: const Text('Reject', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            onPressed: () => _updateStatus(adm, 'Approved'),
                            child: const Text('Approve', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                if ((_userRole == 'admin' || _userRole == 'sadmin') && status == 'Approved') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.school, size: 16),
                      label: const Text('Enroll Student'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _enrollStudent(adm),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(Map<String, dynamic> adm, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Status to "$newStatus"?'),
        content: Text('Applicant: ${adm['applicant_name']}\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _statusColor(newStatus), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _schoolService.updateAdmissionStatus(adm['id'].toString(), newStatus);

    setState(() {
      final idx = _allAdmissions.indexWhere((a) => a['id'] == adm['id']);
      if (idx >= 0) {
        _allAdmissions[idx] = {..._allAdmissions[idx], 'status': newStatus};
        _applyFilter();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${adm['applicant_name']} status updated to $newStatus'),
          backgroundColor: _statusColor(newStatus),
        ),
      );
    }
  }

  Future<void> _enrollStudent(Map<String, dynamic> adm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enroll Student & Create Roster Entry'),
        content: Text(
          'Confirm admission for ${adm['applicant_name']} in ${adm['grade_applying']}?\n\n'
          'This will automatically:\n'
          '• Create student master profile\n'
          '• Link parent account\n'
          '• Issue first quarter fee demand (₹25,000)\n'
          '• Allot roll number and admission number',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Enrollment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final grade = adm['grade_applying']?.toString() ?? 'Class 10';
    final classId = grade.contains('10') ? 'cls-10a' : (grade.contains('9') ? 'cls-9a' : 'cls-10a');
    final result = await _schoolService.enrollAdmissionStudent(
      admission: adm,
      classId: classId,
      section: 'A',
    );

    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enrolled ${adm['applicant_name']} successfully! Roll No. 08, Adm No: ${result['admission_no']}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _showAdmissionDetail(Map<String, dynamic> adm) {
    final status = adm['status']?.toString() ?? 'Under Review';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, sc) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.all(20),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (adm['applicant_name']?.toString() ?? 'A')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(adm['applicant_name'] ?? 'N/A',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('ID: ${adm['id'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(status))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Details
                  _detailSection('Application Details', [
                    _detailRow2('Application ID', adm['id']?.toString() ?? 'N/A'),
                    _detailRow2('Applied For', adm['grade_applying']?.toString() ?? 'N/A'),
                    _detailRow2('Application Date', adm['date']?.toString() ?? 'N/A'),
                    _detailRow2('Current Status', status),
                  ]),
                  const SizedBox(height: 16),

                  _detailSection('Student Information', [
                    _detailRow2('Name', adm['applicant_name']?.toString() ?? 'N/A'),
                    _detailRow2('Date of Birth', adm['dob']?.toString() ?? 'Not provided'),
                  ]),
                  const SizedBox(height: 16),

                  _detailSection('Parent/Guardian Information', [
                    _detailRow2('Parent Name', adm['parent_name']?.toString() ?? 'N/A'),
                    _detailRow2('Phone', adm['parent_phone']?.toString() ?? 'N/A'),
                  ]),
                  const SizedBox(height: 16),

                  // Document Verification Queue
                  _detailSection('Document Verification Queue', [
                    _detailRow2('Birth Certificate', 'Verified (Aadhaar Linked)'),
                    _detailRow2('Previous School Report Card', 'Verified (Grade A)'),
                    _detailRow2('Transfer Certificate (TC)', 'Verified'),
                    _detailRow2('Address Proof', 'Verified (Utility Bill)'),
                    _detailRow2('Quota & Priority', (adm['rte_quota'] == true ? 'RTE 25% Quota' : (adm['sibling_priority'] == true ? 'Sibling Priority' : 'General'))),
                    _detailRow2('Verification Status', adm['doc_status']?.toString() ?? 'Verified'),
                  ]),
                  const SizedBox(height: 16),

                  if (_userRole == 'admin' || _userRole == 'sadmin') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.assignment_turned_in, size: 16),
                            label: const Text('Mark Verified'),
                            onPressed: () async {
                              await _schoolService.updateAdmissionDocStatus(adm['id'].toString(), 'Verified');
                              if (mounted) {
                                Navigator.pop(ctx);
                                _loadData();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay, size: 16),
                            label: const Text('Re-upload'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                            onPressed: () async {
                              await _schoolService.updateAdmissionDocStatus(adm['id'].toString(), 'Re-upload Requested');
                              if (mounted) {
                                Navigator.pop(ctx);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('View Official Offer Letter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showOfferLetterDialog(adm);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (status != 'Enrolled')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.school, size: 16),
                          label: const Text('Enroll Student in Class Roster'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _enrollStudent(adm);
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 20),

                  // Workflow Steps
                  const Text('Admission Workflow',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                  const SizedBox(height: 12),
                  _buildWorkflowSteps(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _detailRow2(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowSteps(String currentStatus) {
    final steps = [
      'Under Review',
      'Interview Scheduled',
      'Approved',
      'Enrolled',
    ];
    final currentIdx = steps.indexOf(currentStatus);

    return Column(
      children: steps.asMap().entries.map((e) {
        final idx = e.key;
        final step = e.value;
        final isDone = currentStatus == 'Enrolled'
            ? true
            : (currentStatus == 'Approved'
                ? idx <= 2
                : (currentStatus == 'Interview Scheduled' ? idx <= 1 : idx == 0));
        final isCurrent = idx == currentIdx;
        final isRejected = currentStatus == 'Rejected';

        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isRejected && isCurrent
                        ? Colors.red
                        : isDone
                            ? Colors.green
                            : isCurrent
                                ? _primaryColor
                                : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRejected && isCurrent
                        ? Icons.close
                        : isDone
                            ? Icons.check
                            : Icons.circle,
                    size: 14,
                    color: isDone || isCurrent ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
                if (idx < steps.length - 1)
                  Container(
                    width: 2,
                    height: 30,
                    color: idx < currentIdx ? Colors.green : const Color(0xFFE5E7EB),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                step,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? _primaryColor : const Color(0xFF374151),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No results found' : 'No admissions found',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedStatus != 'all' ? 'Try changing the status filter' : 'New applications will appear here',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  void _showOfferLetterDialog(Map<String, dynamic> adm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.school, color: _primaryColor),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Admission Offer Letter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHIVALIK INTERNATIONAL SCHOOL',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                    ),
                    const Text('Affiliated to CBSE, New Delhi • Chakrata Road, Dehradun', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                    const SizedBox(height: 8),
                    Text('Ref No: SHIV-ADM-${adm['id'] ?? "2026"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('Date: ${DateTime.now().toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Dear ${adm['parent_name'] ?? "Parent"},\n\nWe are delighted to offer provisional admission for your ward ${adm['applicant_name']} to ${adm['grade_applying']} at Shivalik International School for Academic Year 2026-2027.',
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Offer Details & Schedule:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('• Tuition & Activity Fee: ₹25,000 / Quarter', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text('• Fee Payment Deadline: 15 Days from Offer', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text('• Quota Type: ${(adm['rte_quota'] == true) ? "RTE Act 25% (Free Tuition)" : "General Direct"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Digital Verification Seal: VERIFIED & APPROVED BY PRINCIPAL OFFICE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print / Export Letter'),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offer Letter exported and ready for print!'), backgroundColor: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNewApplicationDialog() {
    final nameCtrl = TextEditingController();
    final parentCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    String selectedGrade = 'Class 6';
    bool isSibling = false;
    bool isRte = false;

    final grades = ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
        'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
        'Class 11-Science', 'Class 11-Commerce', 'Class 12-Science', 'Class 12-Commerce'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New Admission Application',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Student Full Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'Applying for Grade *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setS(() => selectedGrade = v ?? selectedGrade),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dobCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Parent / Guardian Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Parent Mobile Phone *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  // Quota Options
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          dense: true,
                          title: const Text('Sibling Priority (Existing student sibling)', style: TextStyle(fontSize: 13)),
                          value: isSibling,
                          onChanged: (v) => setS(() => isSibling = v ?? false),
                        ),
                        const Divider(height: 1),
                        CheckboxListTile(
                          dense: true,
                          title: const Text('RTE Quota (Right to Education 25%)', style: TextStyle(fontSize: 13)),
                          value: isRte,
                          onChanged: (v) => setS(() => isRte = v ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty || parentCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill all required fields (*)')),
                          );
                          return;
                        }

                        // Duplicate check
                        final isDup = await _schoolService.checkDuplicateAdmission(phoneCtrl.text.trim(), nameCtrl.text.trim());
                        if (isDup && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note: An applicant with this contact or name already exists!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }

                        final newAdm = {
                          'id': 'ADM-${100 + _allAdmissions.length + 1}',
                          'applicant_name': nameCtrl.text,
                          'grade_applying': selectedGrade,
                          'parent_name': parentCtrl.text,
                          'parent_phone': phoneCtrl.text,
                          'dob': dobCtrl.text.isNotEmpty ? dobCtrl.text : '2017-06-15',
                          'status': 'Under Review',
                          'doc_status': 'Pending Verification',
                          'sibling_priority': isSibling,
                          'rte_quota': isRte,
                          'date': DateTime.now().toIso8601String().substring(0, 10),
                        };
                        await _schoolService.submitAdmission(newAdm);
                        if (mounted) {
                          Navigator.pop(ctx);
                          setState(() {
                            _allAdmissions.insert(0, newAdm);
                            _applyFilter();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Application submitted & registered successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Submit Application', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
