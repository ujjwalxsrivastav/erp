import 'package:flutter/material.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _applications = [
    {
      'name': 'Rahul Mehta',
      'class_applying': 'Class 6',
      'date': '28 Oct 2024',
      'status': 'pending',
      'dob': '15 Mar 2013',
      'parent': 'Suresh Mehta',
      'phone': '9876500001',
    },
    {
      'name': 'Sanya Joshi',
      'class_applying': 'Class 9',
      'date': '25 Oct 2024',
      'status': 'approved',
      'dob': '20 Jan 2010',
      'parent': 'Rajan Joshi',
      'phone': '9876500002',
    },
    {
      'name': 'Arjun Kapoor',
      'class_applying': 'Class 11',
      'date': '20 Oct 2024',
      'status': 'rejected',
      'dob': '05 Jun 2008',
      'parent': 'Anil Kapoor',
      'phone': '9876500003',
    },
    {
      'name': 'Meera Shah',
      'class_applying': 'Class 3',
      'date': '15 Oct 2024',
      'status': 'pending',
      'dob': '10 Sep 2016',
      'parent': 'Vijay Shah',
      'phone': '9876500004',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFiltered(String status) {
    if (status == 'all') return _applications;
    return _applications.where((a) => a['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Admissions', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewAdmissionForm,
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('New Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList('pending'),
          _buildList('approved'),
          _buildList('rejected'),
        ],
      ),
    );
  }

  Widget _buildList(String status) {
    final apps = _getFiltered(status);
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_disabled, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No $status applications', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: apps.length,
      itemBuilder: (context, index) => _buildApplicationCard(apps[index]),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final status = app['status'] as String;
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (app['name'] as String).substring(0, 1),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['name'] as String,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    ),
                    Text(
                      'Applying for: ${app['class_applying']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.person_outline, app['parent'] as String),
              const SizedBox(width: 10),
              _infoChip(Icons.calendar_today_outlined, app['date'] as String),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => app['status'] = 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => app['status'] = 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }

  void _showNewAdmissionForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Admission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(decoration: const InputDecoration(labelText: "Student's Name", prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: "Parent's Name", prefixIcon: Icon(Icons.family_restroom))),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: "Applying for Class", prefixIcon: Icon(Icons.class_))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application submitted!'), backgroundColor: Color(0xFF10B981)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit Application', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

