import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/lead_model.dart';
import '../data/lead_status.dart';
import '../services/lead_service.dart';
import '../widgets/lead_status_chip.dart';

/// Lead Detail Screen - Full view of a single lead with history and actions
class LeadDetailScreen extends StatefulWidget {
  final String leadId;
  final String username;

  const LeadDetailScreen({
    super.key,
    required this.leadId,
    required this.username,
  });

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  final LeadService _leadService = LeadService();

  Lead? _lead;
  List<LeadStatusHistory> _history = [];
  List<LeadFollowup> _followups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _leadService.getLeadById(widget.leadId),
        _leadService.getLeadHistory(widget.leadId),
        _leadService.getLeadFollowups(widget.leadId),
      ]);

      setState(() {
        _lead = results[0] as Lead?;
        _history = results[1] as List<LeadStatusHistory>;
        _followups = results[2] as List<LeadFollowup>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_lead?.studentName ?? 'Lead Details'),
        actions: [
          if (_lead != null) ...[
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () => _makeCall(_lead!.phone),
              tooltip: 'Call',
            ),
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => _openWhatsApp(_lead!.phone),
              tooltip: 'WhatsApp',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lead == null
              ? const Center(child: Text('Lead not found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildContactCard(),
                        const SizedBox(height: 16),
                        _buildCourseCard(),
                        const SizedBox(height: 16),
                        _buildStatusCard(),
                        const SizedBox(height: 16),
                        _buildActionsCard(),
                        const SizedBox(height: 16),
                        _buildHistoryCard(),
                        const SizedBox(height: 16),
                        _buildFollowupsCard(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _lead != null
          ? FloatingActionButton.extended(
              onPressed: _showStatusUpdateDialog,
              icon: const Icon(Icons.update),
              label: const Text('Update Status'),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                _lead!.studentName.isNotEmpty
                    ? _lead!.studentName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lead!.studentName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      LeadStatusChip(status: _lead!.status),
                      const SizedBox(width: 8),
                      LeadPriorityBadge(priority: _lead!.priority),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created ${_lead!.timeSinceCreation}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.contact_phone, size: 20),
                SizedBox(width: 8),
                Text(
                  'Contact Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(),
            _InfoRow(icon: Icons.phone, label: 'Phone', value: _lead!.phone),
            if (_lead!.alternatePhone != null)
              _InfoRow(
                  icon: Icons.phone_android,
                  label: 'Alternate',
                  value: _lead!.alternatePhone!),
            if (_lead!.email != null)
              _InfoRow(icon: Icons.email, label: 'Email', value: _lead!.email!),
            if (_lead!.city != null || _lead!.state != null)
              _InfoRow(
                icon: Icons.location_on,
                label: 'Location',
                value: [_lead!.city, _lead!.state]
                    .where((e) => e != null)
                    .join(', '),
              ),
            if (_lead!.address != null)
              _InfoRow(
                  icon: Icons.home, label: 'Address', value: _lead!.address!),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school, size: 20),
                SizedBox(width: 8),
                Text(
                  'Course Interest',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(),
            _InfoRow(
                icon: Icons.book,
                label: 'Course',
                value: _lead!.preferredCourse),
            if (_lead!.preferredBatch != null)
              _InfoRow(
                  icon: Icons.schedule,
                  label: 'Batch',
                  value: _lead!.preferredBatch!),
            if (_lead!.preferredSession != null)
              _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Session',
                  value: _lead!.preferredSession!),
            if (_lead!.qualification != null)
              _InfoRow(
                  icon: Icons.workspace_premium,
                  label: 'Qualification',
                  value: _lead!.qualification!),
            if (_lead!.percentage != null)
              _InfoRow(
                  icon: Icons.percent,
                  label: 'Percentage',
                  value: '${_lead!.percentage}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, size: 20),
                SizedBox(width: 8),
                Text(
                  'Lead Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.source,
              label: 'Source',
              value: '${_lead!.source.emoji} ${_lead!.source.label}',
            ),
            _InfoRow(
              icon: Icons.flag,
              label: 'Priority',
              value: '${_lead!.priority.emoji} ${_lead!.priority.label}',
            ),
            if (_lead!.lastContactDate != null)
              _InfoRow(
                icon: Icons.access_time,
                label: 'Last Contact',
                value: _formatDate(_lead!.lastContactDate!),
              ),
            if (_lead!.nextFollowupDate != null)
              _InfoRow(
                icon: Icons.schedule,
                label: 'Next Follow-up',
                value: _formatDate(_lead!.nextFollowupDate!),
                valueColor: _lead!.isFollowupOverdue ? Colors.red : null,
              ),
            _InfoRow(
              icon: Icons.repeat,
              label: 'Follow-up Count',
              value: '${_lead!.followupCount}',
            ),
            if (_lead!.lastRemark != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Remark',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_lead!.lastRemark!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on, size: 20),
                SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  color: Colors.green,
                  onPressed: () => _makeCall(_lead!.phone),
                ),
                _ActionButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: Colors.teal,
                  onPressed: () => _openWhatsApp(_lead!.phone),
                ),
                if (_lead!.email != null)
                  _ActionButton(
                    icon: Icons.email,
                    label: 'Email',
                    color: Colors.blue,
                    onPressed: () => _sendEmail(_lead!.email!),
                  ),
                _ActionButton(
                  icon: Icons.note_add,
                  label: 'Add Note',
                  color: Colors.orange,
                  onPressed: _showAddNoteDialog,
                ),
                _ActionButton(
                  icon: Icons.schedule,
                  label: 'Schedule',
                  color: Colors.purple,
                  onPressed: _showScheduleFollowupDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Status History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${_history.length} entries',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(),
            if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No history yet')),
              )
            else
              ..._history.take(5).map((h) => _HistoryTile(history: h)),
            if (_history.length > 5)
              TextButton(
                onPressed: _showFullHistory,
                child: Text('View all ${_history.length} entries'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowupsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Scheduled Follow-ups',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showScheduleFollowupDialog,
                ),
              ],
            ),
            const Divider(),
            if (_followups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No follow-ups scheduled')),
              )
            else
              ..._followups.map((f) => _FollowupTile(followup: f)),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final formattedPhone =
        cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';

    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showStatusUpdateDialog() {
    final availableStatuses = LeadStatusHelper.getNextStatuses(_lead!.status);
    final noteController = TextEditingController();
    DateTime? selectedFollowup;
    LeadStatus? selectedStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Current: '),
                    LeadStatusChip(status: _lead!.status),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Select New Status',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableStatuses.map((status) {
                    final isSelected = status == selectedStatus;
                    return ChoiceChip(
                      avatar: Text(status.emoji),
                      label: Text(status.label),
                      selected: isSelected,
                      onSelected: (_) =>
                          setSheetState(() => selectedStatus = status),
                      selectedColor:
                          Color(LeadStatusHelper.getStatusColor(status))
                              .withOpacity(0.3),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Add Note',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 10, minute: 0),
                      );
                      if (time != null) {
                        setSheetState(() {
                          selectedFollowup = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    selectedFollowup != null
                        ? 'Follow-up: ${_formatDate(selectedFollowup!)}'
                        : 'Schedule Follow-up',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedStatus != null
                        ? () async {
                            final success = await _leadService.updateLeadStatus(
                              leadId: _lead!.id,
                              newStatus: selectedStatus!,
                              changedBy: widget.username,
                              notes: noteController.text.isNotEmpty
                                  ? noteController.text
                                  : null,
                              nextFollowup: selectedFollowup,
                            );

                            Navigator.pop(context);
                            if (success) {
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Status updated to ${selectedStatus!.label}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Update Status'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddNoteDialog() {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Enter your note...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (noteController.text.isNotEmpty) {
                await _leadService.addLeadNote(
                  leadId: _lead!.id,
                  note: noteController.text,
                  addedBy: widget.username,
                );
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showScheduleFollowupDialog() {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    FollowupType selectedType = FollowupType.call;
    final purposeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule Follow-up',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text('Type',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: FollowupType.values.map((type) {
                    return ChoiceChip(
                      avatar: Text(type.emoji),
                      label: Text(type.label),
                      selected: type == selectedType,
                      onSelected: (_) =>
                          setSheetState(() => selectedType = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 60)),
                          );
                          if (date != null) {
                            setSheetState(() => selectedDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          selectedDate != null
                              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                              : 'Select Date',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 10, minute: 0),
                          );
                          if (time != null) {
                            setSheetState(() => selectedTime = time);
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          selectedTime != null
                              ? '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                              : 'Select Time',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedDate != null && selectedTime != null
                        ? () async {
                            final scheduledDate = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );

                            await _leadService.scheduleFollowup(
                              leadId: _lead!.id,
                              counsellorId: _lead!.assignedCounsellorId ?? '',
                              scheduledDate: scheduledDate,
                              type: selectedType,
                              purpose: purposeController.text.isNotEmpty
                                  ? purposeController.text
                                  : null,
                            );

                            Navigator.pop(context);
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Follow-up scheduled!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Schedule'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Full History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _history.length,
                itemBuilder: (context, index) =>
                    _HistoryTile(history: _history[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final LeadStatusHistory history;

  const _HistoryTile({required this.history});

  @override
  Widget build(BuildContext context) {
    final status = LeadStatus.fromString(history.newStatus);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Color(LeadStatusHelper.getStatusColor(status)),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(status.emoji),
              const SizedBox(width: 8),
              Text(
                status.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                _formatDate(history.createdAt),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (history.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              history.notes!,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'by ${history.changedBy}',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _FollowupTile extends StatelessWidget {
  final LeadFollowup followup;

  const _FollowupTile({required this.followup});

  @override
  Widget build(BuildContext context) {
    final isPending = followup.status == FollowupStatus.pending;
    final isOverdue = followup.isOverdue;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.shade50
            : isPending
                ? Colors.amber.shade50
                : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(followup.type.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  followup.type.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDate(followup.scheduledDate),
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (followup.purpose != null)
                  Text(
                    followup.purpose!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOverdue
                  ? Colors.red
                  : isPending
                      ? Colors.amber
                      : Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOverdue ? 'Overdue' : followup.status.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
