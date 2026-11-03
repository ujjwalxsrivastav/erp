import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/examination_service.dart';

/// Student result view: published results grouped by session with
/// SGPA, and a revaluation application action per paper.
class StudentResultScreen extends StatefulWidget {
  final String studentId;

  const StudentResultScreen({super.key, required this.studentId});

  @override
  State<StudentResultScreen> createState() => _StudentResultScreenState();
}

class _StudentResultScreenState extends State<StudentResultScreen> {
  final _service = ExaminationService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _myRequests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await _service.getStudentResults(widget.studentId);
    final requests =
        await _service.getStudentRevaluationRequests(widget.studentId);
    if (mounted) {
      setState(() {
        _results = results;
        _myRequests = requests;
        _isLoading = false;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
    ));
  }

  /// result_id -> revaluation status, so a paper shows its state.
  String? _requestStatusFor(String resultId) {
    for (final r in _myRequests) {
      if (r['result_id']?.toString() == resultId) {
        return r['status']?.toString();
      }
    }
    return null;
  }

  Map<String, List<Map<String, dynamic>>> _groupBySession() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _results) {
      final key = r['session_name']?.toString().isNotEmpty == true
          ? r['session_name'].toString()
          : r['session_id'].toString();
      grouped.putIfAbsent(key, () => []).add(r);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupBySession();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.adminPrimary)),
                      )
                    else if (_results.isEmpty)
                      _emptyCard()
                    else
                      ...grouped.entries.map(
                          (e) => _buildSessionBlock(e.key, e.value)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _load,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.adminGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emoji_events,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('My Results',
                        style: AppTheme.h2.copyWith(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Only declared results are shown here',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 52, color: AppTheme.lightGray),
            const SizedBox(height: 14),
            Text('No declared results yet',
                style: AppTheme.h5.copyWith(color: AppTheme.dark)),
            const SizedBox(height: 8),
            Text(
              'Your results will appear here as soon as the examination cell publishes them.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionBlock(
      String sessionName, List<Map<String, dynamic>> results) {
    final sgpa = ExaminationService.computeSgpa(results);
    final backlogs = results.where((r) => r['status'] != 'pass').length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(sessionName,
                    style: AppTheme.h5.copyWith(color: AppTheme.dark)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.adminGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('SGPA ${sgpa.toStringAsFixed(2)}',
                    style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            backlogs == 0
                ? 'All papers clear in this session'
                : '$backlogs backlog paper(s) — contact the examination cell for the backlog form',
            style: AppTheme.caption.copyWith(
                color: backlogs == 0 ? AppTheme.success : AppTheme.error,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...results.map(_buildResultCard),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final passed = r['status'] == 'pass';
    final reqStatus = _requestStatusFor(r['id'].toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (passed ? AppTheme.success : AppTheme.error)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r['grade']?.toString() ?? '-',
                    style: AppTheme.bodyLarge.copyWith(
                      color: passed ? AppTheme.success : AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['subject_name']?.toString() ??
                            r['subject_id']?.toString() ??
                            'Subject',
                        style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.dark,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Internal ${r['internal_marks']} + External ${r['external_marks']}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${r['total']}',
                        style: AppTheme.h5.copyWith(color: AppTheme.dark)),
                    Text('GP ${r['grade_point']} • Cr ${r['credits']}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (passed ? AppTheme.success : AppTheme.error)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(passed ? 'PASS' : 'BACKLOG / FAIL',
                      style: AppTheme.caption.copyWith(
                          color: passed ? AppTheme.success : AppTheme.error,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                if (reqStatus != null)
                  Text(
                    'Revaluation: ${reqStatus.replaceAll('_', ' ')}',
                    style: AppTheme.caption.copyWith(
                        color: AppTheme.adminPrimary,
                        fontWeight: FontWeight.w600),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.rate_review, size: 16),
                    label: const Text('Apply Revaluation'),
                    onPressed: () => _applyRevaluation(r),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyRevaluation(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply for Revaluation'),
        content: Text(
          'Apply for re-checking of ${r['subject_name'] ?? r['subject_id']}? '
          'A revaluation fee of ₹500 will be charged as per institute rules. '
          'Your marks can increase, decrease or stay the same after re-checking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _service.applyRevaluation(
      resultId: r['id'].toString(),
      studentId: widget.studentId,
      subjectId: r['subject_id']?.toString(),
      subjectName: r['subject_name']?.toString(),
      originalMarks: (r['total'] as num?)?.toDouble(),
      feeAmount: 500,
    );
    if (ok) {
      _snack('Revaluation applied — the COE desk will process it');
      _load();
    } else {
      _snack('Could not apply for revaluation', error: true);
    }
  }
}
