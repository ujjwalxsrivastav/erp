import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/hr_workflow_service.dart';

class RecruitmentScreen extends StatefulWidget {
  final String username;
  const RecruitmentScreen({super.key, this.username = ''});

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  final _service = HrWorkflowService();
  List<Map<String, dynamic>> _postings = [];
  List<Map<String, dynamic>> _applications = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _selectedPosting;
  bool _isLoading = true;
  bool _isLoadingApplications = false;

  static const List<String> _postTypes = [
    'permanent',
    'contract',
    'adjunct',
    'visiting',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final postings = await _service.getPostings();
    final stats = await _service.getRecruitmentStats();
    if (mounted) {
      setState(() {
        _postings = postings;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPosting(Map<String, dynamic> posting) async {
    setState(() {
      _selectedPosting = posting;
      _isLoadingApplications = true;
    });
    final apps =
        await _service.getApplications(postingId: posting['id'].toString());
    if (mounted) {
      setState(() {
        _applications = apps;
        _isLoadingApplications = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'published':
      case 'selected':
      case 'offered':
      case 'joined':
        return AppTheme.success;
      case 'shortlisted':
      case 'interview_scheduled':
        return AppTheme.info;
      case 'closed':
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _statusChip(String? status) {
    final s = status ?? 'draft';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(s).withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        s.replaceAll('_', ' ').toUpperCase(),
        style: AppTheme.caption.copyWith(color: _statusColor(s)),
      ),
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.teacherPrimary,
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.extraLightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.teacherPrimary, width: 2),
      ),
    );
  }

  // ---------------- Create Posting ----------------
  Future<void> _showCreatePostingDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final eligibilityCtrl = TextEditingController();
    final vacanciesCtrl = TextEditingController(text: '1');
    String postType = 'permanent';
    String status = 'draft';
    DateTime? closingDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Job Posting'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: _fieldDecoration('Post Title *',
                        icon: Icons.work_outline),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: deptCtrl,
                    decoration: _fieldDecoration('Department',
                        icon: Icons.business),
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    value: postType,
                    decoration: _fieldDecoration('Post Type'),
                    items: _postTypes
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t[0].toUpperCase() + t.substring(1))))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => postType = v ?? 'permanent'),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: vacanciesCtrl,
                    decoration: _fieldDecoration('Vacancies',
                        icon: Icons.group_add_outlined),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return int.tryParse(v.trim()) == null
                          ? 'Enter a valid number'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: eligibilityCtrl,
                    decoration: _fieldDecoration(
                        'Eligibility (e.g. NET / PhD as per UGC)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppTheme.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(closingDate == null
                        ? 'Select Closing Date'
                        : 'Closing: ${DateFormat('dd MMM yyyy').format(closingDate!)}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => closingDate = picked);
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: _fieldDecoration('Status'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(
                          value: 'published', child: Text('Published')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => status = v ?? 'draft'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teacherPrimary),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child:
                  const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final ok = await _service.createPosting({
        'title': titleCtrl.text.trim(),
        'department':
            deptCtrl.text.trim().isEmpty ? null : deptCtrl.text.trim(),
        'post_type': postType,
        'vacancies': int.tryParse(vacanciesCtrl.text.trim()) ?? 1,
        'eligibility': eligibilityCtrl.text.trim().isEmpty
            ? null
            : eligibilityCtrl.text.trim(),
        'status': status,
        'closing_date': closingDate?.toIso8601String().split('T')[0],
        'created_by': widget.username.isEmpty ? null : widget.username,
      });
      _showMessage(ok ? 'Posting created' : 'Failed to create posting',
          isError: !ok);
      if (ok) _loadData();
    }
    titleCtrl.dispose();
    deptCtrl.dispose();
    eligibilityCtrl.dispose();
    vacanciesCtrl.dispose();
  }

  // ---------------- Add Application ----------------
  Future<void> _showApplyDialog() async {
    final posting = _selectedPosting;
    if (posting == null) return;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final qualCtrl = TextEditingController();
    final expCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Application'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration:
                      _fieldDecoration('Applicant Name *', icon: Icons.person),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: AppTheme.md),
                TextFormField(
                  controller: emailCtrl,
                  decoration: _fieldDecoration('Email', icon: Icons.email),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppTheme.md),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: _fieldDecoration('Phone', icon: Icons.phone),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppTheme.md),
                TextFormField(
                  controller: qualCtrl,
                  decoration:
                      _fieldDecoration('Qualification', icon: Icons.school),
                ),
                const SizedBox(height: AppTheme.md),
                TextFormField(
                  controller: expCtrl,
                  decoration: _fieldDecoration('Experience (years)',
                      icon: Icons.timeline),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return double.tryParse(v.trim()) == null
                        ? 'Enter a valid number'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final ok = await _service.applyToPosting({
        'posting_id': posting['id'],
        'applicant_name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'qualification':
            qualCtrl.text.trim().isEmpty ? null : qualCtrl.text.trim(),
        'experience_years': double.tryParse(expCtrl.text.trim()) ?? 0,
        'status': 'applied',
      });
      _showMessage(ok ? 'Application added' : 'Failed to add application',
          isError: !ok);
      if (ok) _selectPosting(posting);
    }
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    qualCtrl.dispose();
    expCtrl.dispose();
  }

  // ---------------- Application Actions ----------------
  Future<void> _scheduleInterview(Map<String, dynamic> app) async {
    DateTime picked = DateTime.now().add(const Duration(days: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: picked,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    final interviewAt = DateTime(
        date.year, date.month, date.day, time?.hour ?? 10, time?.minute ?? 0);
    final ok = await _service.updateApplicationStatus(
      app['id'].toString(),
      'interview_scheduled',
      interviewDate: interviewAt,
    );
    _showMessage(
        ok ? 'Interview scheduled' : 'Failed to schedule interview',
        isError: !ok);
    if (ok && _selectedPosting != null) _selectPosting(_selectedPosting!);
  }

  Future<void> _selectCandidate(Map<String, dynamic> app) async {
    final marksCtrl = TextEditingController(
        text: app['interview_marks']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Candidate'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: marksCtrl,
            decoration:
                _fieldDecoration('Interview Marks', icon: Icons.score),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Marks are required to select';
              }
              return double.tryParse(v.trim()) == null
                  ? 'Enter a valid number'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teacherPrimary),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child:
                const Text('Select', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == true) {
      final ok = await _service.updateApplicationStatus(
        app['id'].toString(),
        'selected',
        interviewMarks: double.tryParse(marksCtrl.text.trim()),
      );
      _showMessage(ok ? 'Candidate selected' : 'Failed to update',
          isError: !ok);
      if (ok && _selectedPosting != null) _selectPosting(_selectedPosting!);
    }
    marksCtrl.dispose();
  }

  Future<void> _simpleStatusUpdate(
      Map<String, dynamic> app, String status, String label) async {
    final ok =
        await _service.updateApplicationStatus(app['id'].toString(), status);
    _showMessage(ok ? label : 'Failed to update application', isError: !ok);
    if (ok && _selectedPosting != null) _selectPosting(_selectedPosting!);
  }

  Future<void> _changePostingStatus(
      Map<String, dynamic> posting, String status) async {
    final ok =
        await _service.updatePostingStatus(posting['id'].toString(), status);
    _showMessage(ok ? 'Posting $status' : 'Failed to update posting',
        isError: !ok);
    if (ok) _loadData();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.teacherPrimary,
        onPressed: _showCreatePostingDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Posting',
            style: TextStyle(color: Colors.white)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.teacherPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.teacherGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.lg, 56, AppTheme.lg, AppTheme.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Recruitment',
                          style: AppTheme.h3.copyWith(color: AppTheme.white),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'Job postings, applications & selection pipeline',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: AppTheme.md),
                        Row(
                          children: [
                            _statMini('Open Posts',
                                _stats['openPostings']?.toString() ?? '0'),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Applications',
                                _stats['totalApplications']?.toString() ?? '0'),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Joined',
                                _stats['joined']?.toString() ?? '0'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.teacherPrimary),
              ),
            )
          else if (_postings.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.work_off_outlined,
                        size: 64, color: AppTheme.lightGray),
                    const SizedBox(height: AppTheme.md),
                    Text('No job postings yet',
                        style: AppTheme.h5
                            .copyWith(color: AppTheme.mediumGray)),
                    const SizedBox(height: AppTheme.sm),
                    const Text('Create the first posting to start hiring.',
                        style: TextStyle(color: AppTheme.lightGray)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ..._postings.map(_buildPostingCard),
                  if (_selectedPosting != null) ...[
                    const SizedBox(height: AppTheme.lg),
                    _buildApplicationsSection(),
                  ],
                  const SizedBox(height: 80),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statMini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: AppTheme.h4.copyWith(color: AppTheme.white)),
        Text(label,
            style: AppTheme.caption.copyWith(color: Colors.white70)),
      ],
    );
  }

  Widget _buildPostingCard(Map<String, dynamic> posting) {
    final isSelected = _selectedPosting?['id'] == posting['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        elevated: isSelected,
        onTap: () => _selectPosting(posting),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.teacherPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.work_outline,
                      color: AppTheme.teacherPrimary),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(posting['title']?.toString() ?? 'Untitled Post',
                          style: AppTheme.h5),
                      Text(
                        '${posting['department'] ?? '-'} • ${posting['post_type'] ?? ''}',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                _statusChip(posting['status']?.toString()),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            Row(
              children: [
                const Icon(Icons.group_add_outlined,
                    size: 16, color: AppTheme.lightGray),
                const SizedBox(width: 4),
                Text('${posting['vacancies'] ?? 1} vacancies',
                    style: AppTheme.bodySmall),
                const SizedBox(width: AppTheme.md),
                const Icon(Icons.event, size: 16, color: AppTheme.lightGray),
                const SizedBox(width: 4),
                Text('Closes ${_formatDate(posting['closing_date'])}',
                    style: AppTheme.bodySmall),
              ],
            ),
            if (posting['eligibility'] != null) ...[
              const SizedBox(height: AppTheme.sm),
              Text('Eligibility: ${posting['eligibility']}',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.mediumGray)),
            ],
            const SizedBox(height: AppTheme.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (posting['status'] == 'draft')
                  TextButton.icon(
                    onPressed: () => _changePostingStatus(posting, 'published'),
                    icon: const Icon(Icons.publish, size: 18),
                    label: const Text('Publish'),
                  ),
                if (posting['status'] == 'published')
                  TextButton.icon(
                    onPressed: () => _changePostingStatus(posting, 'closed'),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Close'),
                  ),
                TextButton.icon(
                  onPressed: () => _selectPosting(posting),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Applications'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsSection() {
    final posting = _selectedPosting!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Applications — ${posting['title'] ?? ''}',
                  style: AppTheme.h5),
            ),
            GradientButton(
              text: 'Add',
              icon: Icons.person_add,
              gradient: AppTheme.teacherGradient,
              height: 40,
              width: 110,
              onPressed: _showApplyDialog,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        if (_isLoadingApplications)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.lg),
              child: CircularProgressIndicator(
                  color: AppTheme.teacherPrimary),
            ),
          )
        else if (_applications.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text('No applications for this posting yet.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.mediumGray)),
              ),
            ),
          )
        else
          ..._applications.map(_buildApplicationCard),
      ],
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final name = app['applicant_name']?.toString() ?? 'Applicant';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.teacherPrimary.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppTheme.teacherPrimary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTheme.bodyLarge),
                  Text(
                    '${app['qualification'] ?? '-'} • ${app['experience_years'] ?? 0} yrs exp',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.mediumGray),
                  ),
                  if (app['interview_date'] != null)
                    Text(
                      'Interview: ${_formatDate(app['interview_date'])}'
                      '${app['interview_marks'] != null ? ' • Marks: ${app['interview_marks']}' : ''}',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.info),
                    ),
                ],
              ),
            ),
            _statusChip(app['status']?.toString()),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'shortlist':
                    _simpleStatusUpdate(app, 'shortlisted', 'Shortlisted');
                    break;
                  case 'interview':
                    _scheduleInterview(app);
                    break;
                  case 'select':
                    _selectCandidate(app);
                    break;
                  case 'offer':
                    _simpleStatusUpdate(app, 'offered', 'Offer released');
                    break;
                  case 'joined':
                    _simpleStatusUpdate(app, 'joined', 'Marked as joined');
                    break;
                  case 'reject':
                    _simpleStatusUpdate(app, 'rejected', 'Rejected');
                    break;
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                    value: 'shortlist', child: Text('Shortlist')),
                PopupMenuItem(
                    value: 'interview', child: Text('Schedule Interview')),
                PopupMenuItem(value: 'select', child: Text('Select (Marks)')),
                PopupMenuItem(value: 'offer', child: Text('Release Offer')),
                PopupMenuItem(value: 'joined', child: Text('Mark Joined')),
                PopupMenuItem(value: 'reject', child: Text('Reject')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
