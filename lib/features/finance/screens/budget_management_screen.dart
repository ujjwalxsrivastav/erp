import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/finance_extension_service.dart';

/// Budget Management — department budgets from `department_budgets`
/// (migration 27) enriched with utilization computed by
/// FinanceExtensionService.getBudgetUtilization().
/// Utilization alert colours: >90% red, >75% orange, else green/teal.
class BudgetManagementScreen extends StatefulWidget {
  const BudgetManagementScreen({super.key});

  @override
  State<BudgetManagementScreen> createState() => _BudgetManagementScreenState();
}

class _BudgetManagementScreenState extends State<BudgetManagementScreen> {
  final _service = FinanceExtensionService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _budgets = [];

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _accent = Color(0xFF00CEC9);
  static const _textSec = Color(0xFF9CA3AF);
  static const _border = Color(0xFF2D2D44);
  static const _ok = Color(0xFF00B894);
  static const _warn = Color(0xFFF59E0B);
  static const _danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final budgets = await _service.getBudgetUtilization();
    if (mounted) {
      setState(() {
        _budgets = budgets;
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic v) {
    final n = (v is num) ? v.toDouble() : 0.0;
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)} Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(2)} L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  Color _alertColor(double pct) {
    if (pct > 90) return _danger;
    if (pct > 75) return _warn;
    return _ok;
  }

  String _alertLabel(double pct) {
    if (pct > 90) return 'CRITICAL — budget almost exhausted';
    if (pct > 75) return 'Warning — utilization above 75%';
    return 'Healthy';
  }

  @override
  Widget build(BuildContext context) {
    double totalAllocated = 0, totalUtilized = 0, totalBalance = 0;
    for (var b in _budgets) {
      totalAllocated += (b['allocated'] as num?)?.toDouble() ?? 0;
      totalUtilized += (b['utilized'] as num?)?.toDouble() ?? 0;
      totalBalance += (b['balance'] as num?)?.toDouble() ?? 0;
    }
    final overallPct =
        totalAllocated > 0 ? (totalUtilized / totalAllocated) * 100 : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Budget Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/accountant-dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _budgets.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCard(totalAllocated, totalUtilized,
                          totalBalance, overallPct),
                      const SizedBox(height: 16),
                      const Text('Department Budgets',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text(
                          'Balance = Allocated − Utilized − Committed (open POs)',
                          style: TextStyle(color: _textSec, fontSize: 12)),
                      const SizedBox(height: 12),
                      ..._budgets.map(_buildBudgetCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: _primary, size: 44),
            ),
            const SizedBox(height: 16),
            const Text('No department budgets found',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Budgets are created in the department_budgets table.\nRun the finance SQL migrations if this is a fresh setup.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSec, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      double allocated, double utilized, double balance, double pct) {
    return GlassCard(
      color: _cardBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.pie_chart_rounded, color: _accent, size: 20),
            SizedBox(width: 8),
            Text('Institute Budget Overview',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _summaryItem('Allocated', allocated, Colors.white)),
            Expanded(child: _summaryItem('Utilized', utilized, _accent)),
            Expanded(
                child: _summaryItem('Balance', balance,
                    balance < 0 ? _danger : _ok)),
          ]),
          const SizedBox(height: 16),
          _buildProgressBar(pct),
          const SizedBox(height: 6),
          Text('${pct.toStringAsFixed(1)}% utilized overall',
              style: TextStyle(color: _alertColor(pct), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatCurrency(value),
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSec, fontSize: 12)),
      ],
    );
  }

  Widget _buildProgressBar(double pct) {
    final clamped = pct.clamp(0, 100).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: clamped / 100,
        minHeight: 10,
        backgroundColor: _border,
        valueColor: AlwaysStoppedAnimation<Color>(_alertColor(pct)),
      ),
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> b) {
    final pct = (b['utilizationPct'] as num?)?.toDouble() ?? 0;
    final color = _alertColor(pct);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        color: _cardBg,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.domain_rounded,
                    color: _primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((b['department'] as String?) ?? 'Department',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text('Status: ${(b['status'] as String?) ?? 'active'}',
                        style:
                            const TextStyle(color: _textSec, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            _buildProgressBar(pct),
            const SizedBox(height: 6),
            Text(_alertLabel(pct),
                style: TextStyle(color: color, fontSize: 11)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _miniStat('Allocated', b['allocated'])),
              Expanded(child: _miniStat('Utilized', b['utilized'])),
              Expanded(child: _miniStat('Committed', b['committed'])),
              Expanded(child: _miniStat('Balance', b['balance'])),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatCurrency(value),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(color: _textSec, fontSize: 11)),
      ],
    );
  }
}
