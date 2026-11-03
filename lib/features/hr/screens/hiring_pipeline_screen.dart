import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/teacher_lifecycle_service.dart';
import 'onboarding_screen.dart';

/// Hiring Pipeline — the zero-to-hero teacher recruitment board:
/// management stats, stage-wise candidates per vacancy, interview
/// rounds, selection / rejection records and offer management.
class HiringPipelineScreen extends StatefulWidget {
  final String username;
  const HiringPipelineScreen({super.key, this.username = ''});

  @override
  State<HiringPipelineScreen> createState() => _HiringPipelineScreenState();
}

class _HiringPipelineScreenState extends State<HiringPipelineScreen> {
  final _service = TeacherLifecycleService();

  List<Map<String, dynamic>> _postings = [];
  List<Map<String, dynamic>> _pipeline = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _selectedPosting;
  String _stageFilter = 'all';
  bool _isLoading = true;
  bool _isLoadingPipeline = false;

  static const List<List<String>> _stages = [
    ['all', 'All'],
    ['applied', 'Applied'],
    ['shortlisted', 'Shortlisted'],
    ['interview', 'In Interview'],
    ['selected', 'Selected'],
    ['offered', 'Offered'],
    ['joined', 'Joined'],
    ['rejected', 'Rejected'],
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final postings = await _service.getPostings();
    final stats = await _service.getManagementStats();
    if (!mounted) return;
    setState(() {
      _postings = postings;
      _stats = stats;
      _isLoading = false;
    });
    if (postings.isNotEmpty) {
      final current = _selectedPosting;
      final target = current == null
          ? postings.first
          : postings.firstWhere(
              (p) => p['id'] == current['id'],
              orElse: () => postings.first,
            );
      _selectPosting(target);
    }
  }

  Future<void> _selectPosting(Map<String, dynamic> posting) async {
    setState(() {
      _selectedPosting = posting;
      _isLoadingPipeline = true;
    });
    final pipeline = await _service.getPipeline(posting['id'].toString());
    if (mounted) {
      setState(() {
        _pipeline = pipeline;
        _isLoadingPipeline = false;
      });
    }
  }

  Future<void> _refreshStats() async {
    final stats = await _service.getManagementStats();
    if (mounted) setState(() => _stats = stats);
  }

  String _stageOf(Map<String, dynamic> app) {
    final status = app['status']?.toString() ?? 'applied';
    return status == 'interview_scheduled' ? 'interview' : status;
  }

