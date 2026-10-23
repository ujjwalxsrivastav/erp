import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/examination_service.dart';

/// COE desk for student revaluation / re-checking requests.
/// Processing with revised marks updates the linked result row
/// and recomputes its grade inside ExaminationService.
class RevaluationScreen extends StatefulWidget {
  const RevaluationScreen({super.key});

  @override
  State<RevaluationScreen> createState() => _RevaluationScreenState();
}

class _RevaluationScreenState extends State<RevaluationScreen> {
  final _service = ExaminationService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final requests = await _service.getRevaluationRequests(
        status: _filter == 'all' ? null : _filter);
    if (mounted) {
      setState(() {
        _requests = requests;
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

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All'),
                      const SizedBox(width: 8),
                      _filterChip('pending', 'Pending'),
                      const SizedBox(width: 8),
                      _filterChip('under_review', 'Under Review'),
                      const SizedBox(width: 8),
                      _filterChip('completed', 'Completed'),
                      const SizedBox(width: 8),
                      _filterChip('rejected', 'Rejected'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.adminPrimary))
                    : _requests.isEmpty
                        ? _emptyState(
                            'No revaluation requests in this queue. Student applications against published results appear here.')
                        : RefreshIndicator(
                            color: AppTheme.adminPrimary,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: _requests.length,
                              itemBuilder: (context, i) =>
                                  _buildRequestCard(_requests[i]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.adminGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Revaluation Desk',
                    style: AppTheme.h4.copyWith(color: Colors.white)),
                Text(
                  '${_requests.length} request(s) • revised marks update the result directly',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.adminPrimary.withOpacity(0.2),
      onSelected: (_) {
        setState(() => _filter = value);
        _load();
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'pending';
    Color color;
    switch (status) {
      case 'completed':
        color = AppTheme.success;
        break;
      case 'rejected':
        color = AppTheme.error;
        break;
      case 'under_review':
        color = AppTheme.info;
        break;
      default:
        color = AppTheme.warning;
    }
    final canProcess = status == 'pending' || status == 'under_review';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.rate_review,
                      color: AppTheme.accentPink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['subject_name'] ?? r['subject_id'] ?? 'Subject'}',
                        style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.dark,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Student: ${r['student_id']} • Applied: ${(r['applied_at'] ?? '').toString().split('T').first}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: AppTheme.caption.copyWith(
                        color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _marksBox('Original', r['original_marks']),
                const SizedBox(width: 12),
                _marksBox('Revised', r['revised_marks']),
                const SizedBox(width: 12),
                _marksBox('Fee (₹)', r['fee_amount']),
              ],
            ),
            if (r['processed_by'] != null) ...[
              const SizedBox(height: 8),
              Text('Processed by ${r['processed_by']}',
                  style:
                      AppTheme.caption.copyWith(color: AppTheme.mediumGray)),
            ],
            if (canProcess) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Complete with Revised Marks'),
                      onPressed: () => _showProcessDialog(r),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error),
                    onPressed: () async {
                      final ok = await _service.processRevaluation(
                          r['id'].toString(),
                          approve: false);
                      if (ok) {
                        _snack('Request rejected');
                        _load();
                      } else {
                        _snack('Could not reject request', error: true);
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _marksBox(String label, dynamic value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value == null ? '-' : value.toString(),
                style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.dark, fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    AppTheme.caption.copyWith(color: AppTheme.mediumGray)),
          ],
        ),
      ),
    );
  }

  Future<void> _showProcessDialog(Map<String, dynamic> r) async {
    final formKey = GlobalKey<FormState>();
    final marksCtrl = TextEditingController(
        text: r['original_marks']?.toString() ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Revaluation'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the revised TOTAL marks for ${r['subject_name'] ?? r['subject_id']} after re-checking. The result, grade and grade point will be updated automatically.',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.mediumGray),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: marksCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Revised Total Marks *'),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null) return 'Enter a number';
                    if (n < 0) return 'Marks cannot be negative';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final ok = await _service.processRevaluation(
                  r['id'].toString(),
                  approve: true,
                  revisedMarks: double.tryParse(marksCtrl.text),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (ok) {
                  _snack('Revaluation completed — result updated');
                  _load();
                } else {
                  _snack('Could not process revaluation', error: true);
                }
              },
              child: const Text('Update Result'),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined,
                size: 56, color: AppTheme.lightGray),
            const SizedBox(height: 14),
            Text(msg,
                textAlign: TextAlign.center,
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray)),
          ],
        ),
      ),
    );
  }
}
