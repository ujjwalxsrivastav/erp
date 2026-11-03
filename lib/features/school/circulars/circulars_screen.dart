import 'package:flutter/material.dart';

class CircularsScreen extends StatefulWidget {
  const CircularsScreen({super.key});

  @override
  State<CircularsScreen> createState() => _CircularsScreenState();
}

class _CircularsScreenState extends State<CircularsScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'General', 'Exam', 'Fee', 'Event', 'Holiday'];

  final List<Map<String, dynamic>> _circulars = [
    {
      'title': 'Annual Sports Day 2024',
      'content': 'The Annual Sports Day will be held on 25th November. All students must participate in at least one event.',
      'date': '01 Nov 2024',
      'category': 'Event',
      'color': const Color(0xFF8B5CF6),
      'icon': Icons.sports,
      'author': 'Principal',
    },
    {
      'title': 'Half-Yearly Examination Schedule',
      'content': 'Half-yearly exams start from 10th December 2024. Admit cards will be distributed on 5th December.',
      'date': '28 Oct 2024',
      'category': 'Exam',
      'color': const Color(0xFFEF4444),
      'icon': Icons.quiz,
      'author': 'Exam Cell',
    },
    {
      'title': 'Fee Payment Reminder',
      'content': 'Last date for fee payment for Q3 is 15th November. Late fees will be charged after this date.',
      'date': '25 Oct 2024',
      'category': 'Fee',
      'color': const Color(0xFFF59E0B),
      'icon': Icons.payment,
      'author': 'Accounts',
    },
    {
      'title': 'Winter Vacation Notice',
      'content': 'School will remain closed for winter vacation from 25th December to 5th January. Reopen on 6th January.',
      'date': '20 Oct 2024',
      'category': 'Holiday',
      'color': const Color(0xFF10B981),
      'icon': Icons.beach_access,
      'author': 'Principal',
    },
    {
      'title': 'Parent-Teacher Meeting',
      'content': 'PTM is scheduled for 30th November from 9 AM to 1 PM. Parents of all classes are requested to attend.',
      'date': '15 Oct 2024',
      'category': 'General',
      'color': const Color(0xFF3B82F6),
      'icon': Icons.people,
      'author': 'Admin',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 'All') return _circulars;
    return _circulars.where((c) => c['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Circulars & Notices', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF8B5CF6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
                          fontWeight: FontWeight.w600,
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
            child: _filtered.isEmpty
                ? const Center(child: Text('No circulars in this category', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) => _buildCircularCard(_filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularCard(Map<String, dynamic> c) {
    final color = c['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Icon(c['icon'] as IconData, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c['title'] as String,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    c['category'] as String,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['content'] as String,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(c['author'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const Spacer(),
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(c['date'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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

