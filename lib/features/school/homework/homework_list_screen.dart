import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';

class HomeworkListScreen extends StatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  State<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends State<HomeworkListScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late TabController _tabController;
  String? _role;

  final List<Map<String, dynamic>> _homework = [
    {
      'id': '1',
      'subject': 'Mathematics',
      'title': 'Chapter 5: Quadratic Equations - Exercise 5.3',
      'description': 'Solve problems 1-15 from the textbook.',
      'class': 'Class 10-A',
      'due_date': '2024-11-15',
      'teacher': 'Mr. Sharma',
      'status': 'pending',
      'color': const Color(0xFF3B82F6),
    },
    {
      'id': '2',
      'subject': 'Science',
      'title': 'Draw and label the diagram of human heart',
      'description': 'Use A4 sheet, label all four chambers.',
      'class': 'Class 10-A',
      'due_date': '2024-11-17',
      'teacher': 'Mrs. Gupta',
      'status': 'pending',
      'color': const Color(0xFF10B981),
    },
    {
      'id': '3',
      'subject': 'English',
      'title': 'Essay: Impact of Technology on Education',
      'description': 'Write 500 words essay with introduction, body, and conclusion.',
      'class': 'Class 10-A',
      'due_date': '2024-11-20',
      'teacher': 'Ms. Verma',
      'status': 'pending',
      'color': const Color(0xFF8B5CF6),
    },
    {
      'id': '4',
      'subject': 'History',
      'title': 'Map Work: Battle of Panipat',
      'description': 'Mark key locations on outline map provided.',
      'class': 'Class 10-A',
      'due_date': '2024-11-10',
      'teacher': 'Mr. Kumar',
      'status': 'submitted',
      'color': const Color(0xFFF59E0B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await _authService.getCurrentUserRole();
    if (mounted) setState(() => _role = role);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _role == 'teacher';
    final pending = _homework.where((h) => h['status'] == 'pending').toList();
    final submitted = _homework.where((h) => h['status'] == 'submitted').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Homework', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Submitted (${submitted.length})'),
          ],
        ),
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/school/homework/upload'),
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeworkList(pending),
          _buildHomeworkList(submitted),
        ],
      ),
    );
  }

  Widget _buildHomeworkList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No homework here!',
              style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildHomeworkCard(items[index]),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final isSubmitted = hw['status'] == 'submitted';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (hw['color'] as Color).withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hw['color'] as Color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.book_outlined, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  hw['subject'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hw['color'] as Color,
                  ),
                ),
                const Spacer(),
                if (isSubmitted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '✓ Submitted',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hw['title'] as String,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 6),
                Text(
                  hw['description'] as String,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.class_outlined, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(hw['class'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(width: 14),
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(hw['teacher'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSubmitted
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: isSubmitted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${hw['due_date']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSubmitted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

