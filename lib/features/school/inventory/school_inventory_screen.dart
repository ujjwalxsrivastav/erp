import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_inventory_service.dart';
import '../../../services/school_export_service.dart';

class SchoolInventoryScreen extends StatefulWidget {
  const SchoolInventoryScreen({super.key});

  @override
  State<SchoolInventoryScreen> createState() => _SchoolInventoryScreenState();
}

class _SchoolInventoryScreenState extends State<SchoolInventoryScreen> with SingleTickerProviderStateMixin {
  final SchoolInventoryService _inventoryService = SchoolInventoryService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _maintenance = [];
  List<Map<String, dynamic>> _audits = [];

  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _categories = [
    'All',
    'Lab Equipment',
    'IT & Computing',
    'Furniture',
    'Sports Goods',
    'Classroom Supplies',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _inventoryService.getInventoryItems(
        category: _selectedCategory,
        search: _searchQuery,
      );
      final issues = await _inventoryService.getInventoryIssues();
      final maintenance = await _inventoryService.getMaintenanceLogs();
      final audits = await _inventoryService.getAuditLogs();

      if (mounted) {
        setState(() {
          _items = items;
          _issues = issues;
          _maintenance = maintenance;
          _audits = audits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load inventory assets: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8FAFC);
    const ink = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory & Asset Accounting',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Fixed Assets, 10% Depreciation, Loans & Physical Audit',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Excel (SP-R07)',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Add New Asset',
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
            onPressed: _showAddItemModal,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Assets & Stock', icon: Icon(Icons.inventory_2_outlined, size: 20)),
            Tab(text: 'Issue & Return Desk', icon: Icon(Icons.assignment_return_outlined, size: 20)),
            Tab(text: 'Maintenance & Audit', icon: Icon(Icons.fact_check_outlined, size: 20)),
          ],
        ),
      ),
      body: _buildBody(ink),
    );
  }

  Widget _buildBody(Color ink) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text('Evaluating asset depreciation and stock ledgers...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildKpiBanner(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStockTab(),
              _buildIssuesTab(),
              _buildMaintenanceAndAuditTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TOP KPI BANNER
  // ==========================================

  Widget _buildKpiBanner() {
    double totalOriginal = 0.0;
    double totalDepreciated = 0.0;
    int totalUnits = 0;
    int lowStockCount = 0;

    for (final it in _items) {
      totalOriginal += (it['total_original_cost'] as num?)?.toDouble() ?? 0.0;
      totalDepreciated += (it['total_depreciated_value'] as num?)?.toDouble() ?? 0.0;
      totalUnits += (it['quantity'] as num?)?.toInt() ?? 0;
      if (it['is_low_stock'] == true) lowStockCount++;
    }

    final activeLoans = _issues.where((i) => i['status'] == 'Issued').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _kpiTile(
                title: 'Book Valuation',
                value: '₹${(totalDepreciated / 100000).toStringAsFixed(2)} Lakh',
                subtitle: 'Orig: ₹${(totalOriginal / 100000).toStringAsFixed(2)}L (10% Dep)',
                color: const Color(0xFF2563EB),
                icon: Icons.account_balance_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Stocked Units',
                value: '$totalUnits Units',
                subtitle: '${_items.length} Asset Catalogues',
                color: const Color(0xFF059669),
                icon: Icons.inventory_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Active Loans',
                value: '$activeLoans On Loan',
                subtitle: 'Issued to Staff/Students',
                color: const Color(0xFF7C3AED),
                icon: Icons.output_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Low Stock Alert',
                value: '$lowStockCount Critical',
                subtitle: 'At or Below Threshold',
                color: lowStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF059669),
                icon: Icons.warning_amber_rounded,
                isNarrow: isNarrow,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isNarrow,
  }) {
    return Container(
      width: isNarrow ? double.infinity : 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ASSETS & STOCK INVENTORY
  // ==========================================

  Widget _buildStockTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search & Add Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search asset name, code, room, or category...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                            _loadData();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onSubmitted: (val) {
                  setState(() => _searchQuery = val.trim());
                  _loadData();
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showAddItemModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Asset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat);
                    _loadData();
                  },
                  selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Category Valuation Chart
        _buildCategoryValuationChart(),
        const SizedBox(height: 16),

        // Asset Cards List
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inventory_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text('No assets found matching your filter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                SizedBox(height: 4),
                Text('Try clearing the search query or changing category.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          )
        else
          ..._items.map((it) => _assetItemCard(it)),
      ],
    );
  }

  Widget _buildCategoryValuationChart() {
    final catTotals = <String, double>{};
    for (final it in _items) {
      final cat = it['category']?.toString() ?? 'Other';
      catTotals[cat] = (catTotals[cat] ?? 0.0) + ((it['total_depreciated_value'] as num?)?.toDouble() ?? 0.0);
    }
    final sortedCats = catTotals.keys.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Depreciated Asset Book Value by Category (₹)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text('fl_chart SP-R07', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 2000000,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) => Text('₹${(val / 100000).toStringAsFixed(0)}L', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < sortedCats.length) {
                          final shortName = sortedCats[idx].split(' ')[0];
                          return Text(shortName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: sortedCats.asMap().entries.map((e) {
                  final val = catTotals[e.value] ?? 0.0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: const Color(0xFF0F172A),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetItemCard(Map<String, dynamic> it) {
    final isLowStock = it['is_low_stock'] == true;
    final qty = it['quantity'] ?? 1;
    final unit = it['unit'] ?? 'Units';
    final origCost = (it['total_original_cost'] as num?)?.toDouble() ?? 0.0;
    final depValue = (it['total_depreciated_value'] as num?)?.toDouble() ?? 0.0;
    final condition = it['condition']?.toString() ?? 'Good';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLowStock ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(it['item_code']?.toString() ?? 'CODE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(it['category']?.toString() ?? 'Category', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                        ),
                        if (isLowStock) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('LOW STOCK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      it['name']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.room_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(it['location_room']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(width: 12),
                        const Icon(Icons.verified_outlined, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text('Condition: $condition', style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$qty $unit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text('In Store', style: TextStyle(fontSize: 10, color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book Value: ₹${depValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                  Text('Original: ₹${origCost.toStringAsFixed(0)} (${it['age_years']} yrs age)', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showScheduleMaintenanceModal(it),
                    icon: const Icon(Icons.build_outlined, size: 12),
                    label: const Text('Maintenance', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showIssueItemModal(it),
                    icon: const Icon(Icons.outbox_outlined, size: 12),
                    label: const Text('Issue Asset', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: ISSUE & RETURN DESK
  // ==========================================

  Widget _buildIssuesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Asset Loans & Active Custody Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_issues.length} Issues', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        ..._issues.map((iss) => _issueCard(iss)),
      ],
    );
  }

  Widget _issueCard(Map<String, dynamic> iss) {
    final status = iss['status']?.toString() ?? 'Issued';
    final isReturned = status == 'Returned';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(iss['item_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReturned ? const Color(0xFF059669).withValues(alpha: 0.1) : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isReturned ? const Color(0xFF059669) : const Color(0xFFD97706)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Issued to: ${iss['issued_to_name']} (${iss['issued_to_role']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(width: 10),
              Text('Qty: ${iss['issued_quantity']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Purpose: ${iss['purpose'] ?? 'Demonstration'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Due: ${(iss['expected_return_date']?.toString() ?? '').split('T')[0]}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              if (!isReturned)
                ElevatedButton.icon(
                  onPressed: () => _showReturnItemModal(iss),
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 12),
                  label: const Text('Accept Return'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: MAINTENANCE & PHYSICAL AUDIT
  // ==========================================

  Widget _buildMaintenanceAndAuditTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Maintenance & Servicing Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_maintenance.length} Logs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        ..._maintenance.map((m) => _maintenanceCard(m)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Annual Physical Audit Reconciliation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ElevatedButton.icon(
              onPressed: _showConductAuditModal,
              icon: const Icon(Icons.fact_check_outlined, size: 14),
              label: const Text('Record Audit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._audits.map((a) => _auditCard(a)),
      ],
    );
  }

  Widget _maintenanceCard(Map<String, dynamic> m) {
    final status = m['status']?.toString() ?? 'In-Progress';
    final cost = (m['service_cost'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m['item_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
              Text('₹${cost.toStringAsFixed(0)} Cost', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF059669))),
            ],
          ),
          const SizedBox(height: 4),
          Text(m['issue_description']?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vendor: ${m['vendor_service_center'] ?? 'Care Center'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'Completed' ? const Color(0xFF059669).withValues(alpha: 0.1) : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status == 'Completed' ? const Color(0xFF059669) : const Color(0xFFD97706))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _auditCard(Map<String, dynamic> a) {
    final status = a['audit_status']?.toString() ?? 'Verified';
    final variance = (a['variance'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(a['item_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'Verified' ? const Color(0xFF059669).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: status == 'Verified' ? const Color(0xFF059669) : const Color(0xFFEF4444))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('System Qty: ${a['system_quantity']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(width: 14),
              Text('Physical Count: ${a['physical_quantity']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(width: 14),
              Text('Variance: $variance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: variance == 0 ? const Color(0xFF059669) : const Color(0xFFDC2626))),
            ],
          ),
          if (a['remarks'] != null && a['remarks'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Remarks: ${a['remarks']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  void _showAddItemModal() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: 'AST-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(text: '5000');
    final roomCtrl = TextEditingController(text: 'Senior Physics Lab');
    String category = 'Lab Equipment';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Capital Asset / Stock Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Asset Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Asset Code', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.where((c) => c != 'All')
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setMState(() => category = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Unit Cost (₹)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'Location / Room', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _inventoryService.addInventoryItem({
                      'name': nameCtrl.text.trim(),
                      'item_code': codeCtrl.text.trim(),
                      'category': category,
                      'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                      'unit_cost': double.tryParse(costCtrl.text) ?? 0.0,
                      'location_room': roomCtrl.text.trim(),
                    });
                    _loadData();
                  },
                  child: const Text('Save Asset to Inventory'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIssueItemModal(Map<String, dynamic> it) {
    final toCtrl = TextEditingController(text: 'Ms. Sunita Sharma');
    final purposeCtrl = TextEditingController(text: 'Smart lecture demo');
    int qty = 1;
    final maxQty = (it['quantity'] as num?)?.toInt() ?? 1;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Issue Asset: ${it['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: toCtrl,
                decoration: const InputDecoration(labelText: 'Issue To (Teacher / Staff Name)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purposeCtrl,
                decoration: const InputDecoration(labelText: 'Purpose / Course / Lab', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Issue Quantity:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: qty > 1 ? () => setMState(() => qty--) : null,
                      ),
                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: qty < maxQty ? () => setMState(() => qty++) : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _inventoryService.issueItem(
                      itemId: it['id']?.toString() ?? 'it',
                      itemName: it['name']?.toString() ?? 'Asset',
                      issuedToId: 'steacher1',
                      issuedToName: toCtrl.text.trim(),
                      quantity: qty,
                      purpose: purposeCtrl.text.trim(),
                    );
                    _loadData();
                  },
                  child: const Text('Confirm Asset Issue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReturnItemModal(Map<String, dynamic> iss) {
    String condition = 'Good';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accept Return: ${iss['item_name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: condition,
                decoration: const InputDecoration(labelText: 'Inspected Condition on Return', border: OutlineInputBorder()),
                items: ['Good', 'Fair', 'Damaged']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setMState(() => condition = v!),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _inventoryService.returnItem(
                      issueId: iss['id']?.toString() ?? 'iss',
                      conditionOnReturn: condition,
                    );
                    _loadData();
                  },
                  child: const Text('Accept Return into Store'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScheduleMaintenanceModal(Map<String, dynamic> it) {
    final descCtrl = TextEditingController(text: 'Routine annual servicing & calibration');
    final costCtrl = TextEditingController(text: '1500');
    final vendorCtrl = TextEditingController(text: 'Authorized Partner');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule Maintenance: ${it['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Issue / Service Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Estimated Service Cost (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: vendorCtrl,
              decoration: const InputDecoration(labelText: 'Vendor / Service Center', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _inventoryService.scheduleMaintenance(
                    itemId: it['id']?.toString() ?? 'it',
                    itemName: it['name']?.toString() ?? 'Asset',
                    issueDescription: descCtrl.text.trim(),
                    serviceCost: double.tryParse(costCtrl.text) ?? 0.0,
                    vendor: vendorCtrl.text.trim(),
                  );
                  _loadData();
                },
                child: const Text('Schedule Service Log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConductAuditModal() {
    if (_items.isEmpty) return;
    final item = _items.first;
    final countCtrl = TextEditingController(text: '${item['quantity']}');
    final remCtrl = TextEditingController(text: 'Physical verification matched inventory store count.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Physical Audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Asset: ${item['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('System Recorded Qty: ${item['quantity']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 10),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual Physical Count *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: remCtrl,
              decoration: const InputDecoration(labelText: 'Audit Remarks', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _inventoryService.recordPhysicalAudit(
                itemId: item['id']?.toString() ?? 'it',
                itemName: item['name']?.toString() ?? 'Asset',
                systemQty: (item['quantity'] as num?)?.toInt() ?? 1,
                physicalQty: int.tryParse(countCtrl.text) ?? 1,
                remarks: remCtrl.text.trim(),
              );
              _loadData();
            },
            child: const Text('Submit Audit Result'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      await SchoolExportService.exportSchoolInventoryStockAuditExcel(
        context: context,
        items: _items,
        audits: _audits,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    }
  }
}
