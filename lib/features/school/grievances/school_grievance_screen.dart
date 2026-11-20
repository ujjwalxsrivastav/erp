import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

/// Full-screen Parent Grievance Centre for the school administration.
///
/// Replaces the old admin-dashboard popup so grievances are handled on a
/// dedicated page with the complete queue.
class SchoolGrievanceScreen extends StatefulWidget {
  const SchoolGrievanceScreen({super.key});

  @override
  State<SchoolGrievanceScreen> createState() => _SchoolGrievanceScreenState();
}

class _SchoolGrievanceScreenState extends State<SchoolGrievanceScreen> {
  final _schoolService = SchoolService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _complaints = [];

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
      final complaints = await _schoolService.getParentComplaints();
      if (!mounted) return;
      setState(() {
        _complaints = complaints;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load grievances: $e';
      });
    }
  }

  bool _isOpen(Map<String, dynamic> c) {
    final status = (c['status'] ?? '').toString().toLowerCase();
    return status.isEmpty ||
        status == 'open' ||
        status == 'submitted' ||
        status == 'pending' ||
        status == 'in_progress';
  }

  Future<void> _showResolveDialog(Map<String, dynamic> complaint) async {
    final notesController = TextEditingController();
    final id = complaint['id']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Resolve Parent Grievance',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint['subject']?.toString().isNotEmpty == true
                          ? complaint['subject'].toString()
                          : 'Parent Complaint',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${complaint['parent'] ?? 'Registered Parent'}'
                      '${(complaint['ticket_no'] ?? '').toString().isNotEmpty ? ' • ${complaint['ticket_no']}' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF7F1D1D)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Resolution Notes (Mandatory for parent notification):',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Enter specific corrective actions taken and response to parent...',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Please enter resolution notes before resolving.'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white),
            child: const Text('Confirm Resolution'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notes = notesController.text.trim();
    final ok = await _schoolService.resolveParentComplaint(
      complaintId: id,
      resolutionNotes: notes,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Parent grievance resolved and recorded.'
            : 'Failed to resolve grievance.'),
        backgroundColor: ok ? const Color(0xFF059669) : Colors.red,
      ),
    );
    if (ok) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _complaints.where(_isOpen).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parent Grievance Centre',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            Text(
              '$openCount open • ${_complaints.length} total complaints',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadData,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF2563EB)),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _complaints.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 80),
                            Icon(Icons.check_circle_outline_rounded,
                                size: 48, color: Color(0xFF059669)),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'No parent grievances in the queue.',
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _complaints.length,
                          itemBuilder: (context, index) {
                            final c = _complaints[index];
                            final isOpen = _isOpen(c);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isOpen
                                              ? const Color(0xFFFEF2F2)
                                              : const Color(0xFFECFDF5),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          (c['status'] ?? 'Open')
                                              .toString()
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isOpen
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                      if ((c['ticket_no'] ?? '')
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          c['ticket_no'].toString(),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF475569)),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (isOpen)
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _showResolveDialog(c),
                                          icon: const Icon(Icons.check_rounded,
                                              size: 14),
                                          label: const Text('Resolve',
                                              style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF059669),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 10, vertical: 4),
                                            minimumSize: const Size(60, 28),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    c['subject']?.toString().isNotEmpty == true
                                        ? c['subject'].toString()
                                        : 'Parent Complaint',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'From: ${c['parent'] ?? 'Registered Parent'}'
                                    '${(c['student'] ?? '').toString().isNotEmpty ? ' • Student: ${c['student']}' : ''}'
                                    '${(c['category'] ?? '').toString().isNotEmpty ? ' • ${c['category']}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B)),
                                  ),
                                  if ((c['description'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      c['description'].toString(),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF334155),
                                          height: 1.4),
                                    ),
                                  ],
                                  if ((c['admin_reply'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Admin reply: ${c['admin_reply']}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF047857)),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
