import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/fee_insights_service.dart';

/// Finance — Fee Insights.
///
/// Tab 1: Defaulters — every student with an outstanding fee
/// balance (live from student_fee_allocations), with department
/// filter and per-student paid/total detail.
/// Tab 2: Collections — day-wise fee collection for the last
/// 30 days plus a payment-mode breakdown (live from fee_receipts).
class FeeInsightsScreen extends StatefulWidget {
  const FeeInsightsScreen({super.key});

  @override
  State<FeeInsightsScreen> createState() => _FeeInsightsScreenState();
}

class _FeeInsightsScreenState extends State<FeeInsightsScreen>
    with SingleTickerProviderStateMixin {
  final _service = FeeInsightsService();
  late final TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _defaulters = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _collections = {};
  String _deptFilter = 'All';
  String _search = '';

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _cardBg2 = Color(0xFF16213E);
  static const _primary = Color(0xFF6C5CE7);
  static const _accent = Color(0xFF00CEC9);
  static const _textSec = Color(0xFF9CA3AF);
  static const _border = Color(0xFF2D2D44);
  static const _danger = Color(0xFFEF4444);
  static const _ok = Color(0xFF00B894);

  final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getDefaulters(),
      _service.getCollectionSummary(days: 30),
    ]);
    if (!mounted) return;
    final defaulters = results[0] as List<Map<String, dynamic>>;
    // Summary derived from the same list the tab renders.
    double totalOutstanding = 0;
    double overdueAmount = 0;
    int overdueCount = 0;
    for (final d in defaulters) {
      final bal = (d['total_balance'] as num).toDouble();
      totalOutstanding += bal;
      if (d['overdue'] == true) {
        overdueCount++;
        overdueAmount += bal;
      }
    }
    setState(() {
      _defaulters = defaulters;
      _summary = {
        'totalOutstanding': totalOutstanding,
        'defaulterCount': defaulters.length,
        'overdueCount': overdueCount,
        'overdueAmount': overdueAmount,
      };
      _collections = results[1] as Map<String, dynamic>;
      _isLoading = false;
    });
  }

  List<String> get _departments {
    final set = <String>{};
    for (final d in _defaulters) {
      final dept = (d['department'] ?? '').toString();
      if (dept.isNotEmpty) set.add(dept);
    }
    return ['All', ...set.toList()..sort()];
  }

  List<Map<String, dynamic>> get _filteredDefaulters {
    return _defaulters.where((d) {
      if (_deptFilter != 'All' && d['department'] != _deptFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final name = (d['name'] ?? '').toString().toLowerCase();
        final id = (d['student_id'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !id.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/accountant-dashboard'),
        ),
        title: const Text(
          'Fee Insights',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: Colors.white,
          unselectedLabelColor: _textSec,
          tabs: const [
            Tab(icon: Icon(Icons.person_off_rounded, size: 18), text: 'Defaulters'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Collections'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : TabBarView(
              controller: _tabController,
              children: [_buildDefaultersTab(), _buildCollectionsTab()],
            ),
    );
  }

  // ----------------------------------------------------------------
  // DEFAULTERS TAB
  // ----------------------------------------------------------------
  Widget _buildDefaultersTab() {
    final list = _filteredDefaulters;
    return RefreshIndicator(
      color: _accent,
      backgroundColor: _cardBg,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(),
          const SizedBox(height: 16),
          _defaulterFilters(),
          const SizedBox(height: 12),
          if (list.isEmpty)
            _emptyState(
              Icons.check_circle_outline_rounded,
              _defaulters.isEmpty
                  ? 'No outstanding dues'
                  : 'No defaulters match the filters',
              _defaulters.isEmpty
                  ? 'Every student has cleared their fees.'
                  : 'Try another department or search term.',
            )
          else
            ...list.map(_defaulterCard),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_danger, _danger.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL OUTSTANDING',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _inr.format(_summary['totalOutstanding'] ?? 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryStat('Defaulters', '${_summary['defaulterCount'] ?? 0}'),
              _summaryDivider(),
              _summaryStat('Overdue', '${_summary['overdueCount'] ?? 0}'),
              _summaryDivider(),
              _summaryStat(
                'Overdue Amount',
                _inr.format(_summary['overdueAmount'] ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white24,
      );

  Widget _defaulterFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _search = v.trim()),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search name or student ID…',
            hintStyle: const TextStyle(color: _textSec),
            prefixIcon: const Icon(Icons.search_rounded, color: _textSec),
            filled: true,
            fillColor: _cardBg2,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _departments.map((dept) {
              final selected = _deptFilter == dept;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(dept),
                  selected: selected,
                  onSelected: (_) => setState(() => _deptFilter = dept),
                  backgroundColor: _cardBg,
                  selectedColor: _primary.withOpacity(0.25),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : _textSec,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: selected ? _primary : _border),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _defaulterCard(Map<String, dynamic> d) {
    final balance = (d['total_balance'] as num).toDouble();
    final paid = (d['total_paid'] as num).toDouble();
    final net = (d['total_net'] as num).toDouble();
    final overdue = d['overdue'] == true;
    final name = (d['name'] ?? d['student_id']).toString();
    final meta = [
      if (d['department'] != null) d['department'].toString(),
      if (d['year'] != null) 'Year ${d['year']}',
      if (d['semester'] != null) 'Sem ${d['semester']}',
      if (d['section'] != null) 'Sec ${d['section']}',
    ].join(' • ');
    final dueRaw = d['oldest_due_date']?.toString();
    final due = dueRaw == null ? null : DateTime.tryParse(dueRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: overdue ? _danger.withOpacity(0.5) : _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: _danger.withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: _danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  d['student_id'].toString(),
                  style: const TextStyle(color: _textSec, fontSize: 11),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: const TextStyle(color: _textSec, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _miniChip('${d['heads']} fee head${d['heads'] == 1 ? '' : 's'}'),
                    _miniChip('Paid ${_inr.format(paid)} / ${_inr.format(net)}'),
                    if (due != null)
                      _miniChip(
                        'Due ${DateFormat('dd MMM yyyy').format(due)}',
                        highlight: overdue,
                      ),
                    if (overdue) _miniChip('OVERDUE', highlight: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'BALANCE',
                style: TextStyle(
                  color: _textSec,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _inr.format(balance),
                style: const TextStyle(
                  color: _danger,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? _danger.withOpacity(0.15) : _cardBg2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlight ? _danger : _textSec,
          fontSize: 10,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // COLLECTIONS TAB
  // ----------------------------------------------------------------
  Widget _buildCollectionsTab() {
    final daily = List<Map<String, dynamic>>.from(
      _collections['daily'] as List? ?? [],
    );
    final modes = List<Map<String, dynamic>>.from(
      _collections['byMode'] as List? ?? [],
    );
    final total = (_collections['totalCollected'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _cardBg,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _collectionStat(
                'Last 30 Days',
                _inr.format(total),
                _accent,
              ),
              const SizedBox(width: 12),
              _collectionStat(
                'Today',
                _inr.format(
                    (_collections['todayCollection'] as num?)?.toDouble() ?? 0),
                _ok,
              ),
              const SizedBox(width: 12),
              _collectionStat(
                'Receipts',
                '${_collections['receiptCount'] ?? 0}',
                _primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (modes.isNotEmpty) ...[
            const Text(
              'By Payment Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: modes.map((m) {
                  final amount = (m['total'] as num).toDouble();
                  final pct = total > 0 ? amount / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_modeIcon(m['mode'].toString()),
                                color: _accent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _modeLabel(m['mode'].toString()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${m['count']} • ${_inr.format(amount)}',
                              style: const TextStyle(
                                color: _textSec,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: _cardBg2,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(_accent),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Day-wise Collection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (daily.isEmpty)
            _emptyState(
              Icons.receipt_long_outlined,
              'No collections in the last 30 days',
              'Completed receipts will appear here day by day.',
            )
          else
            ...daily.map((day) {
              final date = DateTime.tryParse(day['date'].toString());
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: _primary,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date == null
                                ? day['date'].toString()
                                : DateFormat('EEE, dd MMM yyyy').format(date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${day['count']} receipt${day['count'] == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: _textSec,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _inr.format((day['total'] as num).toDouble()),
                      style: const TextStyle(
                        color: _ok,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _collectionStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'upi':
        return Icons.qr_code_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'cheque':
      case 'dd':
        return Icons.receipt_rounded;
      case 'neft':
      case 'rtgs':
      case 'online':
        return Icons.account_balance_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'upi':
        return 'UPI';
      case 'neft':
        return 'NEFT';
      case 'rtgs':
        return 'RTGS';
      case 'dd':
        return 'Demand Draft';
      default:
        return mode.isEmpty
            ? mode
            : '${mode[0].toUpperCase()}${mode.substring(1)}';
    }
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 52, color: _textSec),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: _textSec, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
