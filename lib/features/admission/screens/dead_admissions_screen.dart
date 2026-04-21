import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/temp_admission_service.dart';

class DeadAdmissionsScreen extends StatefulWidget {
  final String? counsellorId; // If null, show all (for dean)

  const DeadAdmissionsScreen({super.key, this.counsellorId});

  @override
  State<DeadAdmissionsScreen> createState() => _DeadAdmissionsScreenState();
}

class _DeadAdmissionsScreenState extends State<DeadAdmissionsScreen> {
  final _service = TempAdmissionService();
  List<Map<String, dynamic>> _deadAdmissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> data;
    if (widget.counsellorId != null) {
      data =
          await _service.getDeadAdmissionsForCounsellor(widget.counsellorId!);
    } else {
      data = await _service.getAllDeadAdmissions();
    }

    setState(() {
      _deadAdmissions = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Rejected Admissions'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deadAdmissions.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              color: Colors.green.shade300, size: 80),
          const SizedBox(height: 16),
          const Text(
            'No Rejected Admissions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'All offers have been accepted!',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deadAdmissions.length,
        itemBuilder: (context, index) => _buildCard(_deadAdmissions[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> admission) {
    final rejectedAt = admission['rejected_at'] != null
        ? DateTime.tryParse(admission['rejected_at'])
        : null;
    final formattedDate = rejectedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(rejectedAt)
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with red accent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_off,
                      color: Colors.red.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admission['student_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Temp ID: ${admission['temp_id'] ?? '-'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'REJECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                    Icons.school, 'Course', admission['course'] ?? '-'),
                const SizedBox(height: 8),
                _buildDetailRow(
                    Icons.phone, 'Phone', admission['phone'] ?? '-'),
                const SizedBox(height: 8),
                _buildDetailRow(
                    Icons.email, 'Email', admission['email'] ?? '-'),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.person, 'Counsellor',
                    admission['assigned_counsellor'] ?? '-'),
                const SizedBox(height: 8),
                _buildDetailRow(
                    Icons.calendar_today, 'Rejected On', formattedDate),
                if (admission['rejection_reason'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          admission['rejection_reason'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
