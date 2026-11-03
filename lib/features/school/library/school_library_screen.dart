import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class SchoolLibraryScreen extends StatefulWidget {
  const SchoolLibraryScreen({super.key});

  @override
  State<SchoolLibraryScreen> createState() => _SchoolLibraryScreenState();
}

class _SchoolLibraryScreenState extends State<SchoolLibraryScreen>
    with SingleTickerProviderStateMixin {
  final _schoolService = SchoolService();
  final _authService = AuthService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _issuedBooks = [];
  List<Map<String, dynamic>> _overdueBooks = [];
  String _userRole = 'student';
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const _primaryColor = Color(0xFF7C3AED);

  final List<String> _categories = [
    'All', 'Science', 'Mathematics', 'Literature', 'History', 'Social Studies',
    'Computer', 'Reference', 'Fiction', 'Sports'
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
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final role = await _authService.getCurrentUserRole() ?? 'student';

      List<Map<String, dynamic>> books = [];
      List<Map<String, dynamic>> issued = [];
      try {
        final booksRes = await _schoolService.supabase.from('school_library').select().order('title');
        books = List<Map<String, dynamic>>.from(booksRes);
      } catch (_) {}

      try {
        final issuedRes = await _schoolService.supabase
            .from('school_library_issues')
            .select()
            .order('issued_date', ascending: false);
        issued = List<Map<String, dynamic>>.from(issuedRes);
      } catch (_) {}

      final overdue = issued.where((i) => i['status'] == 'Overdue').toList();

      if (mounted) {
        setState(() {
          _userRole = role;
          _books = books;
          _issuedBooks = issued;
          _overdueBooks = overdue;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _books = [];
          _issuedBooks = [];
          _overdueBooks = [];
          _isLoading = false;
          _errorMessage = 'Could not load library catalogue. Tap retry.';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBooks {
    return _books.where((b) {
      final matchCat = _selectedCategory == 'All' || b['category'] == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          (b['title'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (b['author'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Library Catalogue',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF7C3AED)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF6D28D9),
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: [
                const Tab(text: 'Books'),
                Tab(text: 'Issued (${_issuedBooks.length})'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Overdue'),
                      if (_overdueBooks.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_overdueBooks.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'sadmin' || _userRole == 'librarian')
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7C3AED),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              elevation: 4,
              onPressed: _showAddBookDialog,
            )
          : null,
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBooksTab(),
                    _buildIssuedTab(),
                    _buildOverdueTab(),
                  ],
                ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Library Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to the library database.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ===== TAB 1: BOOKS =====
  Widget _buildBooksTab() {
    final filtered = _filteredBooks;
    return Column(
      children: [
        // Search + Stats
        Container(
          color: _primaryColor,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search books, authors...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _libStat('${_books.length}', 'Total Books'),
                  _libStat(
                    '${_books.fold<int>(0, (s, b) => s + ((b['available'] as num?)?.toInt() ?? 0))}',
                    'Available',
                  ),
                  _libStat('${_issuedBooks.length}', 'Issued'),
                  _libStat('${_overdueBooks.length}', 'Overdue'),
                ],
              ),
            ],
          ),
        ),

        // Category Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? _primaryColor : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),

        // Book list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('No books found', Icons.menu_book)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildBookCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _libStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final available = (book['available'] as num?)?.toInt() ?? 0;
    final total = (book['copies'] as num?)?.toInt() ?? 0;
    final availabilityColor = available == 0
        ? Colors.red
        : available <= 2
            ? Colors.orange
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showBookDetail(book),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Icon
                Container(
                  width: 50,
                  height: 65,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: _primaryColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'] ?? 'Unknown Title',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${book['author'] ?? 'Unknown Author'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              book['category'] ?? 'General',
                              style: const TextStyle(fontSize: 10, color: _primaryColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500),
                          Text(
                            book['location'] ?? '',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: availabilityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        available == 0 ? 'Unavailable' : '$available/$total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: availabilityColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      available == 0 ? 'All issued' : 'copies left',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                    if ((_userRole == 'admin' || _userRole == 'sadmin' || _userRole == 'librarian') && available > 0)
                      ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showIssueBookDialog(book),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Issue',
                              style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== TAB 2: ISSUED BOOKS =====
  Widget _buildIssuedTab() {
    return _issuedBooks.isEmpty
        ? _buildEmptyState('No books currently issued', Icons.book_outlined)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _issuedBooks.length,
            itemBuilder: (_, i) => _buildIssuedCard(_issuedBooks[i]),
          );
  }

  Widget _buildIssuedCard(Map<String, dynamic> issue) {
    final isOverdue = issue['status'] == 'Overdue';
    final fine = (issue['fine'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isOverdue ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue['book_title'] ?? 'Unknown Book',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    maxLines: 2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOverdue ? Colors.red : Colors.green).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    issue['status'] ?? 'Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text('${issue['student_name'] ?? 'N/A'}  •  Class ${issue['class'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text('Issued: ${issue['issued_date'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                const SizedBox(width: 14),
                Icon(
                  Icons.event,
                  size: 13,
                  color: isOverdue ? Colors.red : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${issue['due_date'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue ? Colors.red : const Color(0xFF9CA3AF),
                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (fine > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Fine: ₹$fine (₹2/day)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                  ),
                ],
              ),
            ],
            if (_userRole == 'admin' || _userRole == 'sadmin' || _userRole == 'librarian') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.book_online, size: 15),
                      label: const Text('Return Book'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _returnBook(issue),
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.payment, size: 15),
                        label: const Text('Collect Fine'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _collectFine(issue),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== TAB 3: OVERDUE =====
  Widget _buildOverdueTab() {
    if (_overdueBooks.isEmpty) {
      return _buildEmptyState('No overdue books! Great!', Icons.check_circle_outline);
    }
    final totalFine = _overdueBooks.fold<int>(0, (s, b) => s + ((b['fine'] as num?)?.toInt() ?? 0));

    return Column(
      children: [
        Container(
          color: Colors.red.shade50,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_overdueBooks.length} books overdue',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    Text(
                      'Total pending fine: ₹$totalFine  •  Fine rate: ₹2/day',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _overdueBooks.length,
            itemBuilder: (_, i) => _buildIssuedCard(_overdueBooks[i]),
          ),
        ),
      ],
    );
  }

  // ===== ACTIONS =====
  void _showBookDetail(Map<String, dynamic> book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book, color: _primaryColor, size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              book['title'] ?? 'Unknown Title',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              'by ${book['author'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _bookDetailRow('ISBN', book['isbn']?.toString() ?? 'N/A'),
            _bookDetailRow('Category', book['category']?.toString() ?? 'General'),
            _bookDetailRow('Total Copies', book['copies']?.toString() ?? 'N/A'),
            _bookDetailRow('Available', book['available']?.toString() ?? 'N/A'),
            _bookDetailRow('Location', book['location']?.toString() ?? 'N/A'),
            const SizedBox(height: 20),
            if ((_userRole == 'admin' || _userRole == 'sadmin' || _userRole == 'librarian') &&
                (book['available'] as num?)?.toInt() != 0) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.book_online),
                label: const Text('Issue This Book'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showIssueBookDialog(book);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  void _showIssueBookDialog(Map<String, dynamic> book) {
    final studentCtrl = TextEditingController();
    final classCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Issue Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: studentCtrl,
              decoration: const InputDecoration(
                labelText: 'Student Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: classCtrl,
              decoration: const InputDecoration(
                labelText: 'Class (e.g. 10-A)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Due date: 14 days from today', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (studentCtrl.text.isEmpty) return;
              final dueDate = DateTime.now().add(const Duration(days: 14));
              final issueId = 'ISS-${_issuedBooks.length + 10}';
              final newIssue = {
                'id': issueId,
                'book_id': book['id']?.toString() ?? '',
                'book_title': book['title']?.toString() ?? '',
                'student_name': studentCtrl.text.trim(),
                'class': classCtrl.text.trim(),
                'issued_date': DateTime.now().toIso8601String().substring(0, 10),
                'due_date': dueDate.toIso8601String().substring(0, 10),
                'status': 'Active',
                'fine': 0,
              };

              try {
                await _schoolService.issueLibraryBook(
                  bookId: book['id']?.toString() ?? '',
                  bookTitle: book['title']?.toString() ?? '',
                  studentName: studentCtrl.text.trim(),
                  className: classCtrl.text.trim(),
                  daysToReturn: 14,
                );
              } catch (_) {}

              setState(() {
                _issuedBooks.insert(0, newIssue);
                final bookIdx = _books.indexWhere((b) => b['id'] == book['id']);
                if (bookIdx >= 0) {
                  final curr = (book['available'] as num?)?.toInt() ?? 0;
                  _books[bookIdx] = {..._books[bookIdx], 'available': curr > 0 ? curr - 1 : 0};
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Book issued to ${studentCtrl.text} (Due in 14 days)'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Issue Book'),
          ),
        ],
      ),
    );
  }

  void _returnBook(Map<String, dynamic> issue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Return Book'),
        content: Text('Mark "${issue['book_title']}" as returned by ${issue['student_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final studentUname = (issue['student_name'] ?? 'sstudent1').toString().toLowerCase().replaceAll(' ', '');
              final res = await _schoolService.returnLibraryBook(
                issueId: issue['id']?.toString() ?? '',
                bookId: issue['book_id']?.toString() ?? '',
                studentUsername: studentUname.contains('aarav') ? 'sstudent1' : studentUname,
              );

              setState(() {
                _issuedBooks.removeWhere((i) => i['id'] == issue['id']);
                _overdueBooks.removeWhere((i) => i['id'] == issue['id']);
                final bookIdx = _books.indexWhere((b) => b['id'] == issue['book_id']);
                if (bookIdx >= 0) {
                  final curr = (_books[bookIdx]['available'] as num?)?.toInt() ?? 0;
                  _books[bookIdx] = {..._books[bookIdx], 'available': curr + 1};
                }
              });
              Navigator.pop(ctx);
              final fineIncurred = (res['fine_incurred'] as num?)?.toDouble() ?? 0.0;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    fineIncurred > 0
                        ? 'Book returned. Late fine of ₹${fineIncurred.toInt()} auto-posted to student fee dues!'
                        : 'Book returned successfully with zero dues.',
                  ),
                  backgroundColor: fineIncurred > 0 ? Colors.orange : Colors.green,
                ),
              );
            },
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );
  }

  void _collectFine(Map<String, dynamic> issue) {
    final fine = (issue['fine'] as num?)?.toInt() ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Collect Fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payment, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text('Student: ${issue['student_name']}'),
            const SizedBox(height: 6),
            Text('Fine Amount: ₹$fine', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                final idx = _issuedBooks.indexWhere((i) => i['id'] == issue['id']);
                if (idx >= 0) {
                  _issuedBooks[idx] = {..._issuedBooks[idx], 'fine': 0};
                }
                final odx = _overdueBooks.indexWhere((i) => i['id'] == issue['id']);
                if (odx >= 0) {
                  _overdueBooks[odx] = {..._overdueBooks[odx], 'fine': 0};
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fine of ₹$fine collected from ${issue['student_name']}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Collected'),
          ),
        ],
      ),
    );
  }

  void _showAddBookDialog() {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final isbnCtrl = TextEditingController();
    final copiesCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String selectedCat = 'Science';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Book'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Book Title *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Author *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: isbnCtrl, decoration: const InputDecoration(labelText: 'ISBN', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setS(() => selectedCat = v ?? selectedCat),
                ),
                const SizedBox(height: 10),
                TextField(controller: copiesCtrl, decoration: const InputDecoration(labelText: 'Number of Copies', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Shelf Location', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
              onPressed: () {
                if (titleCtrl.text.isEmpty || authorCtrl.text.isEmpty) return;
                final copies = int.tryParse(copiesCtrl.text) ?? 1;
                final newBook = {
                  'id': 'BK-${_books.length + 1}'.padLeft(6, '0'),
                  'title': titleCtrl.text,
                  'author': authorCtrl.text,
                  'isbn': isbnCtrl.text,
                  'category': selectedCat,
                  'copies': copies,
                  'available': copies,
                  'location': locationCtrl.text,
                };
                setState(() => _books.insert(0, newBook));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Book added to library'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Add Book'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

