import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class SchoolCertificatesScreen extends StatefulWidget {
  const SchoolCertificatesScreen({super.key});

  @override
  State<SchoolCertificatesScreen> createState() => _SchoolCertificatesScreenState();
}

class _SchoolCertificatesScreenState extends State<SchoolCertificatesScreen>
    with SingleTickerProviderStateMixin {
  final _schoolService = SchoolService();
  final _authService = AuthService();
  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String _userRole = 'student';
  String _userName = '';
  String _selectedFilter = 'All';

  static const _primaryColor = Color(0xFF059669);

  final List<String> _certTypes = [
    'Transfer Certificate (TC)',
    'Bonafide Certificate',
    'Character Certificate',
    'Study Certificate',
    'Migration Certificate',
    'School Leaving Certificate',
  ];

  // Mock requests
  List<Map<String, dynamic>> get _defaultRequests => [
    {
      'id': 'CERT-001',
      'student_name': 'Priya Sharma',
      'class': '10-A',
      'cert_type': 'Bonafide Certificate',
      'reason': 'Required for bank account opening',
      'status': 'Ready for Collection',
      'requested_date': '2026-10-28',
      'processed_date': '2026-10-31',
      'username': 'sstudent1',
    },
    {
      'id': 'CERT-002',
      'student_name': 'Arjun Kumar',
      'class': '12-A',
      'cert_type': 'Transfer Certificate (TC)',
      'reason': 'Shifting to another school',
      'status': 'Under Review',
      'requested_date': '2026-11-01',
      'processed_date': null,
      'username': 'student2',
    },
    {
      'id': 'CERT-003',
      'student_name': 'Meera Joshi',
      'class': '9-B',
      'cert_type': 'Character Certificate',
      'reason': 'Required for scholarship application',
      'status': 'Issued',
      'requested_date': '2026-10-20',
      'processed_date': '2026-10-23',
      'username': 'student3',
    },
    {
      'id': 'CERT-004',
      'student_name': 'Rohit Verma',
      'class': '11-A',
      'cert_type': 'Study Certificate',
      'reason': 'Part-time job requirement',
      'status': 'Under Review',
      'requested_date': '2026-11-02',
      'processed_date': null,
      'username': 'student4',
    },
    {
      'id': 'CERT-005',
      'student_name': 'Sanya Patel',
      'class': '8-A',
      'cert_type': 'Bonafide Certificate',
      'reason': 'Railway concession pass',
      'status': 'Approved',
      'requested_date': '2026-10-30',
      'processed_date': '2026-11-01',
      'username': 'student5',
    },
  ];

  final List<String> _statusFilters = ['All', 'Under Review', 'Approved', 'Ready for Collection', 'Issued', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final role = await _authService.getCurrentUserRole() ?? 'student';
      final username = await _authService.getCurrentUsername() ?? '';

      List<Map<String, dynamic>> requests = [];
      try {
        final res = await _schoolService.supabase
            .from('school_certificate_requests')
            .select()
            .order('requested_date', ascending: false);
        requests = List<Map<String, dynamic>>.from(res);
      } catch (_) {}

      if (requests.isEmpty) requests = _defaultRequests;

      if (mounted) {
        setState(() {
          _userRole = role;
          _userName = username;
          // Students only see their own requests
          if (role == 'student') {
            _requests = requests.where((r) => r['username'] == username).toList();
          } else {
            _requests = requests;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requests = _defaultRequests;
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_selectedFilter == 'All') return _requests;
    return _requests.where((r) => r['status'] == _selectedFilter).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.blue;
      case 'Ready for Collection':
        return Colors.orange;
      case 'Issued':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.thumb_up;
      case 'Ready for Collection':
        return Icons.assignment_turned_in;
      case 'Issued':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  Map<String, int> get _counts {
    final m = <String, int>{};
    for (final s in _statusFilters) {
      m[s] = s == 'All' ? _requests.length : _requests.where((r) => r['status'] == s).length;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Certificates', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Apply Now'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildApplyTab(),
              ],
            ),
    );
  }

  // ===== TAB 1: REQUESTS LIST =====
  Widget _buildRequestsTab() {
    return Column(
      children: [
        // Stats Summary
        Container(
          color: _primaryColor,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _certStat('${_counts['All']}', 'Total'),
              _certStat('${_counts['Under Review']}', 'Pending'),
              _certStat('${_counts['Ready for Collection']}', 'Ready'),
              _certStat('${_counts['Issued']}', 'Issued'),
            ],
          ),
        ),

        // Filter Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _statusFilters.map((s) {
                final selected = _selectedFilter == s;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? _primaryColor : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$s (${_counts[s] ?? 0})',
                      style: TextStyle(
                        fontSize: 11,
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

        // Request List
        Expanded(
          child: _filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No certificate requests found', style: TextStyle(color: Color(0xFF6B7280))),
                      if (_userRole == 'student') ...[
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
                          onPressed: () => _tabController.animateTo(1),
                          child: const Text('Apply for Certificate'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredRequests.length,
                  itemBuilder: (_, i) => _buildRequestCard(_filteredRequests[i]),
                ),
        ),
      ],
    );
  }

  Widget _certStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final status = req['status']?.toString() ?? 'Under Review';
    final statusColor = _statusColor(status);
    final isAdmin = _userRole == 'admin' || _userRole == 'sadmin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isAdmin ? () => _showRequestDetail(req) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.description, color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['cert_type'] ?? 'Certificate',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 3),
                          if (isAdmin)
                            Text(
                              '${req['student_name'] ?? 'N/A'}  •  Class ${req['class'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          Text(
                            'Requested: ${req['requested_date'] ?? 'N/A'}  •  ID: ${req['id'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(status), size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status == 'Ready for Collection' ? 'Ready' : status,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (req['reason'] != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reason: ${req['reason']}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                if (status == 'Ready for Collection' || status == 'Issued') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status == 'Issued'
                                ? 'Issued on ${req['processed_date'] ?? 'N/A'}'
                                : 'Ready for collection from school office',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                          ),
                        ),
                        if (status == 'Ready for Collection')
                          TextButton(
                            onPressed: () => _viewCertificate(req),
                            child: const Text('Preview', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ],

                // Admin action buttons
                if (isAdmin && status == 'Under Review') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          onPressed: () => _updateRequestStatus(req, 'Rejected'),
                          child: const Text('Reject', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          onPressed: () => _updateRequestStatus(req, 'Approved'),
                          child: const Text('Approve', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],

                if (isAdmin && status == 'Approved') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Generate & Mark Ready'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _generateAndMarkReady(req),
                    ),
                  ),
                ],

                if (isAdmin && status == 'Ready for Collection') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark as Issued'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _updateRequestStatus(req, 'Issued'),
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

  // ===== TAB 2: APPLY =====
  Widget _buildApplyTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.description_outlined, size: 36, color: Colors.white),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apply for a Certificate', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Choose a certificate type to apply. Processing takes 2–3 working days.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Select Certificate Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 14),
        ..._certTypes.map((cert) => _buildCertTypeCard(cert)),
      ],
    );
  }

  Widget _buildCertTypeCard(String certType) {
    final Map<String, dynamic> certInfo = {
      'Transfer Certificate (TC)': {
        'desc': 'Required when transferring to another school. Includes academic record and conduct details.',
        'icon': Icons.school_outlined,
        'color': const Color(0xFFEF4444),
        'days': '5–7 working days',
      },
      'Bonafide Certificate': {
        'desc': 'Confirms student is currently enrolled. Required for bank accounts, travel concessions, etc.',
        'icon': Icons.badge_outlined,
        'color': _primaryColor,
        'days': '1–2 working days',
      },
      'Character Certificate': {
        'desc': 'Certifies good conduct and character. Required for scholarships and job applications.',
        'icon': Icons.verified_user_outlined,
        'color': const Color(0xFF3B82F6),
        'days': '2–3 working days',
      },
      'Study Certificate': {
        'desc': 'Confirms student is currently studying at the institution. For part-time jobs.',
        'icon': Icons.menu_book_outlined,
        'color': const Color(0xFFF59E0B),
        'days': '1–2 working days',
      },
      'Migration Certificate': {
        'desc': 'Required for migrating to another university/board. Issued after TC.',
        'icon': Icons.swap_horiz,
        'color': const Color(0xFF8B5CF6),
        'days': '7–10 working days',
      },
      'School Leaving Certificate': {
        'desc': 'Official document confirming completion of schooling at this institution.',
        'icon': Icons.assignment_turned_in_outlined,
        'color': const Color(0xFF10B981),
        'days': '3–5 working days',
      },
    };

    final info = certInfo[certType] ?? {'desc': '', 'icon': Icons.description, 'color': _primaryColor, 'days': '3 working days'};
    final color = info['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showApplyDialog(certType),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(info['icon'] as IconData, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(certType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                      const SizedBox(height: 4),
                      Text(info['desc'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 2),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(info['days'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== ACTIONS =====
  void _showApplyDialog(String certType) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Apply: $certType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(certType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for certificate *',
                hintText: 'Please specify why you need this certificate...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Note: Your application will be reviewed by the office. You will be notified when ready.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason for the certificate')),
                );
                return;
              }
              final newReq = {
                'id': 'CERT-${_requests.length + 10}',
                'student_name': _userName,
                'class': '10-A',
                'cert_type': certType,
                'reason': reasonCtrl.text.trim(),
                'status': 'Under Review',
                'requested_date': DateTime.now().toIso8601String().substring(0, 10),
                'processed_date': null,
                'username': _userName,
              };
              try {
                await _schoolService.supabase.from('school_certificate_requests').insert(newReq);
              } catch (_) {}
              if (mounted) {
                setState(() => _requests.insert(0, newReq));
                Navigator.pop(ctx);
                _tabController.animateTo(0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Certificate request submitted! We will notify you when ready.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRequestStatus(Map<String, dynamic> req, String newStatus) async {
    setState(() {
      final idx = _requests.indexWhere((r) => r['id'] == req['id']);
      if (idx >= 0) {
        _requests[idx] = {
          ..._requests[idx],
          'status': newStatus,
          'processed_date': DateTime.now().toIso8601String().substring(0, 10),
        };
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request ${req['id']} updated to $newStatus'),
        backgroundColor: _statusColor(newStatus),
      ),
    );
  }

  void _generateAndMarkReady(Map<String, dynamic> req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate Certificate'),
        content: Text(
          'Generate ${req['cert_type']} for ${req['student_name']} and mark as ready for collection?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _updateRequestStatus(req, 'Ready for Collection');
              _viewCertificate(req);
            },
            child: const Text('Generate & Mark Ready'),
          ),
        ],
      ),
    );
  }

  void _viewCertificate(Map<String, dynamic> req) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, color: _primaryColor, size: 32),
                  const SizedBox(width: 8),
                  const Text('ERP School', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Affiliated to State Board of Education', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300), bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Text(
                  req['cert_type'] ?? 'Certificate',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This is to certify that ${req['student_name'] ?? 'the student'} of Class ${req['class'] ?? 'N/A'} is a bonafide student of this school during the academic year 2026-27.',
                style: const TextStyle(fontSize: 13, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      Text(DateTime.now().toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Principal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Text('ERP School', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sending to printer...')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
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

  void _showRequestDetail(Map<String, dynamic> req) {
    _viewCertificate(req);
  }
}