  Map<String, int> get _stageCounts {
    final counts = <String, int>{'all': _pipeline.length};
    for (var app in _pipeline) {
      final stage = _stageOf(app);
      counts[stage] = (counts[stage] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get _filtered => _stageFilter == 'all'
      ? _pipeline
      : _pipeline.where((a) => _stageOf(a) == _stageFilter).toList();

  List<Map<String, dynamic>> get _recentEvents {
    final raw = _stats['recentEvents'];
    if (raw is List) {
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'selected':
      case 'offered':
      case 'joined':
      case 'accepted':
        return AppTheme.success;
      case 'shortlisted':
      case 'interview_scheduled':
      case 'issued':
        return AppTheme.info;
      case 'rejected':
      case 'declined':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _statusChip(String? status) {
    final s = status ?? 'applied';
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

  IconData _eventIcon(String? type) {
    switch (type) {
      case 'cv_received':
        return Icons.description_outlined;
      case 'shortlisted':
        return Icons.playlist_add_check;
      case 'interview_scheduled':
        return Icons.event_available_outlined;
      case 'interview_done':
        return Icons.how_to_reg_outlined;
      case 'selected':
        return Icons.verified_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'offer_issued':
        return Icons.mail_outline;
      case 'offer_accepted':
        return Icons.thumb_up_outlined;
      case 'joined':
        return Icons.celebration_outlined;
      default:
        return Icons.note_outlined;
    }
  }

  Future<void> _openDetail(Map<String, dynamic> app) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ApplicantDetailPage(
          application: app,
          posting: _selectedPosting!,
          username: widget.username,
        ),
      ),
    );
    if (_selectedPosting != null) _selectPosting(_selectedPosting!);
    _refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                decoration:
                    const BoxDecoration(gradient: AppTheme.teacherGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.lg, 56, AppTheme.lg, AppTheme.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Hiring Pipeline',
                          style: AppTheme.h3.copyWith(color: AppTheme.white),
                        ),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          'CV to classroom — interviews, offers & joining',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: AppTheme.md),
                        Row(
                          children: [
                            _statMini('Vacancies',
                                _stats['totalVacancies']?.toString() ?? '0'),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('In Interview',
                                _stats['inInterview']?.toString() ?? '0'),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Selected',
                                _stats['selected']?.toString() ?? '0'),
                            const SizedBox(width: AppTheme.lg),
                            _statMini('Joined (Month)',
                                _stats['joinedThisMonth']?.toString() ?? '0'),
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
                child:
                    CircularProgressIndicator(color: AppTheme.teacherPrimary),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildOverviewCards(),
                  const SizedBox(height: AppTheme.lg),
                  if (_postings.isEmpty)
                    _buildNoPostings()
                  else ...[
                    _buildPostingSelector(),
                    const SizedBox(height: AppTheme.md),
                    _buildStageChips(),
                    const SizedBox(height: AppTheme.md),
                    if (_isLoadingPipeline)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppTheme.lg),
                          child: CircularProgressIndicator(
                              color: AppTheme.teacherPrimary),
                        ),
                      )
                    else if (_filtered.isEmpty)
                      GlassCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.md),
                            child: Text(
                              _pipeline.isEmpty
                                  ? 'No applications for this vacancy yet. CVs added from the Recruitment screen will appear here.'
                                  : 'No candidates in this stage yet.',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyMedium
                                  .copyWith(color: AppTheme.mediumGray),
                            ),
                          ),
                        ),
                      )
                    else
                      ..._filtered.map(_buildApplicantCard),
                  ],
                  const SizedBox(height: AppTheme.lg),
                  _buildRecentActivity(),
                  const SizedBox(height: 40),
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
        Text(value, style: AppTheme.h4.copyWith(color: AppTheme.white)),
        Text(label, style: AppTheme.caption.copyWith(color: Colors.white70)),
      ],
    );
  }

  Widget _buildOverviewCards() {
    final items = <List<dynamic>>[
      ['Vacancies', _stats['totalVacancies'] ?? 0, Icons.work_outline, AppTheme.teacherPrimary],
      ['Applications', _stats['totalApplications'] ?? 0, Icons.people_outline, AppTheme.info],
      ['In Interview', _stats['inInterview'] ?? 0, Icons.event_available_outlined, AppTheme.accentOrange],
      ['Selected', _stats['selected'] ?? 0, Icons.verified_outlined, AppTheme.success],
      ['Offers Pending', _stats['offersPending'] ?? 0, Icons.mail_outline, AppTheme.adminPrimary],
      ['Rejected (Record)', _stats['rejected'] ?? 0, Icons.cancel_outlined, AppTheme.error],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Management Overview', style: AppTheme.h5),
        const SizedBox(height: AppTheme.md),
        for (var i = 0; i < items.length; i += 3) ...[
          Row(
            children: [
              for (var j = i; j < i + 3 && j < items.length; j++) ...[
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppTheme.md),
                    child: Column(
                      children: [
                        Icon(items[j][2] as IconData,
                            color: items[j][3] as Color, size: 22),
                        const SizedBox(height: AppTheme.sm),
                        Text('${items[j][1]}',
                            style: AppTheme.h4
                                .copyWith(color: items[j][3] as Color)),
                        Text(items[j][0] as String,
                            textAlign: TextAlign.center,
                            style: AppTheme.caption
                                .copyWith(color: AppTheme.mediumGray)),
                      ],
                    ),
                  ),
                ),
                if (j < i + 2 && j < items.length - 1)
                  const SizedBox(width: AppTheme.md),
              ],
            ],
          ),
          if (i + 3 < items.length) const SizedBox(height: AppTheme.md),
        ],
      ],
    );
  }

  Widget _buildNoPostings() {
    return GlassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Column(
            children: [
              const Icon(Icons.work_off_outlined,
                  size: 48, color: AppTheme.lightGray),
              const SizedBox(height: AppTheme.md),
              Text('No job postings yet', style: AppTheme.h5),
              const SizedBox(height: AppTheme.sm),
              const Text(
                'Create a vacancy from the Recruitment screen — its full pipeline will be tracked here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.lightGray),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostingSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vacancy', style: AppTheme.caption.copyWith(color: AppTheme.mediumGray)),
          DropdownButtonFormField<String>(
            value: _selectedPosting?['id']?.toString(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            isExpanded: true,
            items: _postings
                .map((p) => DropdownMenuItem<String>(
                      value: p['id'].toString(),
                      child: Text(
                        '${p['title'] ?? 'Untitled'}'
                        '${p['department'] != null ? ' • ${p['department']}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              final posting =
                  _postings.firstWhere((p) => p['id'].toString() == id);
              setState(() => _stageFilter = 'all');
              _selectPosting(posting);
            },
          ),
          if (_selectedPosting != null)
            Text(
              '${_selectedPosting!['vacancies'] ?? 1} vacancies • '
              '${_selectedPosting!['post_type'] ?? ''} • '
              'Closes ${_formatDate(_selectedPosting!['closing_date'])}',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
            ),
        ],
      ),
    );
  }

  Widget _buildStageChips() {
    final counts = _stageCounts;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _stages.map((stage) {
          final key = stage[0];
          final selected = _stageFilter == key;
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.sm),
            child: ChoiceChip(
              label: Text('${stage[1]} (${counts[key] ?? 0})'),
              selected: selected,
              selectedColor: AppTheme.teacherPrimary.withOpacity(0.18),
              labelStyle: TextStyle(
                color:
                    selected ? AppTheme.teacherDark : AppTheme.mediumGray,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (_) => setState(() => _stageFilter = key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> app) {
    final name = app['applicant_name']?.toString() ?? 'Applicant';
    final rounds = (app['rounds_count'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: GlassCard(
        onTap: () => _openDetail(app),
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
                  const SizedBox(height: AppTheme.xs),
                  Wrap(
                    spacing: AppTheme.sm,
                    runSpacing: AppTheme.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (rounds > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available_outlined,
                                size: 14, color: AppTheme.info),
                            const SizedBox(width: 4),
                            Text(
                              '$rounds round${rounds == 1 ? '' : 's'}'
                              ' (${(app['rounds_completed'] as num?)?.toInt() ?? 0} done)',
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.info),
                            ),
                          ],
                        ),
                      if (app['offer_status'] != null)
                        _statusChip('offer: ${app['offer_status']}'),
                    ],
                  ),
                  if (app['status'] == 'rejected' &&
                      app['rejection_reason'] != null) ...[
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      'Rejected at ${app['rejection_stage'] ?? '-'}: ${app['rejection_reason']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.error),
                    ),
                  ],
                ],
              ),
            ),
            _statusChip(app['status']?.toString()),
            const Icon(Icons.chevron_right, color: AppTheme.lightGray),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final events = _recentEvents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Management Updates — Recent Activity', style: AppTheme.h5),
        const SizedBox(height: AppTheme.md),
        if (events.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text(
                  'No recruitment activity yet. Every step — shortlist, interview, selection, offer, joining — will appear here for management.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.mediumGray),
                ),
              ),
            ),
          )
        else
          GlassCard(
            child: Column(
              children: [
                for (var i = 0; i < events.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.teacherPrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _eventIcon(events[i]['event_type']?.toString()),
                          size: 16,
                          color: AppTheme.teacherPrimary,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              events[i]['title']?.toString() ?? 'Update',
                              style: AppTheme.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (events[i]['applicant_name'] != null)
                              Text(
                                events[i]['applicant_name'].toString(),
                                style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.mediumGray),
                              ),
                            if (events[i]['notes'] != null)
                              Text(
                                events[i]['notes'].toString(),
                                style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.mediumGray),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDateTime(events[i]['created_at']),
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.lightGray),
                      ),
                    ],
                  ),
                  if (i < events.length - 1)
                    const Divider(height: AppTheme.lg),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================
