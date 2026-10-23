import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/examination_service.dart';

/// Tabulation register for a session: one row per student with
/// paper-wise grades and the computed SGPA.
class TabulationScreen extends StatefulWidget {
  const TabulationScreen({super.key});

  @override
  State<TabulationScreen> createState() => _TabulationScreenState();
}

class _TabulationScreenState extends State<TabulationScreen> {
  final _service = ExaminationService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _sheet = [];
  Map<String, dynamic>? _selectedSession;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final sessions = await _service.getSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSession(Map<String, dynamic> session) async {
    setState(() {
      _selectedSession = session;
      _isLoading = true;
    });
    final sheet = await _service.getTabulation(session['id'].toString());
    if (mounted) {
      setState(() {
        _sheet = sheet;
        _isLoading = false;
      });
    }
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
              if (_selectedSession != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedSession,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Exam Session'),
                    items: _sessions
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s['name']?.toString() ?? 'Session',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _selectSession(v);
                    },
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.adminPrimary))
                    : _selectedSession == null
                        ? _buildSessionPicker()
                        : _sheet.isEmpty
                            ? _emptyState(
                                'No results tabulated yet for this session. Enter results first, then the SGPA sheet appears here.')
                            : ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount: _sheet.length,
                                itemBuilder: (context, i) =>
                                    _buildStudentRow(_sheet[i]),
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
                Text('Tabulation Register',
                    style: AppTheme.h4.copyWith(color: Colors.white)),
                Text(
                  'Student-wise SGPA = sum(credits x grade point) / sum(credits)',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPicker() {
    if (_sessions.isEmpty) {
      return _emptyState('No sessions found. Create an exam session first.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _sessions.length,
      itemBuilder: (context, i) {
        final s = _sessions[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            onTap: () => _selectSession(s),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart,
                      color: AppTheme.adminPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s['name']?.toString() ?? 'Session',
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.dark, fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: AppTheme.lightGray),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> row) {
    final results =
        (row['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sgpa = (row['sgpa'] as num?)?.toDouble() ?? 0;
    final backlogs = row['backlogs'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.adminPrimary.withOpacity(0.12),
                  child: const Icon(Icons.person,
                      color: AppTheme.adminPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['name']} (${row['student_id']})',
                          style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.dark,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${row['department']} • Sec ${row['section']} • Credits ${row['total_credits']}',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.mediumGray),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('SGPA ${sgpa.toStringAsFixed(2)}',
                      style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.adminDark,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: results.map((r) {
                final passed = r['status'] == 'pass';
                return Chip(
                  backgroundColor:
                      (passed ? AppTheme.success : AppTheme.error)
                          .withOpacity(0.1),
                  label: Text(
                    '${r['subject_name'] ?? r['subject_id']}: ${r['total']} (${r['grade']})',
                    style: AppTheme.caption.copyWith(
                        color: passed ? AppTheme.success : AppTheme.error,
                        fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              backlogs == 0
                  ? 'All papers clear'
                  : '$backlogs backlog paper(s)',
              style: AppTheme.caption.copyWith(
                  color: backlogs == 0 ? AppTheme.success : AppTheme.error,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart_outlined,
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
