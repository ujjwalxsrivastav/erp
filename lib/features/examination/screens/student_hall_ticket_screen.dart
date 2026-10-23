import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/examination_service.dart';

/// Student hall ticket view: pick a published session and see the
/// issued admit card (with QR) or the current registration status.
class StudentHallTicketScreen extends StatefulWidget {
  final String studentId;

  const StudentHallTicketScreen({super.key, required this.studentId});

  @override
  State<StudentHallTicketScreen> createState() =>
      _StudentHallTicketScreenState();
}

class _StudentHallTicketScreenState extends State<StudentHallTicketScreen> {
  final _service = ExaminationService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _selectedSession;
  Map<String, dynamic>? _ticket;
  Map<String, dynamic>? _registration;
  List<Map<String, dynamic>> _sessionSubjects = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final sessions = await _service.getSessions(status: 'published');
    final declared = await _service.getSessions(status: 'result_declared');
    final conducted = await _service.getSessions(status: 'conducted');
    final all = [...sessions, ...conducted, ...declared];
    if (mounted) {
      setState(() {
        _sessions = all;
        _isLoading = false;
      });
      if (all.isNotEmpty) _selectSession(all.first);
    }
  }

  Future<void> _selectSession(Map<String, dynamic> session) async {
    setState(() {
      _selectedSession = session;
      _isLoading = true;
    });
    final ticket =
        await _service.getHallTicket(widget.studentId, session['id'].toString());
    final registration = await _service.getStudentRegistration(
        session['id'].toString(), widget.studentId);
    final subjects =
        await _service.getSessionSubjects(session['id'].toString());
    if (mounted) {
      setState(() {
        _ticket = ticket;
        _registration = registration;
        _sessionSubjects = subjects;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_sessions.isNotEmpty) ...[
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedSession,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Exam Session'),
                        items: _sessions
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                      s['name']?.toString() ?? 'Session',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _selectSession(v);
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.adminPrimary)),
                      )
                    else if (_sessions.isEmpty)
                      _statusCard(
                        Icons.event_busy,
                        'No exam session is open right now',
                        'Hall tickets appear here once a session is published and your ticket is issued by the examination cell.',
                      )
                    else if (_ticket != null)
                      _buildTicketCard()
                    else if (_registration == null)
                      _statusCard(
                        Icons.app_registration,
                        'Exam form not registered',
                        'Your exam form for this session has not been registered yet. Please contact the examination cell if the form window is open.',
                      )
                    else
                      _statusCard(
                        Icons.hourglass_top,
                        'Hall ticket not issued yet',
                        'Your registration status is "${(_registration!['status'] ?? 'applied').toString().replaceAll('_', ' ')}". The hall ticket will appear here once the examination cell verifies your form and issues it.',
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.adminGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('Hall Ticket',
                        style: AppTheme.h2.copyWith(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Carry this admit card with your ID card to every paper',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard() {
    final ticket = _ticket!;
    final subjects =
        (ticket['subjects'] as List?)?.cast<dynamic>() ?? [];
    // Match registration subjects with the session date-sheet for dates/rooms.
    final sheetById = <String, Map<String, dynamic>>{
      for (final s in _sessionSubjects)
        (s['subject_id'] ?? s['subject_name']).toString(): s,
    };
    return GlassCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.adminGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('ADMIT CARD',
                    style: AppTheme.caption.copyWith(
                        color: Colors.white,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_selectedSession?['name']?.toString() ?? 'Examination',
                    style: AppTheme.h5.copyWith(color: Colors.white),
                    textAlign: TextAlign.center),
                Text(
                  '${_selectedSession?['academic_year'] ?? ''} • ${(_selectedSession?['exam_type'] ?? 'regular').toString().toUpperCase()}',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Student ID', widget.studentId),
                    const SizedBox(height: 12),
                    _infoRow('Ticket No', ticket['ticket_no']?.toString() ?? '-'),
                    const SizedBox(height: 12),
                    _infoRow(
                        'Issued On',
                        (ticket['issued_at'] ?? '')
                            .toString()
                            .split('T')
                            .first),
                    const SizedBox(height: 12),
                    _infoRow('Papers', '${subjects.length}'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.extraLightGray, width: 1),
                ),
                child: QrImageView(
                  data: ticket['qr_data']?.toString() ??
                      ticket['ticket_no']?.toString() ??
                      '',
                  version: QrVersions.auto,
                  size: 120,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Papers & Schedule',
              style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.dark, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (subjects.isEmpty)
            Text('Paper list will be confirmed by the examination cell.',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray))
          else
            ...subjects.map((sub) {
              final map = (sub as Map).cast<String, dynamic>();
              final key =
                  (map['subject_id'] ?? map['subject_name']).toString();
              final sheet = sheetById[key];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book,
                          size: 18, color: AppTheme.adminPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              map['subject_name']?.toString() ?? key,
                              style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.dark,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              sheet == null
                                  ? (map['subject_id']?.toString() ?? '')
                                  : '${sheet['exam_date'] ?? ''} • ${sheet['start_time'] ?? ''} - ${sheet['end_time'] ?? ''} • ${sheet['room'] ?? ''}',
                              style: AppTheme.caption
                                  .copyWith(color: AppTheme.mediumGray),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Reach the exam hall 15 minutes early. Mobile phones and smart watches are not allowed inside the hall.',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTheme.caption.copyWith(color: AppTheme.mediumGray)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.dark, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statusCard(IconData icon, String title, String msg) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 52, color: AppTheme.lightGray),
            const SizedBox(height: 14),
            Text(title,
                style: AppTheme.h5.copyWith(color: AppTheme.dark),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray)),
          ],
        ),
      ),
    );
  }
}
