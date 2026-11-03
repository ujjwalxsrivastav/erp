import 'package:flutter/material.dart';
import '../services/lead_service.dart';

/// SLA Alerts Widget - Shows Service Level Agreement violations
class SlaAlertsWidget extends StatefulWidget {
  final String? counsellorId;
  final bool compact;
  final VoidCallback? onTap;

  const SlaAlertsWidget({
    super.key,
    this.counsellorId,
    this.compact = false,
    this.onTap,
  });

  @override
  State<SlaAlertsWidget> createState() => _SlaAlertsWidgetState();
}

class _SlaAlertsWidgetState extends State<SlaAlertsWidget> {
  final LeadService _leadService = LeadService();
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _violations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  Future<void> _loadViolations() async {
    setState(() => _isLoading = true);

    final stats = await _leadService.getSlaStats();
    final violations = await _leadService.getSlaViolations(
      counsellorId: widget.counsellorId,
    );

    setState(() {
      _stats = stats;
      _violations = violations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_violations.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompactView();
    }

    return _buildExpandedView();
  }

  Widget _buildCompactView() {
    final criticalCount = _stats['critical'] ?? 0;
    final warningCount = _stats['warning'] ?? 0;
    final total = _stats['total'] ?? 0;

    if (total == 0) return const SizedBox.shrink();

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: criticalCount > 0
                ? [Colors.red.shade400, Colors.red.shade600]
                : [Colors.orange.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (criticalCount > 0 ? Colors.red : Colors.orange)
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SLA Alerts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$criticalCount critical, $warningCount warnings',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.red),
              const SizedBox(width: 8),
              const Text(
                'SLA Violations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadViolations,
              ),
            ],
          ),
        ),
        // Stats row
        _buildStatsRow(),
        const SizedBox(height: 16),
        // Violations list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _violations.length > 5 ? 5 : _violations.length,
          itemBuilder: (context, index) {
            return SlaViolationCard(violation: _violations[index]);
          },
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatBadge('Critical', _stats['critical'] ?? 0, Colors.red),
          const SizedBox(width: 12),
          _buildStatBadge('Warning', _stats['warning'] ?? 0, Colors.orange),
          const SizedBox(width: 12),
          _buildStatBadge('Stale', _stats['stale'] ?? 0, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single SLA Violation Card
class SlaViolationCard extends StatelessWidget {
  final Map<String, dynamic> violation;

  const SlaViolationCard({super.key, required this.violation});

  @override
  Widget build(BuildContext context) {
    final studentName = violation['student_name'] as String? ?? 'Unknown';
    final phone = violation['phone'] as String? ?? '';
    final course = violation['preferred_course'] as String? ?? '';
    final counsellorName = violation['counsellor_name'] as String?;
    final violationType = violation['violation_type'] as String? ?? '';
    final violationMessage = violation['violation_message'] as String? ?? '';
    final priority = violation['priority'] as String? ?? 'normal';

    final isCritical = violationType.startsWith('critical');
    final color = isCritical ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Severity indicator
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          studentName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (priority == 'high')
                        const Text('🔴', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Text(
                    '$phone • $course',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      violationMessage,
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ),
                  if (counsellorName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '👤 $counsellorName',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            // Action button
            IconButton(
              icon: Icon(Icons.phone, color: color),
              onPressed: () {
                // TODO: Make call
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// SLA Summary Banner - Shows at top of dashboard
class SlaSummaryBanner extends StatelessWidget {
  final int criticalCount;
  final int warningCount;
  final VoidCallback? onTap;

  const SlaSummaryBanner({
    super.key,
    required this.criticalCount,
    required this.warningCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (criticalCount == 0 && warningCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: criticalCount > 0
                ? [Colors.red.shade700, Colors.red.shade500]
                : [Colors.orange.shade700, Colors.orange.shade500],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (criticalCount > 0 ? Colors.red : Colors.orange)
                  .withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SLA Alerts Require Attention',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (criticalCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '🔴 $criticalCount Critical',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (warningCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '🟡 $warningCount Warnings',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
