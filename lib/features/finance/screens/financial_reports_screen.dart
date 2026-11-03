import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/finance_service.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});
  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final _service = FinanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic> _stats = {};
  String _selectedReport = 'trial_balance';

  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6C5CE7);
  static const _textSec = Color(0xFF9CA3AF);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _accounts = await _service.getChartOfAccounts();
    _stats = await _service.getDashboardStats();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _cardBg, foregroundColor: Colors.white, elevation: 0, title: const Text('Financial Reports', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/accountant-dashboard'))),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: _primary)) : Row(children: [
        // Report selector sidebar
        Container(
          width: 220,
          decoration: const BoxDecoration(color: _cardBg, border: Border(right: BorderSide(color: Color(0xFF2D2D44)))),
          child: Column(children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Reports', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
            _reportItem('Trial Balance', 'trial_balance', Icons.balance_rounded),
            _reportItem('Balance Sheet', 'balance_sheet', Icons.account_balance_rounded),
            _reportItem('Income Statement', 'income_statement', Icons.trending_up_rounded),
            _reportItem('Cash Flow', 'cash_flow', Icons.water_drop_rounded),
            _reportItem('Collection Report', 'collection', Icons.receipt_long_rounded),
            _reportItem('Dept. Revenue', 'dept_revenue', Icons.business_rounded),
            _reportItem('Defaulter Report', 'defaulters', Icons.person_off_rounded),
          ]),
        ),
        Expanded(child: _buildReportContent()),
      ]),
    );
  }

  Widget _reportItem(String label, String key, IconData icon) {
    final sel = _selectedReport == key;
    return InkWell(
      onTap: () => setState(() => _selectedReport = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: sel ? _primary.withOpacity(0.15) : Colors.transparent, border: Border(left: BorderSide(color: sel ? _primary : Colors.transparent, width: 3))),
        child: Row(children: [
          Icon(icon, size: 18, color: sel ? _primary : _textSec),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: sel ? Colors.white : _textSec, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_selectedReport) {
      case 'trial_balance': return _buildTrialBalance();
      case 'balance_sheet': return _buildBalanceSheet();
      case 'income_statement': return _buildIncomeStatement();
      case 'collection': return _buildCollectionReport();
      default: return _buildTrialBalance();
    }
  }

  Widget _buildTrialBalance() {
    double totalDebit = 0, totalCredit = 0;
    for (var a in _accounts) {
      final bal = (a['current_balance'] as num?)?.toDouble() ?? 0;
      if (a['normal_balance'] == 'debit') totalDebit += bal.abs();
      else totalCredit += bal.abs();
    }

    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Trial Balance', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (totalDebit - totalCredit).abs() < 0.01 ? const Color(0xFF00B894).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text((totalDebit - totalCredit).abs() < 0.01 ? '✓ BALANCED' : '✗ UNBALANCED', style: TextStyle(color: (totalDebit - totalCredit).abs() < 0.01 ? const Color(0xFF00B894) : const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 20),
      Expanded(child: Container(
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2D2D44))),
        child: SingleChildScrollView(child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF16213E)),
          columns: const [
            DataColumn(label: Text('Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Debit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), numeric: true),
            DataColumn(label: Text('Credit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), numeric: true),
          ],
          rows: [
            ..._accounts.map((a) {
              final bal = (a['current_balance'] as num?)?.toDouble() ?? 0;
              final isDebit = a['normal_balance'] == 'debit';
              return DataRow(cells: [
                DataCell(Text(a['account_code'] ?? '', style: const TextStyle(color: _textSec, fontSize: 12))),
                DataCell(Text(a['account_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                DataCell(Text((a['account_type'] ?? '').toString().toUpperCase(), style: const TextStyle(color: _textSec, fontSize: 10))),
                DataCell(Text(isDebit ? '₹${bal.abs().toStringAsFixed(2)}' : '', style: const TextStyle(color: Color(0xFF00B894), fontSize: 12))),
                DataCell(Text(!isDebit ? '₹${bal.abs().toStringAsFixed(2)}' : '', style: const TextStyle(color: Color(0xFFFD79A8), fontSize: 12))),
              ]);
            }),
            DataRow(color: WidgetStateProperty.all(const Color(0xFF16213E)), cells: [
              const DataCell(Text('')),
              const DataCell(Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              const DataCell(Text('')),
              DataCell(Text('₹${totalDebit.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.w800))),
              DataCell(Text('₹${totalCredit.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFD79A8), fontWeight: FontWeight.w800))),
            ]),
          ],
        )),
      )),
    ]));
  }

  Widget _buildBalanceSheet() {
    final assets = _accounts.where((a) => a['account_type'] == 'asset').toList();
    final liabilities = _accounts.where((a) => a['account_type'] == 'liability').toList();
    final equity = _accounts.where((a) => a['account_type'] == 'equity').toList();
    double totalAssets = assets.fold(0.0, (s, a) => s + ((a['current_balance'] as num?)?.toDouble() ?? 0));
    double totalLiabilities = liabilities.fold(0.0, (s, a) => s + ((a['current_balance'] as num?)?.toDouble() ?? 0));
    double totalEquity = equity.fold(0.0, (s, a) => s + ((a['current_balance'] as num?)?.toDouble() ?? 0));

    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Balance Sheet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _bsSection('ASSETS', assets, totalAssets, const Color(0xFF00B894))),
        const SizedBox(width: 16),
        Expanded(child: Column(children: [
          Expanded(child: _bsSection('LIABILITIES', liabilities, totalLiabilities, const Color(0xFFFD79A8))),
          const SizedBox(height: 16),
          Expanded(child: _bsSection('EQUITY', equity, totalEquity, const Color(0xFFA29BFE))),
        ])),
      ])),
    ]));
  }

  Widget _bsSection(String title, List<Map<String, dynamic>> items, double total, Color c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 12),
      ...items.map((a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Expanded(child: Text(a['account_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
        Text('₹${((a['current_balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
      ]))),
      const Divider(color: Color(0xFF2D2D44)),
      Row(children: [
        const Expanded(child: Text('TOTAL', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
        Text('₹${total.toStringAsFixed(2)}', style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    ]),
  );

  Widget _buildIncomeStatement() {
    final revenue = _accounts.where((a) => a['account_type'] == 'revenue').toList();
    final expenses = _accounts.where((a) => a['account_type'] == 'expense').toList();
    double totalRev = revenue.fold(0.0, (s, a) => s + ((a['current_balance'] as num?)?.toDouble() ?? 0));
    double totalExp = expenses.fold(0.0, (s, a) => s + ((a['current_balance'] as num?)?.toDouble() ?? 0));
    double netIncome = totalRev - totalExp;

    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Income Statement', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [netIncome >= 0 ? const Color(0xFF00B894) : const Color(0xFFEF4444), netIncome >= 0 ? const Color(0xFF00B894).withOpacity(0.7) : const Color(0xFFEF4444).withOpacity(0.7)]), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(netIncome >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(netIncome >= 0 ? 'NET SURPLUS' : 'NET DEFICIT', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('₹${netIncome.abs().toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _bsSection('REVENUE', revenue, totalRev, const Color(0xFF00B894))),
        const SizedBox(width: 16),
        Expanded(child: _bsSection('EXPENSES', expenses, totalExp, const Color(0xFFE17055))),
      ])),
    ]));
  }

  Widget _buildCollectionReport() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Collection Report', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      Row(children: [
        _crCard('Total Collected', _stats['totalCollected'] ?? 0, const Color(0xFF00B894)),
        const SizedBox(width: 12),
        _crCard('Today', _stats['todayCollection'] ?? 0, const Color(0xFF74B9FF)),
        const SizedBox(width: 12),
        _crCard('This Month', _stats['monthlyRevenue'] ?? 0, const Color(0xFFA29BFE)),
        const SizedBox(width: 12),
        _crCard('Pending', _stats['pendingDues'] ?? 0, const Color(0xFFFD79A8)),
      ]),
      const SizedBox(height: 20),
      Expanded(child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2D2D44))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Collection Trend', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Expanded(child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFF2D2D44), strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][v.toInt() % 12], style: const TextStyle(color: _textSec, fontSize: 10)))),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [LineChartBarData(spots: List.generate(12, (i) => FlSpot(i.toDouble(), (50000 + (i * 12000) + (i % 3 * 8000)).toDouble())), isCurved: true, color: _primary, barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: _primary.withOpacity(0.1)))],
          ))),
        ]),
      )),
    ]));
  }

  Widget _crCard(String label, dynamic value, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('₹${((value is num ? value.toDouble() : 0.0)).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    ]),
  ));
}
