import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../services/auth_service.dart';
import '../services/admission_flow_service.dart';

/// Admission Review Screen — dean / counsellor side of the
/// admission pipeline.
///
/// Lists admission_applications with stats and status filters,
/// opens a full detail view per application, and drives the
/// review workflow: under_review -> documents_pending / approved /
/// rejected -> enrolled (via AdmissionFlowService.convertToStudent).
class AdmissionReviewScreen extends StatefulWidget {
  const AdmissionReviewScreen({super.key});

  @override
  State<AdmissionReviewScreen> createState() => _AdmissionReviewScreenState();
}

const Map<String, String> _statusLabels = {
  'draft': 'Draft',
  'submitted': 'Submitted',
  'under_review': 'Under Review',
  'documents_pending': 'Docs Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'enrolled': 'Enrolled',
};

Color _statusColor(String status) {
  switch (status) {
    case 'submitted':
      return AppTheme.studentPrimary;
    case 'under_review':
      return AppTheme.warning;
    case 'documents_pending':
      return AppTheme.accentOrange;
    case 'approved':
      return AppTheme.success;
    case 'rejected':
      return AppTheme.error;
    case 'enrolled':
      return AppTheme.accentTeal;
    default:
      return AppTheme.lightGray;
  }
}

Widget _statusChip(String status) {
  final color = _statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      _statusLabels[status] ?? status,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

String _shortDate(dynamic iso) {
  if (iso == null) return '—';
  final s = iso.toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

class _AdmissionReviewScreenState extends State<AdmissionReviewScreen> {
  final _service = AdmissionFlowService();
  final _authService = AuthService();
  final _searchController = TextEditingController();

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _applications = [];
  String? _statusFilter;
  bool _isLoading = true;
  String _currentUser = 'admin';

  static const List<String?> _filters = [
    null,
    'submitted',
    'under_review',
    'documents_pending',
    'approved',
    'rejected',
    'enrolled',
    'draft',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final username = await _authService.getCurrentUsername();
    if (mounted && username != null && username.isNotEmpty) {
      setState(() => _currentUser = username);
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final stats = await _service.getAdmissionStats();
    final apps = await _service.getApplications(
      status: _statusFilter,
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _applications = apps;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Review'),
        foregroundColor: AppTheme.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.studentGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildStatsStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.md, AppTheme.sm, AppTheme.md, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, phone or application no.',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide:
                      const BorderSide(color: AppTheme.extraLightGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide:
                      const BorderSide(color: AppTheme.extraLightGray),
                ),
              ),
              onSubmitted: (_) => _refresh(),
              textInputAction: TextInputAction.search,
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.md, vertical: AppTheme.sm),
              children: _filters.map((f) {
                final selected = _statusFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.sm),
                  child: ChoiceChip(
                    label: Text(f == null
                        ? 'All'
                        : (_statusLabels[f] ?? f)),
                    selected: selected,
                    selectedColor:
                        AppTheme.studentPrimary.withOpacity(0.15),
                    onSelected: (_) {
                      setState(() => _statusFilter = f);
                      _refresh();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _applications.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.md),
                          itemCount: _applications.length,
                          itemBuilder: (context, i) =>
                              _buildApplicationCard(_applications[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsStrip() {
    final byStatus =
        (_stats['applicationsByStatus'] as Map?)?.cast<String, int>() ??
            <String, int>{};
    final items = <Map<String, dynamic>>[
      {
        'label': 'Applications',
        'value': _stats['totalApplications'] ?? 0,
        'icon': Icons.description,
        'color': AppTheme.studentPrimary,
      },
      {
        'label': 'Pending Review',
        'value': _stats['pendingReviews'] ?? 0,
        'icon': Icons.hourglass_top,
        'color': AppTheme.warning,
      },
      {
        'label': 'Approved',
        'value': byStatus['approved'] ?? 0,
        'icon': Icons.check_circle,
        'color': AppTheme.success,
      },
      {
        'label': 'Enrolled',
        'value': byStatus['enrolled'] ?? 0,
        'icon': Icons.school,
        'color': AppTheme.accentTeal,
      },
      {
        'label': 'Leads Today',
        'value': _stats['newLeadsToday'] ?? 0,
        'icon': Icons.person_add,
        'color': AppTheme.info,
      },
      {
        'label': 'Converted',
        'value': _stats['convertedCount'] ?? 0,
        'icon': Icons.celebration,
        'color': AppTheme.adminPrimary,
      },
    ];
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppTheme.md, AppTheme.md, AppTheme.md, 0),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final color = item['color'] as Color;
          return Container(
            width: 128,
            margin: const EdgeInsets.only(right: AppTheme.sm),
            child: GlassCard(
              padding: const EdgeInsets.all(AppTheme.sm + 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(item['icon'] as IconData, size: 18, color: color),
                      const SizedBox(width: 6),
                      Text(
                        '${item['value']}',
                        style: AppTheme.h4.copyWith(color: AppTheme.dark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['label'] as String,
                    style:
                        AppTheme.caption.copyWith(color: AppTheme.mediumGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppTheme.lightGray),
          const SizedBox(height: AppTheme.md),
          Text(
            'No applications found',
            style: AppTheme.h5.copyWith(color: AppTheme.mediumGray),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Applications submitted from the admission form will '
            'appear here.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightGray),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final status = (app['status'] ?? 'draft').toString();
    final courseLine = [
      if (app['course'] != null) app['course'].toString(),
      if (app['department'] != null) app['department'].toString(),
      if (app['session'] != null) 'Session ${app['session']}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: GlassCard(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _AdmissionDetailScreen(
                application: app,
                reviewedBy: _currentUser,
              ),
            ),
          );
          _refresh();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppTheme.studentPrimary.withOpacity(0.12),
                  child: Text(
                    (app['student_name'] ?? '?').toString().isNotEmpty
                        ? (app['student_name'] as String)
                            .trim()
                            .split(' ')
                            .first[0]
                            .toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppTheme.studentPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (app['student_name'] ?? 'Unknown').toString(),
                        style: AppTheme.h5.copyWith(color: AppTheme.dark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        app['application_no']?.toString() ?? 'No number',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: AppTheme.sm),
            if (courseLine.isNotEmpty)
              Text(
                courseLine,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.darkGray),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: AppTheme.lightGray),
                const SizedBox(width: 4),
                Text(
                  (app['phone'] ?? '').toString(),
                  style:
                      AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
                ),
                const Spacer(),
                const Icon(Icons.event, size: 14, color: AppTheme.lightGray),
                const SizedBox(width: 4),
                Text(
                  _shortDate(app['created_at']),
                  style:
                      AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL + REVIEW ACTIONS
// ============================================================

class _AdmissionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  final String reviewedBy;

  const _AdmissionDetailScreen({
    required this.application,
    required this.reviewedBy,
  });

  @override
  State<_AdmissionDetailScreen> createState() =>
      _AdmissionDetailScreenState();
}

class _AdmissionDetailScreenState extends State<_AdmissionDetailScreen> {
  final _service = AdmissionFlowService();
  late Map<String, dynamic> _app;
  late Map<String, bool> _documents;
  bool _isBusy = false;

  static const Map<String, String> _documentLabels = {
    'photo': 'Passport Photo',
    'marksheet': 'Marksheet (10th / 12th)',
    'tc': 'Transfer Certificate (TC)',
    'aadhaar': 'Aadhaar Card',
    'caste_certificate': 'Caste Certificate',
  };

  @override
  void initState() {
    super.initState();
    _app = Map<String, dynamic>.from(widget.application);
    _documents = _parseDocuments(_app['documents']);
  }

  Map<String, bool> _parseDocuments(dynamic raw) {
    final result = <String, bool>{
      'photo': false,
      'marksheet': false,
      'tc': false,
      'aadhaar': false,
      'caste_certificate': false,
    };
    if (raw is Map) {
      raw.forEach((key, value) {
        final k = key.toString();
        result[k] = value == true || (value is String && value.isNotEmpty);
      });
    }
    return result;
  }

  String get _status => (_app['status'] ?? 'draft').toString();
  String get _id => _app['id'].toString();

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _changeStatus(String status, {String? remarks}) async {
    setState(() => _isBusy = true);
    final ok = await _service.updateApplicationStatus(
      _id,
      status,
      reviewedBy: widget.reviewedBy,
      remarks: remarks,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (ok) {
      setState(() {
        _app['status'] = status;
        _app['reviewed_by'] = widget.reviewedBy;
        if (remarks != null) _app['review_remarks'] = remarks;
      });
      _toast('Status updated to ${_statusLabels[status] ?? status}');
    } else {
      _toast('Could not update status. Please try again.', error: true);
    }
  }

  Future<void> _toggleDocument(String key, bool value) async {
    setState(() => _documents[key] = value);
    final ok = await _service.updateDocuments(
      _id,
      Map<String, dynamic>.from(_documents),
    );
    if (!ok) {
      if (!mounted) return;
      setState(() => _documents[key] = !value);
      _toast('Could not save the document checklist.', error: true);
    }
  }

  List<String> get _missingDocuments => _documents.entries
      .where((e) => e.value != true)
      .map((e) => _documentLabels[e.key] ?? e.key)
      .toList();

  Future<void> _askDocuments() async {
    final missing = _missingDocuments;
    final controller = TextEditingController(
      text: missing.isEmpty
          ? ''
          : 'Please submit the following documents: ${missing.join(', ')}.',
    );
    final remarks = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ask for Documents'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Message to applicant',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (remarks == null) return;
    await _changeStatus('documents_pending',
        remarks: remarks.isEmpty ? null : remarks);
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final remarks = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection *',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Remarks are required to reject'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (remarks == null) return;
    await _changeStatus('rejected', remarks: remarks);
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Application'),
        content: Text(
          'Approve the application of '
          '${_app['student_name'] ?? 'this applicant'}? After approval '
          'you can enrol them as a student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _changeStatus('approved');
  }

  String _suggestUsername() {
    final name = (_app['student_name'] ?? 'student').toString().toLowerCase();
    final cleaned = name.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    var base = parts.isEmpty ? 'student' : parts.join('.');
    final session = (_app['session'] ?? '').toString();
    final yearMatch = RegExp(r'(\d{4})').firstMatch(session);
    if (yearMatch != null) {
      base = '$base${yearMatch.group(1)!.substring(2)}';
    }
    return base;
  }

  Future<void> _enroll() async {
    final usernameController =
        TextEditingController(text: _suggestUsername());
    final passwordController =
        TextEditingController(text: _suggestUsername());
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enroll Student'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A student login will be created for '
                '${_app['student_name'] ?? 'the applicant'} '
                '(${_app['department'] ?? '—'}, Semester '
                '${_app['semester'] ?? 1}).',
              ),
              const SizedBox(height: AppTheme.md),
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Student Username (ID) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Username is required'
                    : null,
              ),
              const SizedBox(height: AppTheme.md),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Initial Password *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 4)
                    ? 'Password must be at least 4 characters'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Create Student'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final username = usernameController.text.trim();
    setState(() => _isBusy = true);
    final result = await _service.convertToStudent(
      _id,
      username: username,
      password: passwordController.text.trim(),
      createdBy: widget.reviewedBy,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result['success'] == true) {
      setState(() {
        _app['status'] = 'enrolled';
        _app['enrolled_student_id'] = username;
      });
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Student Enrolled'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle,
                  color: AppTheme.success, size: 40),
              const SizedBox(height: AppTheme.sm),
              Text('Student account created successfully.'),
              const SizedBox(height: AppTheme.sm),
              Text(
                'Username: $username',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.xs),
              const Text(
                'Share these login details with the student. Fee '
                'structure can now be assigned from the Finance '
                'module.',
                style: TextStyle(color: AppTheme.mediumGray),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      _toast(
        'Enrolment failed at step ${result['step']}: '
        '${result['error'] ?? 'unknown error'}',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = (_app['extra_details'] is Map)
        ? Map<String, dynamic>.from(_app['extra_details'] as Map)
        : <String, dynamic>{};
    final tenth = (extra['tenth'] is Map)
        ? Map<String, dynamic>.from(extra['tenth'] as Map)
        : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(_app['application_no']?.toString() ?? 'Application'),
        foregroundColor: AppTheme.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.studentGradient),
        ),
      ),
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(),
                const SizedBox(height: AppTheme.md),
                _section('Personal Details', [
                  _row('Name', _app['student_name']),
                  _row('Email', _app['email']),
                  _row('Phone', _app['phone']),
                  _row('Alternate Phone', _app['alternate_phone']),
                  _row('Date of Birth', _app['date_of_birth']),
                  _row('Gender', _app['gender']),
                  _row('Category', _app['category']),
                  _row('Address', _app['address']),
                  _row('City', _app['city']),
                  _row('State', _app['state']),
                  _row('PIN Code', _app['pincode']),
                  _row('Aadhaar', extra['aadhaar']),
                ]),
                _section('Family Details', [
                  _row("Father's Name", _app['father_name']),
                  _row("Father's Phone", _app['father_phone']),
                  _row("Father's Occupation", extra['father_occupation']),
                  _row("Mother's Name", _app['mother_name']),
                  _row("Mother's Occupation", extra['mother_occupation']),
                  _row('Guardian Name', _app['guardian_name']),
                  _row('Guardian Contact', extra['guardian_contact']),
                  _row('Guardian Email', extra['guardian_email']),
                ]),
                _section('Academic Details', [
                  _row('Qualification', _app['qualification']),
                  _row('Board', _app['board']),
                  _row('Stream', extra['stream']),
                  _row('Percentage / CGPA', _app['percentage']),
                  _row('Passing Year', _app['passing_year']),
                  _row('Previous School', _app['previous_school']),
                  _row('10th School', tenth['school']),
                  _row('10th Board', tenth['board']),
                  _row('10th Year', tenth['year']),
                  _row('10th Percentage', tenth['percentage']),
                ]),
                _section('Course Details', [
                  _row('Course', _app['course']),
                  _row('Department', _app['department']),
                  _row('Branch', _app['branch']),
                  _row('Session', _app['session']),
                  _row('Semester', _app['semester']),
                  _row('Section', _app['section']),
                  _row('Batch', extra['batch']),
                  _row('Hostel Required',
                      extra['hostel_required'] == true ? 'Yes' : 'No'),
                  _row('Transport Required',
                      extra['transport_required'] == true ? 'Yes' : 'No'),
                  _row('Source', _app['source']),
                  _row('Applied On', _shortDate(_app['created_at'])),
                ]),
                _documentsCard(),
                if (_app['reviewed_by'] != null ||
                    _app['review_remarks'] != null ||
                    _app['enrolled_student_id'] != null)
                  _section('Review', [
                    _row('Reviewed By', _app['reviewed_by']),
                    _row('Review Remarks', _app['review_remarks']),
                    _row('Enrolled Student ID', _app['enrolled_student_id']),
                  ]),
                const SizedBox(height: AppTheme.md),
                _actionsBar(),
                const SizedBox(height: AppTheme.xl),
              ],
            ),
          ),
          if (_isBusy)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.studentPrimary.withOpacity(0.12),
            child: Text(
              (_app['student_name'] ?? '?').toString().isNotEmpty
                  ? (_app['student_name'] as String)
                      .trim()
                      .split(' ')
                      .first[0]
                      .toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppTheme.studentPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_app['student_name'] ?? 'Unknown').toString(),
                  style: AppTheme.h4.copyWith(color: AppTheme.dark),
                ),
                Text(
                  '${_app['application_no'] ?? ''} · '
                  '${_app['course'] ?? ''} · ${_app['phone'] ?? ''}',
                  style:
                      AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
                ),
              ],
            ),
          ),
          _statusChip(_status),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget?> rows) {
    final visible = rows.whereType<Widget>().toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTheme.h5.copyWith(color: AppTheme.dark),
            ),
            const SizedBox(height: AppTheme.sm),
            ...visible,
          ],
        ),
      ),
    );
  }

  Widget? _row(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.dark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentsCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documents Checklist',
              style: AppTheme.h5.copyWith(color: AppTheme.dark),
            ),
            const SizedBox(height: AppTheme.xs),
            Text(
              'Tick documents as they are received / verified.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.lightGray),
            ),
            ..._documents.entries.map(
              (e) => SwitchListTile(
                value: e.value,
                onChanged: (_status == 'enrolled' || _status == 'rejected')
                    ? null
                    : (v) => _toggleDocument(e.key, v),
                title: Text(_documentLabels[e.key] ?? e.key),
                secondary: Icon(
                  e.value ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: e.value ? AppTheme.success : AppTheme.lightGray,
                ),
                activeColor: AppTheme.studentPrimary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsBar() {
    final canReview = _status == 'submitted' ||
        _status == 'under_review' ||
        _status == 'documents_pending';
    if (_status == 'enrolled') {
      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: Text(
                'This applicant is enrolled as student '
                '${_app['enrolled_student_id'] ?? ''}.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.dark),
              ),
            ),
          ],
        ),
      );
    }
    if (_status == 'rejected') {
      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.cancel, color: AppTheme.error),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: Text(
                'This application was rejected.'
                '${_app['review_remarks'] != null ? ' Reason: ${_app['review_remarks']}' : ''}',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.dark),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (canReview)
          Row(
            children: [
              if (_status == 'submitted')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => _changeStatus('under_review'),
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Start Review'),
                  ),
                ),
              if (_status == 'submitted') const SizedBox(width: AppTheme.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _askDocuments,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Ask Documents'),
                ),
              ),
            ],
          ),
        if (canReview) const SizedBox(height: AppTheme.sm),
        if (canReview)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isBusy ? null : _approve,
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isBusy ? null : _reject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
        if (_status == 'approved')
          GradientButton(
            text: 'Enroll Student',
            icon: Icons.school,
            gradient: AppTheme.studentGradient,
            width: double.infinity,
            isLoading: _isBusy,
            onPressed: _isBusy ? () {} : _enroll,
          ),
      ],
    );
  }
}
