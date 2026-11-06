import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_living_service.dart';
import '../../../services/school_export_service.dart';
import '../../../services/auth_service.dart';

class SchoolLivingScreen extends StatefulWidget {
  const SchoolLivingScreen({super.key});

  @override
  State<SchoolLivingScreen> createState() => _SchoolLivingScreenState();
}

class _SchoolLivingScreenState extends State<SchoolLivingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _livingService = SchoolLivingService();

  bool _isLoading = true;
  String? _errorMessage;

  // Hostel Data
  List<Map<String, dynamic>> _hostels = [];
  List<Map<String, dynamic>> _gatePasses = [];
  Map<String, dynamic> _hostelStats = {};

  // Infirmary Data
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _medicines = [];

  // Cafeteria Data
  List<Map<String, dynamic>> _menus = [];
  List<Map<String, dynamic>> _orders = [];

  // Design Tokens
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _primary = Color(0xFF2563EB); // Indigo/Blue
  static const Color _emerald = Color(0xFF059669);
  static const Color _violet = Color(0xFF7C3AED);
  static const Color _amber = Color(0xFFD97706);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hList = await _livingService.getHostels();
      final gpList = await _livingService.getGatePasses();
      final hStats = await _livingService.getHostelStats();

      final vList = await _livingService.getInfirmaryVisits();
      final mList = await _livingService.getMedicineStock();

      final menuList = await _livingService.getCafeteriaMenus();
      final ordList = await _livingService.getCanteenOrders();

      if (mounted) {
        setState(() {
          _hostels = hList;
          _gatePasses = gpList;
          _hostelStats = hStats;

          _visits = vList;
          _medicines = mList;

          _menus = menuList;
          _orders = ordList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Campus Living: Hostel, Infirmary & Dining',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Records',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export Current Tab Excel',
            onPressed: () => _exportActiveTabExcel(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.hotel_rounded, size: 18), text: 'Hostel & Residence'),
            Tab(icon: Icon(Icons.medical_services_rounded, size: 18), text: 'Infirmary (Clinic)'),
            Tab(icon: Icon(Icons.restaurant_rounded, size: 18), text: 'Cafeteria & Meals'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHostelTab(isWide),
                    _buildInfirmaryTab(isWide),
                    _buildCafeteriaTab(isWide),
                  ],
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. HOSTEL TAB (S3.1 + SP-R03)
  // ---------------------------------------------------------------------------
  Widget _buildHostelTab(bool isWide) {
    final occPct = (_hostelStats['occupancy_percentage'] as num?)?.toDouble() ?? 75.0;
    final cap = _hostelStats['total_capacity'] ?? 220;
    final occ = _hostelStats['occupied_beds'] ?? 165;
    final activePasses = _hostelStats['active_gate_passes'] ?? _gatePasses.length;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildKpiGrid(
            isWide: isWide,
            tiles: [
              _kpi('Total Capacity', '$cap Beds', Icons.hotel_outlined, _primary),
              _kpi('Occupancy Rate', '${occPct.toStringAsFixed(1)}%', Icons.pie_chart_outline, _emerald),
              _kpi('Occupied Beds', '$occ Students', Icons.groups_outlined, _violet),
              _kpi('Active Gate Passes', '$activePasses Students', Icons.exit_to_app_rounded, _amber),
            ],
          ),
          const SizedBox(height: 16),
          _buildHostelOccupancyChart(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Residential Hostels & Wardens',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export Excel (SP-R03)'),
                style: OutlinedButton.styleFrom(foregroundColor: _emerald, side: const BorderSide(color: _border)),
                onPressed: () => SchoolExportService.exportSchoolHostelOccupancyExcel(context: context, hostels: _hostels),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._hostels.map((h) => _buildHostelCard(h)),
          const SizedBox(height: 20),
          const Text(
            'Active Gate Passes & Night-Out Authorizations',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 12),
          if (_gatePasses.isEmpty)
            _buildEmptyCard('No Active Gate Passes', 'All hostel boarding students are currently present within campus residences.')
          else
            ..._gatePasses.map((gp) => _buildGatePassTile(gp)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHostelOccupancyChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: _primary),
              SizedBox(width: 8),
              Text('Hostel Occupancy Distribution (SP-R03)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 140,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < _hostels.length) {
                          final name = _hostels[idx]['name']?.toString() ?? 'Hostel';
                          return Text(name.split(' ').first, style: const TextStyle(fontSize: 11, color: _muted));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                barGroups: _hostels.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final h = entry.value;
                  final cap = (h['capacity'] as num?)?.toDouble() ?? 100.0;
                  final occ = cap * 0.75;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(toY: cap, color: _primary.withValues(alpha: 0.25), width: 18, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: occ, color: _primary, width: 18, borderRadius: BorderRadius.circular(4)),
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

  Widget _buildHostelCard(Map<String, dynamic> h) {
    final name = h['name']?.toString() ?? 'Hostel';
    final warden = h['warden_name']?.toString() ?? 'Warden';
    final contact = h['warden_contact']?.toString() ?? '-';
    final cap = h['capacity'] ?? 100;
    final gender = h['gender']?.toString() ?? 'Boys';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.apartment_rounded, color: _primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(gender.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _violet)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Warden: $warden • $contact', style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$cap Beds', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              const Text('Capacity', style: TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGatePassTile(Map<String, dynamic> gp) {
    final sname = gp['student_name']?.toString() ?? 'Student';
    final sid = gp['student_id']?.toString() ?? '';
    final reason = gp['reason']?.toString() ?? 'Personal Leave';
    final outTime = gp['out_time']?.toString() ?? '-';
    final status = (gp['status']?.toString() ?? 'Active').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFFFFBEB),
            child: Icon(Icons.badge_outlined, size: 18, color: _amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$sname ($sid)', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink)),
                Text('$reason • Out: $outTime', style: const TextStyle(fontSize: 11.5, color: _muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _amber)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. INFIRMARY TAB (S3.2 + SP-R04)
  // ---------------------------------------------------------------------------
  Widget _buildInfirmaryTab(bool isWide) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildKpiGrid(
            isWide: isWide,
            tiles: [
              _kpi('Total Consultations', '${_visits.length} Logged', Icons.medical_services_outlined, _primary),
              _kpi('Admitted to Bed', '0 Students', Icons.bed_outlined, _emerald),
              _kpi('Medical Stock Items', '${_medicines.length} Types', Icons.medication_outlined, _violet),
              _kpi('Parent Alerts Sent', '${_visits.length} Real-Time', Icons.notifications_active_outlined, _amber),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Clinical Visits Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Log Visit'),
                    style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                    onPressed: _showLogVisitModal,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export Excel (SP-R04)'),
                    style: OutlinedButton.styleFrom(foregroundColor: _emerald, side: const BorderSide(color: _border)),
                    onPressed: () => SchoolExportService.exportSchoolInfirmaryVisitsExcel(context: context, visits: _visits),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_visits.isEmpty)
            _buildEmptyCard('No Clinical Visits Logged', 'All students are in optimal health. Log consultations and treatments using the "Log Visit" action.')
          else
            ..._visits.map((v) => _buildVisitCard(v)),
          const SizedBox(height: 20),
          const Text('Essential Medicine & First-Aid Inventory', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 12),
          ..._medicines.map((m) => _buildMedicineTile(m)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> v) {
    final sname = v['student_name']?.toString() ?? 'Student';
    final sid = v['student_id']?.toString() ?? '';
    final symp = v['symptoms']?.toString() ?? 'Checkup';
    final treat = v['treatment']?.toString() ?? 'Treatment';
    final med = v['medicine_given']?.toString() ?? 'Rest';
    final time = v['visit_time']?.toString() ?? '-';
    final staff = v['handled_by']?.toString() ?? 'Nurse';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$sname ($sid)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
              Text(time.length > 10 ? time.substring(0, 10) : time, style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Symptoms: $symp', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _danger)),
          const SizedBox(height: 2),
          Text('Treatment: $treat • Medicine: $med', style: const TextStyle(fontSize: 12, color: _muted)),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attended by: $staff', style: const TextStyle(fontSize: 11, color: _muted)),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: _emerald),
                  SizedBox(width: 4),
                  Text('Parent Notified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _emerald)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineTile(Map<String, dynamic> m) {
    final name = m['name']?.toString() ?? '';
    final cat = m['category']?.toString() ?? '';
    final qty = (m['quantity'] as num?)?.toInt() ?? 0;
    final unit = m['unit']?.toString() ?? 'Units';
    final exp = m['expiry_date']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                Text('$cat • Exp: $exp', style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: qty > 20 ? _emerald.withValues(alpha: 0.1) : _danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$qty $unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: qty > 20 ? _emerald : _danger)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. CAFETERIA TAB (S3.3 + SP-R05)
  // ---------------------------------------------------------------------------
  Widget _buildCafeteriaTab(bool isWide) {
    double totalRevenue = 0.0;
    for (final o in _orders) {
      totalRevenue += (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildKpiGrid(
            isWide: isWide,
            tiles: [
              _kpi('Canteen Orders', '${_orders.length} Completed', Icons.receipt_long_outlined, _primary),
              _kpi('Total Sales Volume', '₹${totalRevenue.toStringAsFixed(0)}', Icons.point_of_sale_rounded, _emerald),
              _kpi('Active Menus', '${_menus.length} Meal Offerings', Icons.restaurant_menu_rounded, _violet),
              _kpi('Meal Plan Subs', '38 Students', Icons.card_membership_outlined, _amber),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Campus Dining Menu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export Excel (SP-R05)'),
                style: OutlinedButton.styleFrom(foregroundColor: _emerald, side: const BorderSide(color: _border)),
                onPressed: () => SchoolExportService.exportSchoolCafeteriaSalesExcel(context: context, orders: _orders),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._menus.map((m) => _buildMenuItemCard(m)),
          const SizedBox(height: 20),
          const Text('Recent Dining & Canteen Orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 12),
          if (_orders.isEmpty)
            _buildEmptyCard('No Canteen Orders Today', 'Transactions through student RFID cards and wallet deductions will appear here in real time.')
          else
            ..._orders.map((o) => _buildOrderTile(o)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> m) {
    final item = m['item_name']?.toString() ?? '';
    final meal = m['meal_type']?.toString() ?? 'Meal';
    final price = (m['price'] as num?)?.toDouble() ?? 50.0;
    final cat = m['category']?.toString() ?? 'Veg';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.restaurant_outlined, color: _emerald, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink)),
                Text('$meal • $cat', style: const TextStyle(fontSize: 11.5, color: _muted)),
              ],
            ),
          ),
          Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink)),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Map<String, dynamic> o) {
    final sname = o['student_name']?.toString() ?? 'Student';
    final sid = o['student_id']?.toString() ?? '';
    final amt = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
    final time = o['order_time']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$sname ($sid)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
              Text('Time: ${time.length > 16 ? time.substring(0, 16) : time}', style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
          Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _emerald)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS & MODALS
  // ---------------------------------------------------------------------------
  void _showLogVisitModal() {
    final snameCtrl = TextEditingController(text: 'Aarav Sharma');
    final sidCtrl = TextEditingController(text: 'sstudent1');
    final sympCtrl = TextEditingController(text: 'Mild Fever & Headache');
    final treatCtrl = TextEditingController(text: 'Oral rehydration and resting in clinic observation bay');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log Infirmary Clinic Visit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 6),
            const Text('Record student medical room consultation. Instant notification will be transmitted to the parent.', style: TextStyle(fontSize: 12.5, color: _muted)),
            const SizedBox(height: 16),
            TextField(controller: sidCtrl, decoration: const InputDecoration(labelText: 'Student Username', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: snameCtrl, decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: sympCtrl, decoration: const InputDecoration(labelText: 'Reported Symptoms', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: treatCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Treatment / First Aid', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  final user = await AuthService().getCurrentUsername() ?? 'nurse1';
                  await _livingService.logInfirmaryVisit(
                    studentId: sidCtrl.text.trim(),
                    studentName: snameCtrl.text.trim(),
                    className: 'Class 10-A',
                    symptoms: sympCtrl.text.trim(),
                    diagnosis: 'Seasonal Viral / Fatigue',
                    treatment: treatCtrl.text.trim(),
                    handledBy: user,
                  );
                  _loadAllData();
                },
                child: const Text('Save & Notify Parent', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportActiveTabExcel(BuildContext context) {
    if (_tabController.index == 0) {
      SchoolExportService.exportSchoolHostelOccupancyExcel(context: context, hostels: _hostels);
    } else if (_tabController.index == 1) {
      SchoolExportService.exportSchoolInfirmaryVisitsExcel(context: context, visits: _visits);
    } else {
      SchoolExportService.exportSchoolCafeteriaSalesExcel(context: context, orders: _orders);
    }
  }

  Widget _buildKpiGrid({required bool isWide, required List<Widget> tiles}) {
    return isWide
        ? Row(children: tiles.map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: t))).toList())
        : Column(
            children: [
              Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 8), Expanded(child: tiles[1])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 8), Expanded(child: tiles[3])]),
            ],
          );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted), maxLines: 1),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Column(
        children: [
          const Icon(Icons.info_outline_rounded, size: 36, color: _muted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() => const Center(child: CircularProgressIndicator());

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: _danger),
          const SizedBox(height: 12),
          Text(_errorMessage ?? 'Failed to load campus records', style: const TextStyle(color: _muted)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
        ],
      ),
    );
  }
}
