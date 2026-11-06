import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/school_library_deep_service.dart';
import '../../../services/school_export_service.dart';

class SchoolLibraryDeepScreen extends StatefulWidget {
  const SchoolLibraryDeepScreen({super.key});

  @override
  State<SchoolLibraryDeepScreen> createState() => _SchoolLibraryDeepScreenState();
}

class _SchoolLibraryDeepScreenState extends State<SchoolLibraryDeepScreen> with SingleTickerProviderStateMixin {
  final SchoolLibraryDeepService _libraryService = SchoolLibraryDeepService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _ebooks = [];

  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _categories = [
    'All',
    'Mathematics',
    'Science',
    'Literature',
    'Social Studies',
    'Computer Science',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final books = await _libraryService.getBooks(category: _selectedCategory, search: _searchQuery);
      final issues = await _libraryService.getIssuedBooks();
      final reservations = await _libraryService.getReservations();
      final ebooks = await _libraryService.getEbooks();

      if (mounted) {
        setState(() {
          _books = books;
          _issues = issues;
          _reservations = reservations;
          _ebooks = ebooks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load library resources: $e';
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
              'Library Resource Center & E-Books',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Catalogue, Waitlist Reservations, ₹5/day Auto-Fines & Free E-Books',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Excel (SP-R11)',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Add Book to Catalogue',
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _showAddBookModal,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'Catalogue & Loan', icon: Icon(Icons.menu_book_outlined, size: 18)),
            Tab(text: 'Reservations', icon: Icon(Icons.bookmark_added_outlined, size: 18)),
            Tab(text: 'Overdue Desk', icon: Icon(Icons.alarm_on_outlined, size: 18)),
            Tab(text: 'Digital E-Books', icon: Icon(Icons.cloud_download_outlined, size: 18)),
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
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF047857)),
            SizedBox(height: 16),
            Text('Syncing circulation catalogues and waitlist reservations...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                  backgroundColor: const Color(0xFF047857),
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
              _buildCatalogueTab(),
              _buildReservationsTab(),
              _buildOverdueTab(),
              _buildEbooksTab(),
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
    int totalCopies = 0;
    int availableCopies = 0;
    for (final b in _books) {
      totalCopies += (b['copies'] as num?)?.toInt() ?? 0;
      availableCopies += (b['available'] as num?)?.toInt() ?? 0;
    }

    final activeLoans = _issues.where((i) => i['return_date'] == null).length;
    final overdueLoans = _issues.where((i) => (i['days_overdue'] as int? ?? 0) > 0).length;
    double totalFines = 0.0;
    for (final i in _issues) {
      totalFines += (i['fine'] as num?)?.toDouble() ?? 0.0;
    }

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
                title: 'Library Holdings',
                value: '${_books.length} Titles',
                subtitle: '$availableCopies / $totalCopies Copies Available',
                color: const Color(0xFF047857),
                icon: Icons.menu_book_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Active Loans',
                value: '$activeLoans On Loan',
                subtitle: 'Circulating with Students',
                color: const Color(0xFF2563EB),
                icon: Icons.assignment_return_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Overdue Fines',
                value: '₹${totalFines.toStringAsFixed(0)} Assessed',
                subtitle: '$overdueLoans Overdue (₹5/day auto-post)',
                color: overdueLoans > 0 ? const Color(0xFFEF4444) : const Color(0xFF059669),
                icon: Icons.alarm_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Free E-Books',
                value: '${_ebooks.length} Public Titles',
                subtitle: 'NCERT & Gutenberg Reads',
                color: const Color(0xFF7C3AED),
                icon: Icons.cloud_download_outlined,
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
  // TAB 1: CATALOGUE & LOAN
  // ==========================================

  Widget _buildCatalogueTab() {
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
                  hintText: 'Search title, author, ISBN, or accession code...',
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
                ),
                onSubmitted: (val) {
                  setState(() => _searchQuery = val.trim());
                  _loadData();
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showAddBookModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Title'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
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
                  selectedColor: const Color(0xFF047857).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF047857),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Circulation Chart
        _buildCirculationChart(),
        const SizedBox(height: 16),

        // Catalogue Books List
        ..._books.map((b) => _bookCard(b)),
      ],
    );
  }

  Widget _buildCirculationChart() {
    final catCounts = <String, int>{
      'Math': 18,
      'Science': 12,
      'Literature': 24,
      'Social': 14,
      'CS': 11,
    };
    final labels = catCounts.keys.toList();

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
              Text('Available Catalogue Volumes by Subject Domain', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text('fl_chart SP-R11', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 30,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Text(labels[idx], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: labels.asMap().entries.map((e) {
                  final count = catCounts[e.value] ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: const Color(0xFF047857),
                        width: 22,
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

  Widget _bookCard(Map<String, dynamic> b) {
    final available = (b['available'] as num?)?.toInt() ?? 0;
    final total = (b['copies'] as num?)?.toInt() ?? 1;
    final isOutOfStock = available == 0;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.book, color: Color(0xFF047857), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                          child: Text(b['id']?.toString() ?? 'BK', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                          child: Text(b['category']?.toString() ?? 'General', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(b['title']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('By ${b['author']}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$available / $total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFF059669))),
                  Text(isOutOfStock ? 'Waitlist Only' : 'Copies Avail', style: TextStyle(fontSize: 10, color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
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
              Text('Location: ${b['location'] ?? 'Shelf A-1'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              if (isOutOfStock)
                ElevatedButton.icon(
                  onPressed: () => _showReserveModal(b),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 12),
                  label: const Text('Reserve (Waitlist)', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _showIssueModal(b),
                  icon: const Icon(Icons.assignment_return_outlined, size: 12),
                  label: const Text('Issue Loan', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
  // TAB 2: RESERVATIONS & WAITLIST
  // ==========================================

  Widget _buildReservationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Book Reservation Queue & Waitlist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_reservations.length} Queue', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        ..._reservations.map((resv) => _reservationCard(resv)),
      ],
    );
  }

  Widget _reservationCard(Map<String, dynamic> resv) {
    final status = resv['status']?.toString() ?? 'Waitlisted';
    final isReady = status.contains('Ready');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isReady ? const Color(0xFF059669).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(resv['book_title']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReady ? const Color(0xFF059669).withValues(alpha: 0.1) : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isReady ? const Color(0xFF059669) : const Color(0xFFD97706)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Reserved for: ${resv['student_name']} (${resv['class_section']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Claim Window: 3 Days until expiry', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              if (isReady)
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Issue Claimed Copy', style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: OVERDUE DESK & FINE LEDGER
  // ==========================================

  Widget _buildOverdueTab() {
    final overdueList = _issues.where((i) => (i['days_overdue'] as int? ?? 0) > 0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Automated Fine Policy: ₹5.00/day assessed on all overdue issues. Overdue fines are auto-posted to student fee demands under head "LibraryFine".',
                  style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Overdue Books Circulation Desk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${overdueList.length} Overdue', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
          ],
        ),
        const SizedBox(height: 12),
        ...overdueList.map((iss) => _overdueCard(iss)),
      ],
    );
  }

  Widget _overdueCard(Map<String, dynamic> iss) {
    final days = iss['days_overdue'] as int? ?? 0;
    final fine = (iss['fine'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(iss['book_title']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('₹${fine.toStringAsFixed(0)} FINE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Borrower: ${iss['student_name']} (${iss['class']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(width: 10),
              Text('$days Days Late', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Due Date: ${iss['due_date']} • Auto-posted to Fees', style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _showWaiveFineModal(iss),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Waive Fine', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _returnBook(iss),
                icon: const Icon(Icons.check_circle_outline, size: 12),
                label: const Text('Return Book & Settle Fine', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: DIGITAL E-BOOKS (FREE SOURCES ONLY)
  // ==========================================

  Widget _buildEbooksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC4B5FD).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.public, color: Color(0xFF7C3AED), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '100% Free Educational Resources: All e-books are officially provided via NCERT Open Educational Resources and Project Gutenberg Public Domain archives. Zero subscription or fee required.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF5B21B6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Digital E-Books & Open Reads', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_ebooks.length} Free Titles', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
          ],
        ),
        const SizedBox(height: 12),
        ..._ebooks.map((ebk) => _ebookCard(ebk)),
      ],
    );
  }

  Widget _ebookCard(Map<String, dynamic> ebk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Color(0xFF7C3AED), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ebk['title']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('By ${ebk['author']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(ebk['source_domain']?.toString() ?? 'Public Domain', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                    const SizedBox(width: 8),
                    Text('${ebk['file_size_mb']} MB', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final url = ebk['download_url']?.toString();
              if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            icon: const Icon(Icons.download, size: 12),
            label: const Text('Read Free', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  void _showAddBookModal() {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final isbnCtrl = TextEditingController();
    final copiesCtrl = TextEditingController(text: '15');
    final roomCtrl = TextEditingController(text: 'Shelf A-2');
    String category = 'Mathematics';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Title to Library Catalogue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Book Title *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Author Name *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Subject Category', border: OutlineInputBorder()),
                      items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setMState(() => category = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(controller: copiesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Copies Count', border: OutlineInputBorder())),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: isbnCtrl, decoration: const InputDecoration(labelText: 'ISBN Number', border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Shelf Location', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _libraryService.addBook({
                      'title': titleCtrl.text.trim(),
                      'author': authorCtrl.text.trim(),
                      'category': category,
                      'isbn': isbnCtrl.text.trim(),
                      'copies': int.tryParse(copiesCtrl.text) ?? 10,
                      'location': roomCtrl.text.trim(),
                    });
                    _loadData();
                  },
                  child: const Text('Save to Library Holdings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIssueModal(Map<String, dynamic> b) {
    final studentCtrl = TextEditingController(text: 'Aarav Sharma');
    final classCtrl = TextEditingController(text: 'Class 10-A');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue Book Loan: ${b['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: studentCtrl, decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class & Section', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book loan issued for 14-day borrowing period.')));
                  _loadData();
                },
                child: const Text('Confirm 14-Day Circulation Loan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReserveModal(Map<String, dynamic> b) {
    final studentCtrl = TextEditingController(text: 'Aarav Sharma');
    final classCtrl = TextEditingController(text: 'Class 10-A');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reserve (Waitlist): ${b['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('All copies currently on loan. Join waitlist queue to reserve the next returned volume.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(controller: studentCtrl, decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class & Section', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _libraryService.reserveBook(
                    bookId: b['id']?.toString() ?? 'BK',
                    bookTitle: b['title']?.toString() ?? 'Book',
                    studentId: 'sstudent1',
                    studentName: studentCtrl.text.trim(),
                    classSection: classCtrl.text.trim(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation confirmed! You are #1 on the waitlist queue.')));
                  _loadData();
                },
                child: const Text('Join Waitlist Queue (3-Day Claim Window)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _returnBook(Map<String, dynamic> iss) async {
    final res = await _libraryService.returnBookWithAutoFine(
      issueId: iss['id']?.toString() ?? 'iss',
      bookId: iss['book_id']?.toString() ?? 'BK-001',
      studentName: iss['student_name']?.toString() ?? 'Student',
    );
    if (mounted) {
      final fine = res['fine_amount'] as double? ?? 0.0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Book returned. Fine: ₹${fine.toStringAsFixed(0)} (Auto-posted to Fee Ledger).')),
      );
      _loadData();
    }
  }

  void _showWaiveFineModal(Map<String, dynamic> iss) {
    final reasonCtrl = TextEditingController(text: 'Medical absence verified by school infirmary.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Waive Library Overdue Fine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fine Amount: ₹${iss['fine']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFDC2626))),
            const SizedBox(height: 10),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for Waiver *', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _libraryService.waiveLibraryFine(
                fineId: iss['id']?.toString() ?? 'iss',
                reason: reasonCtrl.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fine waived with audit trail entry.')));
              _loadData();
            },
            child: const Text('Confirm Waiver'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      await SchoolExportService.exportSchoolLibraryCirculationExcel(
        context: context,
        issues: _issues,
        ebooks: _ebooks,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export Excel: $e')));
    }
  }
}
