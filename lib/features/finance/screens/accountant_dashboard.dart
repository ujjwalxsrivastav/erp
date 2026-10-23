import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_service.dart';
import '../services/finance_service.dart';

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});
  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> with TickerProviderStateMixin {
  final _authService = AuthService();
  final _financeService = FinanceService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _fadeController;
  String _accountantName = 'Accountant';
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _deptRevenue = [];
  int _selectedNavIndex = 0;

  static const _primary = Color(0xFF6C5CE7);
  static const _primaryDark = Color(0xFF5A4BD1);
  static const _accent = Color(0xFF00CEC9);
  static const _bg = Color(0xFF0F0E17);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _cardBg2 = Color(0xFF16213E);
  static const _textPrimary = Color(0xFFE4E4E7);
  static const _textSecondary = Color(0xFF9CA3AF);

  final _navItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
    {'icon': Icons.receipt_long_rounded, 'label': 'Fee Heads'},
    {'icon': Icons.people_rounded, 'label': 'Students'},
    {'icon': Icons.account_tree_rounded, 'label': 'Accounts'},
    {'icon': Icons.book_rounded, 'label': 'Journals'},
    {'icon': Icons.confirmation_number_rounded, 'label': 'Receipts'},
    {'icon': Icons.school_rounded, 'label': 'Scholarships'},
    {'icon': Icons.analytics_rounded, 'label': 'Reports'},
    {'icon': Icons.calendar_month_rounded, 'label': 'Fin. Year'},
    {'icon': Icons.shield_rounded, 'label': 'Audit Logs'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final username = await _authService.getCurrentUsername();
    final stats = await _financeService.getDashboardStats();
    final dept = await _financeService.getDepartmentRevenue();
    if (mounted) setState(() { _accountantName = username ?? 'Accountant'; _stats = stats; _deptRevenue = dept; _isLoading = false; });
  }

  @override
  void dispose() { _fadeController.dispose(); super.dispose(); }

  String _formatCurrency(dynamic v) {
    final n = (v is num) ? v.toDouble() : 0.0;
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)} Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(2)} L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  void _navigateToSection(int index) {
    final routes = [null, '/finance/fee-heads', '/finance/student-ledger', '/finance/chart-of-accounts',
      '/finance/journal-entries', '/finance/receipts', '/finance/scholarships',
      '/finance/reports', '/finance/financial-year', '/finance/audit-logs'];
    if (index == 0) { setState(() => _selectedNavIndex = 0); return; }
    if (index < routes.length && routes[index] != null) context.go(routes[index]!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      drawer: Drawer(
        backgroundColor: _cardBg,
        child: _buildSidebarContent(),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : FadeTransition(opacity: _fadeController, child: _buildMainContent()),
    );
  }

  Widget _buildSidebarContent() {
    return SafeArea(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _accent]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Finance ERP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
          ]),
        ),
        const Divider(color: Color(0xFF2D2D44), height: 1),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _navItems.length,
            itemBuilder: (ctx, i) {
              final sel = i == _selectedNavIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () { Navigator.pop(context); _navigateToSection(i); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: sel ? _primary.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: sel ? Border.all(color: _primary.withOpacity(0.3)) : null,
                      ),
                      child: Row(children: [
                        Icon(_navItems[i]['icon'] as IconData, size: 20, color: sel ? _primary : _textSecondary),
                        const SizedBox(width: 12),
                        Text(_navItems[i]['label'] as String, style: TextStyle(color: sel ? Colors.white : _textSecondary, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(color: Color(0xFF2D2D44), height: 1),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
          title: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          onTap: () async { await _authService.logout(); if (mounted) context.go('/login'); },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _buildTopBar()),
      SliverPadding(padding: const EdgeInsets.all(24), sliver: SliverList(delegate: SliverChildListDelegate([
        _buildKPIRow(),
        const SizedBox(height: 24),
        _buildChartsRow(),
        const SizedBox(height: 24),
        _buildBottomRow(),
      ]))),
    ]);
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        decoration: BoxDecoration(
          color: _cardBg,
          border: const Border(bottom: BorderSide(color: Color(0xFF2D2D44))),
        ),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome back, ${_accountantName.toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('Finance Dashboard • ${DateFormat('EEEE, MMM dd yyyy').format(DateTime.now())}', style: const TextStyle(color: _textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 12),
          _buildTopBarBtn(Icons.refresh_rounded, 'Refresh', _loadAll),
          const SizedBox(width: 10),
          _buildTopBarBtn(Icons.notifications_outlined, 'Alerts', () {}),
        ]),
      ),
    );
  }

  Widget _buildTopBarBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _cardBg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2D2D44))),
            child: Icon(icon, color: _textSecondary, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildKPIRow() {
    final kpis = [
      {'title': 'Total Collected', 'value': _formatCurrency(_stats['totalCollected']), 'icon': Icons.trending_up_rounded, 'color': const Color(0xFF00B894), 'sub': 'All time'},
      {'title': 'Pending Dues', 'value': _formatCurrency(_stats['pendingDues']), 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFFD79A8), 'sub': 'Outstanding'},
      {'title': 'Today\'s Collection', 'value': _formatCurrency(_stats['todayCollection']), 'icon': Icons.today_rounded, 'color': const Color(0xFF74B9FF), 'sub': DateFormat('dd MMM').format(DateTime.now())},
      {'title': 'Monthly Revenue', 'value': _formatCurrency(_stats['monthlyRevenue']), 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFFA29BFE), 'sub': DateFormat('MMMM yyyy').format(DateTime.now())},
      {'title': 'Scholarships', 'value': _formatCurrency(_stats['scholarshipTotal']), 'icon': Icons.school_rounded, 'color': const Color(0xFFFDCB6E), 'sub': 'Distributed'},
      {'title': 'Defaulters', 'value': '${_stats['defaultersCount'] ?? 0}', 'icon': Icons.person_off_rounded, 'color': const Color(0xFFE17055), 'sub': 'Overdue students'},
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = ((constraints.maxWidth - 32) / 3).clamp(180.0, 500.0);
      return Wrap(spacing: 16, runSpacing: 16, children: kpis.map((k) => SizedBox(
        width: cardWidth,
        child: _buildKPICard(k['title'] as String, k['value'] as String, k['icon'] as IconData, k['color'] as Color, k['sub'] as String),
      )).toList());
    });
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D44)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(sub, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          )),
        ]),
        const SizedBox(height: 16),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: _textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _buildChartsRow() {
    return Column(children: [
      _buildDeptRevenueChart(),
      const SizedBox(height: 16),
      _buildPaymentModeChart(),
    ]);
  }

  Widget _buildDeptRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2D2D44))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Department-wise Revenue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Collection vs Pending by department', style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 24),
        SizedBox(
          height: 250,
          child: _deptRevenue.isEmpty
            ? const Center(child: Text('No department data', style: TextStyle(color: _textSecondary)))
            : BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _deptRevenue.fold<double>(0, (m, d) { final c = (d['collected'] as num?)?.toDouble() ?? 0; final p = (d['pending'] as num?)?.toDouble() ?? 0; return (c + p) > m ? (c + p) : m; }) * 1.2,
                barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(tooltipRoundedRadius: 8)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                    if (v.toInt() >= _deptRevenue.length) return const SizedBox();
                    final name = (_deptRevenue[v.toInt()]['department'] as String?) ?? '';
                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(name.length > 8 ? '${name.substring(0, 8)}..' : name, style: const TextStyle(color: _textSecondary, fontSize: 10)));
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, m) => Text(_formatCurrency(v), style: const TextStyle(color: _textSecondary, fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFF2D2D44), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: _deptRevenue.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(toY: (e.value['collected'] as num?)?.toDouble() ?? 0, color: const Color(0xFF00B894), width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  BarChartRodData(toY: (e.value['pending'] as num?)?.toDouble() ?? 0, color: const Color(0xFFFD79A8), width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ])).toList(),
              )),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendDot(const Color(0xFF00B894), 'Collected'),
          const SizedBox(width: 20),
          _legendDot(const Color(0xFFFD79A8), 'Pending'),
        ]),
      ]),
    );
  }

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
  ]);

  Widget _buildPaymentModeChart() {
    final cash = (_stats['cashAmount'] as num?)?.toDouble() ?? 0;
    final online = (_stats['onlineAmount'] as num?)?.toDouble() ?? 0;
    final total = cash + online;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2D2D44))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payment Modes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: total == 0
            ? const Center(child: Text('No data', style: TextStyle(color: _textSecondary)))
            : PieChart(PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(value: cash, color: const Color(0xFF00B894), radius: 35, title: '${(cash / total * 100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  PieChartSectionData(value: online, color: const Color(0xFF74B9FF), radius: 35, title: '${(online / total * 100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              )),
        ),
        const SizedBox(height: 16),
        _paymentModeRow(const Color(0xFF00B894), 'Cash', _formatCurrency(cash), _stats['cashCount'] ?? 0),
        const SizedBox(height: 8),
        _paymentModeRow(const Color(0xFF74B9FF), 'Online / Digital', _formatCurrency(online), _stats['onlineCount'] ?? 0),
      ]),
    );
  }

  Widget _paymentModeRow(Color c, String label, String amount, int count) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12))),
    Text(amount, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    const SizedBox(width: 8),
    Text('($count)', style: const TextStyle(color: _textSecondary, fontSize: 11)),
  ]);

  Widget _buildBottomRow() {
    return Column(children: [
      _buildRecentTransactions(),
      const SizedBox(height: 16),
      _buildQuickActions(),
    ]);
  }

  Widget _buildRecentTransactions() {
    final txns = (_stats['recentTransactions'] as List<Map<String, dynamic>>?) ?? [];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2D2D44))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child:
          Text('Recent Transactions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => context.go('/finance/receipts'), child: const Text('View All', style: TextStyle(color: _primary, fontSize: 12))),
        ]),
        const SizedBox(height: 12),
        if (txns.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No recent transactions', style: TextStyle(color: _textSecondary))))
        else
          ...txns.take(6).map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF00B894).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['receipt_number'] ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(t['student_id'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ])),
              Text(_formatCurrency(t['total_amount']), style: const TextStyle(color: Color(0xFF00B894), fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          )),
      ]),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.add_card_rounded, 'label': 'New Receipt', 'color': const Color(0xFF00B894), 'route': '/finance/receipts'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Fee Heads', 'color': const Color(0xFF74B9FF), 'route': '/finance/fee-heads'},
      {'icon': Icons.book_rounded, 'label': 'Journal Entry', 'color': const Color(0xFFA29BFE), 'route': '/finance/journal-entries'},
      {'icon': Icons.analytics_rounded, 'label': 'Reports', 'color': const Color(0xFFFDCB6E), 'route': '/finance/reports'},
      {'icon': Icons.school_rounded, 'label': 'Scholarships', 'color': const Color(0xFFFD79A8), 'route': '/finance/scholarships'},
      {'icon': Icons.shield_rounded, 'label': 'Audit Trail', 'color': const Color(0xFFE17055), 'route': '/finance/audit-logs'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Budgets', 'color': const Color(0xFF00CEC9), 'route': '/finance/budgets'},
      {'icon': Icons.shopping_cart_rounded, 'label': 'Purchase (P2P)', 'color': const Color(0xFF6C5CE7), 'route': '/finance/purchase'},
      {'icon': Icons.science_rounded, 'label': 'Research Grants', 'color': const Color(0xFFFDCB6E), 'route': '/finance/grants'},
      {'icon': Icons.insights_rounded, 'label': 'Fee Insights', 'color': const Color(0xFFFD79A8), 'route': '/finance/fee-insights'},
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2D2D44))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go(a['route'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: (a['color'] as Color).withOpacity(0.15))),
                child: Row(children: [
                  Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
                  const SizedBox(width: 12),
                  Text(a['label'] as String, style: TextStyle(color: a['color'] as Color, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, color: (a['color'] as Color).withOpacity(0.5), size: 14),
                ]),
              ),
            ),
          ),
        )),
      ]),
    );
  }
}