// APPLICANT DETAIL — rounds, decisions, offer, onboarding entry
// ============================================================
class _ApplicantDetailPage extends StatefulWidget {
  final Map<String, dynamic> application;
  final Map<String, dynamic> posting;
  final String username;
  const _ApplicantDetailPage({
    required this.application,
    required this.posting,
    required this.username,
  });

  @override
  State<_ApplicantDetailPage> createState() => _ApplicantDetailPageState();
}

class _ApplicantDetailPageState extends State<_ApplicantDetailPage> {
  final _service = TeacherLifecycleService();
  late Map<String, dynamic> _app;
  List<Map<String, dynamic>> _rounds = [];
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _offer;
  bool _isLoading = true;
  bool _isBusy = false;

  String get _appId => _app['id'].toString();
  String? get _by => widget.username.isEmpty ? null : widget.username;

  @override
  void initState() {
    super.initState();
    _app = Map<String, dynamic>.from(widget.application);
    _offer = widget.application['offer'] as Map<String, dynamic>?;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _isLoading = true);
    final pipeline =
        await _service.getPipeline(widget.posting['id'].toString());
    final rounds = await _service.getRounds(_appId);
    final offer = await _service.getOfferForApplication(_appId);
    final events = await _service.getEvents(applicationId: _appId, limit: 30);
    if (!mounted) return;
    final fresh = pipeline.where((a) => a['id'].toString() == _appId);
    setState(() {
      if (fresh.isNotEmpty) _app = fresh.first;
      _rounds = rounds;
      _offer = offer;
      _events = events;
      _isLoading = false;
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'selected':
      case 'offered':
      case 'joined':
      case 'accepted':
      case 'completed':
        return AppTheme.success;
      case 'shortlisted':
      case 'interview_scheduled':
      case 'issued':
      case 'scheduled':
        return AppTheme.info;
      case 'rejected':
      case 'declined':
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _statusChip(String? status) {
    final s = status ?? '-';
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

  Future<void> _runAction(
      Future<bool> Function() action, String successMsg) async {
    setState(() => _isBusy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);
    _showMessage(ok ? successMsg : 'Action failed', isError: !ok);
    if (ok) _reload();
  }

  // ---------------- Schedule Interview ----------------
  Future<void> _scheduleInterview() async {
    String roundType = 'panel';
    DateTime? date;
    TimeOfDay? time;
    final venueCtrl = TextEditingController();
    final panelCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Schedule Interview — Round ${_rounds.length + 1}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: roundType,
                  decoration: _fieldDecoration('Round Type'),
                  items: TeacherLifecycleService.roundTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.replaceAll('_', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => roundType = v ?? 'panel'),
                ),
                const SizedBox(height: AppTheme.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(date == null
                      ? 'Pick Date *'
                      : DateFormat('dd MMM yyyy').format(date!)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 2)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(time == null
                      ? 'Pick Time'
                      : time!.format(ctx)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (picked != null) setDialogState(() => time = picked);
                  },
                ),
                TextFormField(
                  controller: venueCtrl,
                  decoration:
                      _fieldDecoration('Venue', icon: Icons.place_outlined),
                ),
                const SizedBox(height: AppTheme.md),
                TextFormField(
                  controller: panelCtrl,
                  decoration: _fieldDecoration(
                      'Panel Members (comma separated)',
                      icon: Icons.groups_outlined),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teacherPrimary),
              onPressed: date == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child:
                  const Text('Schedule', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true && date != null) {
      final scheduledAt = DateTime(date!.year, date!.month, date!.day,
          time?.hour ?? 10, time?.minute ?? 0);
      final panel = panelCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() => _isBusy = true);
      final round = await _service.scheduleInterview(
        applicationId: _appId,
        roundType: roundType,
        scheduledAt: scheduledAt,
        venue: venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
        panelMembers: panel,
        createdBy: _by,
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showMessage(
          round != null ? 'Interview scheduled' : 'Failed to schedule',
          isError: round == null);
      if (round != null) _reload();
    }
    venueCtrl.dispose();
    panelCtrl.dispose();
  }

  // ---------------- Complete Interview ----------------
  Future<void> _completeInterview(Map<String, dynamic> round) async {
    final formKey = GlobalKey<FormState>();
    final marksCtrl = TextEditingController();
    final feedbackCtrl = TextEditingController();
    String recommendation = '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              'Complete Round ${round['round_no']} — ${(round['round_type'] ?? '').toString().replaceAll('_', ' ')}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: marksCtrl,
                    decoration:
                        _fieldDecoration('Marks', icon: Icons.score),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return double.tryParse(v.trim()) == null
                          ? 'Enter a valid number'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: feedbackCtrl,
                    decoration: _fieldDecoration('Feedback'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    value: recommendation,
                    decoration: _fieldDecoration('Recommendation'),
                    items: const [
                      DropdownMenuItem(
                          value: '', child: Text('Select (optional)')),
                      DropdownMenuItem(
                          value: 'strong_yes', child: Text('Strong Yes')),
                      DropdownMenuItem(value: 'yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'no', child: Text('No')),
                      DropdownMenuItem(
                          value: 'strong_no', child: Text('Strong No')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => recommendation = v ?? ''),
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
              child: const Text('Complete',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(
        () => _service.completeInterview(
          round['id'].toString(),
          marks: double.tryParse(marksCtrl.text.trim()),
          feedback:
              feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim(),
          recommendation: recommendation.isEmpty ? null : recommendation,
          by: _by,
        ),
        'Interview round completed',
      );
    }
    marksCtrl.dispose();
    feedbackCtrl.dispose();
  }

  // ---------------- Reject ----------------
  Future<void> _reject() async {
    final formKey = GlobalKey<FormState>();
    final reasonCtrl = TextEditingController();
    const stageOptions = [
      'applied',
      'shortlisted',
      'interview',
      'selection',
      'offer',
    ];
    String stage = switch (_app['status']?.toString()) {
      'interview_scheduled' => 'interview',
      'selected' => 'selection',
      'offered' => 'offer',
      'shortlisted' => 'shortlisted',
      _ => 'applied',
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reject Candidate'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The candidate stays in the rejected pool permanently with this stage and reason on record.',
                    style: TextStyle(color: AppTheme.mediumGray, fontSize: 13),
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    value: stage,
                    decoration: _fieldDecoration('Rejection Stage *'),
                    items: stageOptions
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => stage = v ?? stage),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: _fieldDecoration('Reason *'),
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Reason is required'
                        : null,
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
                  backgroundColor: AppTheme.error),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child:
                  const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(
        () => _service.rejectApplication(
          _appId,
          stage: stage,
          reason: reasonCtrl.text.trim(),
          by: _by,
        ),
        'Candidate rejected — kept in the rejected pool',
      );
    }
    reasonCtrl.dispose();
  }

  // ---------------- Issue Offer ----------------
  Future<void> _issueOffer() async {
    final formKey = GlobalKey<FormState>();
    final designationCtrl = TextEditingController();
    final deptCtrl = TextEditingController(
        text: widget.posting['department']?.toString() ?? '');
    final basicCtrl = TextEditingController();
    final hraCtrl = TextEditingController();
    final otherCtrl = TextEditingController();
    String employmentType = 'permanent';
    DateTime? joiningDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Issue Offer Letter'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: designationCtrl,
                    decoration: _fieldDecoration(
                        'Designation * (e.g. Assistant Professor)',
                        icon: Icons.badge_outlined),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Designation is required'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: deptCtrl,
                    decoration:
                        _fieldDecoration('Department *', icon: Icons.business),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Department is required'
                        : null,
                  ),
                  const SizedBox(height: AppTheme.md),
                  DropdownButtonFormField<String>(
                    value: employmentType,
                    decoration: _fieldDecoration('Employment Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'permanent', child: Text('Permanent')),
                      DropdownMenuItem(
                          value: 'contract', child: Text('Contract')),
                      DropdownMenuItem(
                          value: 'adjunct', child: Text('Adjunct')),
                      DropdownMenuItem(
                          value: 'visiting', child: Text('Visiting')),
                      DropdownMenuItem(value: 'guest', child: Text('Guest')),
                    ],
                    onChanged: (v) => setDialogState(
                        () => employmentType = v ?? 'permanent'),
                  ),
                  const SizedBox(height: AppTheme.md),
                  TextFormField(
                    controller: basicCtrl,
                    decoration: _fieldDecoration('Basic Salary (₹/month) *',
                        icon: Icons.payments_outlined),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter basic salary';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: hraCtrl,
                          decoration: _fieldDecoration('HRA (₹/month)'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.trim()) == null
                                ? 'Invalid'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: TextFormField(
                          controller: otherCtrl,
                          decoration: _fieldDecoration('Other Allow. (₹)'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.trim()) == null
                                ? 'Invalid'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(joiningDate == null
                        ? 'Joining Date'
                        : 'Joining: ${DateFormat('dd MMM yyyy').format(joiningDate!)}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 15)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => joiningDate = picked);
                      }
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
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Issue Offer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isBusy = true);
      final offer = await _service.issueOffer(
        applicationId: _appId,
        department: deptCtrl.text.trim(),
        designation: designationCtrl.text.trim(),
        employmentType: employmentType,
        basic: double.tryParse(basicCtrl.text.trim()) ?? 0,
        hra: double.tryParse(hraCtrl.text.trim()) ?? 0,
        other: double.tryParse(otherCtrl.text.trim()) ?? 0,
        joiningDate: joiningDate,
        by: _by,
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showMessage(offer != null ? 'Offer issued' : 'Failed to issue offer',
          isError: offer == null);
      if (offer != null) _reload();
    }
    designationCtrl.dispose();
    deptCtrl.dispose();
    basicCtrl.dispose();
    hraCtrl.dispose();
    otherCtrl.dispose();
  }

  // ---------------- Offer actions ----------------
  Future<void> _startOnboarding() async {
    if (_offer == null) return;
    setState(() => _isBusy = true);
    final onboarding = await _service.startOnboarding(_offer!);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (onboarding == null) {
      _showMessage('Failed to start onboarding', isError: true);
      return;
    }
    _showMessage(
        'Onboarding started — ${onboarding['employee_id']} (${onboarding['username']})');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EmployeeOnboardingScreen(username: widget.username),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final name = _app['applicant_name']?.toString() ?? 'Applicant';
    final status = _app['status']?.toString() ?? 'applied';
    final isRejected = status == 'rejected';
    final isJoined = status == 'joined';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppTheme.teacherPrimary,
        foregroundColor: Colors.white,
        title: const Text('Candidate Detail'),
        elevation: 0,
      ),
      body: _isLoading && _rounds.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.teacherPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(name, status),
                  if (isRejected) ...[
                    const SizedBox(height: AppTheme.md),
                    _buildRejectionCard(),
                  ],
                  const SizedBox(height: AppTheme.lg),
                  _buildActions(status, isRejected, isJoined),
                  const SizedBox(height: AppTheme.lg),
                  _buildRoundsSection(),
                  const SizedBox(height: AppTheme.lg),
                  _buildOfferSection(),
                  const SizedBox(height: AppTheme.lg),
                  _buildTimelineSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String name, String status) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.teacherPrimary.withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppTheme.teacherPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTheme.h5),
                    Text(
                      'Applied for ${widget.posting['title'] ?? ''}',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.mediumGray),
                    ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          _infoRow(Icons.school_outlined, 'Qualification',
              _app['qualification']?.toString() ?? '-'),
          _infoRow(Icons.timeline, 'Experience',
              '${_app['experience_years'] ?? 0} years'),
          _infoRow(Icons.email_outlined, 'Email',
              _app['email']?.toString() ?? '-'),
          _infoRow(Icons.phone_outlined, 'Phone',
              _app['phone']?.toString() ?? '-'),
          _infoRow(Icons.event_outlined, 'Applied On',
              _formatDate(_app['applied_at'])),
          if (_app['resume_url'] != null)
            _infoRow(Icons.link, 'Resume', _app['resume_url'].toString()),
          if (_app['remarks'] != null)
            _infoRow(Icons.note_outlined, 'Remarks',
                _app['remarks'].toString()),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.lightGray),
          const SizedBox(width: AppTheme.sm),
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray)),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildRejectionCard() {
    return GlassCard(
      color: AppTheme.error.withOpacity(0.05),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined, color: AppTheme.error),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rejected — on record',
                    style:
                        AppTheme.bodyLarge.copyWith(color: AppTheme.error)),
                const SizedBox(height: AppTheme.xs),
                Text(
                  'Stage: ${(_app['rejection_stage'] ?? '-').toString().replaceAll('_', ' ')}'
                  '\nReason: ${_app['rejection_reason'] ?? '-'}',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(String status, bool isRejected, bool isJoined) {
    if (isJoined) {
      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.celebration_outlined, color: AppTheme.success),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Text('This candidate has joined the institute.',
                  style: AppTheme.bodyMedium),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions', style: AppTheme.h5),
        const SizedBox(height: AppTheme.md),
        Wrap(
          spacing: AppTheme.sm,
          runSpacing: AppTheme.sm,
          children: [
            if (status == 'applied')
              GradientButton(
                text: 'Shortlist',
                icon: Icons.playlist_add_check,
                gradient: AppTheme.teacherGradient,
                height: 42,
                width: 140,
                isLoading: _isBusy,
                onPressed: () => _runAction(
                  () => _service.shortlistApplication(_appId, by: _by),
                  'Candidate shortlisted',
                ),
              ),
            if (!isRejected)
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _scheduleInterview,
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('Schedule Interview'),
              ),
            if (status == 'shortlisted' ||
                status == 'interview_scheduled')
              GradientButton(
                text: 'Select Candidate',
                icon: Icons.verified_outlined,
                gradient: AppTheme.teacherGradient,
                height: 42,
                width: 170,
                isLoading: _isBusy,
                onPressed: () => _runAction(
                  () => _service.selectApplication(_appId, by: _by),
                  'Candidate selected',
                ),
              ),
            if (status == 'selected' && _offer == null)
              GradientButton(
                text: 'Issue Offer',
                icon: Icons.mail_outline,
                gradient: AppTheme.teacherGradient,
                height: 42,
                width: 150,
                isLoading: _isBusy,
                onPressed: _issueOffer,
              ),
            if (!isRejected)
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _reject,
                icon: const Icon(Icons.cancel_outlined,
                    size: 18, color: AppTheme.error),
                label: const Text('Reject',
                    style: TextStyle(color: AppTheme.error)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Interview Rounds', style: AppTheme.h5)),
            if (_app['status'] != 'rejected' && _app['status'] != 'joined')
              TextButton.icon(
                onPressed: _isBusy ? null : _scheduleInterview,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        if (_rounds.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text('No interview rounds scheduled yet.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.mediumGray)),
              ),
            ),
          )
        else
          ..._rounds.map((round) {
            final panel = round['panel_members'];
            final panelText = panel is List
                ? panel.map((e) => e.toString()).join(', ')
                : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Round ${round['round_no']} — ${(round['round_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase()}',
                            style: AppTheme.bodyLarge,
                          ),
                        ),
                        _statusChip(round['status']?.toString()),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      _formatDateTime(round['scheduled_at']),
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.mediumGray),
                    ),
                    if (round['venue'] != null)
                      Text('Venue: ${round['venue']}',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.mediumGray)),
                    if (panelText.isNotEmpty)
                      Text('Panel: $panelText',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.mediumGray)),
                    if (round['status'] == 'completed') ...[
                      const Divider(height: AppTheme.lg),
                      if (round['marks'] != null)
                        Text('Marks: ${round['marks']}',
                            style: AppTheme.bodyMedium),
                      if (round['recommendation'] != null)
                        Text(
                            'Recommendation: ${round['recommendation'].toString().replaceAll('_', ' ')}',
                            style: AppTheme.bodyMedium),
                      if (round['feedback'] != null)
                        Text('Feedback: ${round['feedback']}',
                            style: AppTheme.bodySmall
                                .copyWith(color: AppTheme.mediumGray)),
                    ],
                    if (round['status'] == 'scheduled') ...[
                      const SizedBox(height: AppTheme.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed:
                              _isBusy ? null : () => _completeInterview(round),
                          icon: const Icon(Icons.check_circle_outline,
                              size: 18),
                          label: const Text('Complete Round'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildOfferSection() {
    if (_offer == null) return const SizedBox.shrink();
    final offer = _offer!;
    final gross = ((offer['basic_salary'] as num?)?.toDouble() ?? 0) +
        ((offer['hra'] as num?)?.toDouble() ?? 0) +
        ((offer['other_allowances'] as num?)?.toDouble() ?? 0);
    final fmt = NumberFormat('#,##0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Offer Letter', style: AppTheme.h5),
        const SizedBox(height: AppTheme.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${offer['designation'] ?? ''} • ${offer['department'] ?? ''}',
                      style: AppTheme.bodyLarge,
                    ),
                  ),
                  _statusChip(offer['status']?.toString()),
                ],
              ),
              const SizedBox(height: AppTheme.sm),
              Text(
                'Type: ${(offer['employment_type'] ?? '').toString()} • '
                'Offered: ${_formatDate(offer['offer_date'])} • '
                'Joining: ${_formatDate(offer['joining_date'])}',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
              const Divider(height: AppTheme.lg),
              _infoRow(Icons.payments_outlined, 'Basic',
                  '₹${fmt.format(offer['basic_salary'] ?? 0)}'),
              _infoRow(Icons.home_outlined, 'HRA',
                  '₹${fmt.format(offer['hra'] ?? 0)}'),
              _infoRow(Icons.add_circle_outline, 'Other Allowances',
                  '₹${fmt.format(offer['other_allowances'] ?? 0)}'),
              _infoRow(Icons.account_balance_wallet_outlined, 'Gross / month',
                  '₹${fmt.format(gross)}'),
              const SizedBox(height: AppTheme.sm),
              Wrap(
                spacing: AppTheme.sm,
                runSpacing: AppTheme.sm,
                children: [
                  if (offer['status'] == 'issued')
                    GradientButton(
                      text: 'Mark Accepted',
                      icon: Icons.thumb_up_outlined,
                      gradient: AppTheme.teacherGradient,
                      height: 42,
                      width: 165,
                      isLoading: _isBusy,
                      onPressed: () => _runAction(
                        () => _service.updateOfferStatus(
                            offer['id'].toString(), 'accepted', _appId,
                            by: _by),
                        'Offer marked accepted',
                      ),
                    ),
                  if (offer['status'] == 'issued' ||
                      offer['status'] == 'accepted')
                    OutlinedButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () => _runAction(
                                () => _service.updateOfferStatus(
                                    offer['id'].toString(), 'declined', _appId,
                                    by: _by),
                                'Offer marked declined',
                              ),
                      icon: const Icon(Icons.thumb_down_outlined, size: 18),
                      label: const Text('Mark Declined'),
                    ),
                  if (offer['status'] == 'accepted' ||
                      offer['status'] == 'issued')
                    GradientButton(
                      text: 'Start Onboarding',
                      icon: Icons.rocket_launch_outlined,
                      gradient: AppTheme.teacherGradient,
                      height: 42,
                      width: 180,
                      isLoading: _isBusy,
                      onPressed: _startOnboarding,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Candidate Timeline', style: AppTheme.h5),
        const SizedBox(height: AppTheme.md),
        if (_events.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Text('No timeline events yet.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.mediumGray)),
              ),
            ),
          )
        else
          GlassCard(
            child: Column(
              children: [
                for (var i = 0; i < _events.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fiber_manual_record,
                          size: 10, color: AppTheme.teacherPrimary),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_events[i]['title']?.toString() ?? 'Update',
                                style: AppTheme.bodyMedium
                                    .copyWith(fontWeight: FontWeight.w600)),
                            if (_events[i]['notes'] != null)
                              Text(_events[i]['notes'].toString(),
                                  style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.mediumGray)),
                          ],
                        ),
                      ),
                      Text(_formatDateTime(_events[i]['created_at']),
                          style: AppTheme.caption
                              .copyWith(color: AppTheme.lightGray)),
                    ],
                  ),
                  if (i < _events.length - 1) const Divider(height: AppTheme.lg),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
