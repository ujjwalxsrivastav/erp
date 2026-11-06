import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class CircularsScreen extends StatefulWidget {
  const CircularsScreen({super.key});

  @override
  State<CircularsScreen> createState() => _CircularsScreenState();
}

class _CircularsScreenState extends State<CircularsScreen> {
  final _schoolService = SchoolService();
  final _authService = AuthService();
  String _selectedCategory = 'All';
  String? _userRole;
  bool _isLoading = true;
  String? _errorMessage;
  final List<String> _categories = [
    'All',
    'General',
    'Academic',
    'Exam',
    'Fee',
    'Events',
    'Holiday'
  ];

  List<Map<String, dynamic>> _circulars = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final role = await _authService.getCurrentUserRole();
      final list = await _schoolService.getCirculars();
      if (mounted) {
        setState(() {
          _userRole = role;
          _circulars = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Unable to load notices. Please check your network and tap retry.';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 'All') return _circulars;
    return _circulars
        .where((c) =>
            (c['category']?.toString().toLowerCase() ?? '') ==
            _selectedCategory.toLowerCase())
        .toList();
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'General';
    String audience = 'All';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Publish New Circular',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Annual Sports Day 2026',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Category',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  items: [
                    'General',
                    'Academic',
                    'Exam',
                    'Fee',
                    'Events',
                    'Holiday'
                  ]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Target Audience',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  items: ['All', 'Students', 'Parents', 'Teachers']
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => audience = v);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Content / Details',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write circular description...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    contentCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final newCirc = {
                  'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text.trim(),
                  'category': category,
                  'target_audience': audience,
                  'published_at':
                      DateTime.now().toIso8601String().substring(0, 10),
                  'author': 'School Admin',
                };
                await _schoolService.createCircular(newCirc);
                setState(() => _circulars.insert(0, newCirc));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Circular published successfully'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Publish',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const publisherRoles = {
      'admin',
      'sadmin',
      'principal',
      'superadmin',
      'teacher',
      'steacher'
    };
    final canPublish = publisherRoles.contains(_userRole?.toLowerCase());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notices & Circulars',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF581C87), Color(0xFF6D28D9), Color(0xFF7C3AED)],
            ),
          ),
        ),
      ),
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add),
              label: const Text('New Notice',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF581C87),
                  Color(0xFF6D28D9),
                  Color(0xFF7C3AED)
                ],
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF6D28D9)
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingSkeleton()
                : _errorMessage != null
                    ? _buildErrorView()
                    : _filtered.isEmpty
                        ? _buildEmptyView(canPublish)
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: const Color(0xFF7C3AED),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final c = _filtered[index];
                                final cat =
                                    c['category']?.toString() ?? 'General';
                                Color catColor = const Color(0xFF7C3AED);
                                IconData catIcon = Icons.notifications_outlined;
                                if (cat.contains('Exam')) {
                                  catColor = const Color(0xFFEF4444);
                                  catIcon = Icons.quiz_outlined;
                                } else if (cat.contains('Fee')) {
                                  catColor = const Color(0xFFF59E0B);
                                  catIcon = Icons.payment_outlined;
                                } else if (cat.contains('Holiday')) {
                                  catColor = const Color(0xFF10B981);
                                  catIcon = Icons.beach_access_outlined;
                                } else if (cat.contains('Event')) {
                                  catColor = const Color(0xFF3B82F6);
                                  catIcon = Icons.celebration_outlined;
                                }

                                final publishedAt =
                                    c['published_at']?.toString() ?? '';
                                final audience =
                                    c['target_audience']?.toString() ?? 'All';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: catColor.withValues(
                                                  alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(catIcon,
                                                    size: 14, color: catColor),
                                                const SizedBox(width: 6),
                                                Text(
                                                  cat,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: catColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Audience: $audience',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        c['title'] ?? 'Notice',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if ((c['content'] ?? '')
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          c['content'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF475569),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule,
                                              size: 14,
                                              color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            publishedAt.length >= 10
                                                ? publishedAt.substring(0, 10)
                                                : 'Recent',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
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
        height: 120,
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
              child: Icon(Icons.error_outline,
                  size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Notices',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to the server.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool canPublish) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined,
                  size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'No $_selectedCategory Circulars Found',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'New circulars and announcements will appear here once published.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            if (canPublish) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Publish First Notice',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
