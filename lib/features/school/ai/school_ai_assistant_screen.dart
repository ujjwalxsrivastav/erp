import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/school_ai_service.dart';
import '../../../services/school_export_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/school_service.dart';
import 'widgets/rag_chat_panel.dart';

class SchoolAiAssistantScreen extends StatefulWidget {
  final int initialTab;
  const SchoolAiAssistantScreen({super.key, this.initialTab = 0});

  @override
  State<SchoolAiAssistantScreen> createState() => _SchoolAiAssistantScreenState();
}

class _SchoolAiAssistantScreenState extends State<SchoolAiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SchoolAiService _aiService = SchoolAiService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String? _errorMessage;

  String _currentUsername = '';
  String _currentRole = '';

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _remarks = [];
  List<Map<String, dynamic>> _questionPapers = [];
  List<Map<String, dynamic>> _feedbacks = [];

  // Controllers for remark generation
  final _studentNameCtrl = TextEditingController();
  final _studentUserCtrl = TextEditingController();
  final _marksCtrl = TextEditingController();
  final _attCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _examCtrl = TextEditingController();
  final _remarkClassCtrl = TextEditingController();
  final _feedbackAssignmentCtrl = TextEditingController();
  final _feedbackStudentCtrl = TextEditingController();
  final _feedbackSummaryCtrl = TextEditingController();
  final _feedbackScoreCtrl = TextEditingController();
  final _feedbackMaxCtrl = TextEditingController();
  bool _isGeneratingRemark = false;

  // Controllers for question paper
  final _qpSubjectCtrl = TextEditingController();
  final _qpClassCtrl = TextEditingController();
  final _qpChaptersCtrl = TextEditingController();
  final _qpMarksCtrl = TextEditingController();
  bool _isGeneratingPaper = false;
  bool _isGeneratingFeedback = false;

  // Theme Constants
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentNameCtrl.dispose();
    _studentUserCtrl.dispose();
    _marksCtrl.dispose();
    _attCtrl.dispose();
    _notesCtrl.dispose();
    _examCtrl.dispose();
    _remarkClassCtrl.dispose();
    _feedbackAssignmentCtrl.dispose();
    _feedbackStudentCtrl.dispose();
    _feedbackSummaryCtrl.dispose();
    _feedbackScoreCtrl.dispose();
    _feedbackMaxCtrl.dispose();
    _qpSubjectCtrl.dispose();
    _qpClassCtrl.dispose();
    _qpChaptersCtrl.dispose();
    _qpMarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uname = await _authService.getCurrentUsername() ?? '';
      final rawRole = uname.isEmpty ? null : await _authService.getLiveUserRole(uname);
      if (uname.isEmpty || rawRole == null) throw Exception('Your signed-in school role could not be verified.');
      final role = rawRole == 'steacher' ? 'teacher' : rawRole == 'sadmin' ? 'admin' : rawRole;
      if (!{'teacher', 'class_teacher', 'admin', 'sadmin', 'principal', 'superadmin', 'student', 'sstudent', 'parent', 'sparent', 'staff', 'accountant', 'librarian', 'warden', 'nurse', 'conductor', 'alumni'}.contains(role)) {
        throw Exception('This role cannot access AI tools.');
      }
      final isAdmin = {'admin', 'sadmin', 'principal', 'superadmin'}.contains(rawRole);

      final stats = isAdmin ? await _aiService.getAiStats() : <String, dynamic>{};

      // Live queries from runtime tables (R5)
      List<Map<String, dynamic>> remarks = [];
      List<Map<String, dynamic>> papers = [];
      List<Map<String, dynamic>> feedbacks = [];

      try {
        if (!isAdmin) throw StateError('Saved remarks have no owner column for safe teacher scoping.');
        final remRes = await SupabaseService.client
            .from('school_ai_remarks')
            .select()
            .order('created_at', ascending: false);
        remarks = List<Map<String, dynamic>>.from(remRes);
      } catch (_) {}

      try {
        var qpQuery = SupabaseService.client.from('school_ai_question_papers').select();
        if (!isAdmin) qpQuery = qpQuery.eq('created_by', uname);
        final qpRes = await qpQuery.order('created_at', ascending: false);
        papers = List<Map<String, dynamic>>.from(qpRes);
      } catch (_) {}

      try {
        var fbQuery = SupabaseService.client.from('school_ai_feedback').select();
        if (!isAdmin) fbQuery = fbQuery.eq('created_by', uname);
        final fbRes = await fbQuery.order('created_at', ascending: false);
        feedbacks = List<Map<String, dynamic>>.from(fbRes);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentUsername = uname;
          _currentRole = role;
          _stats = stats;
          _remarks = remarks;
          _questionPapers = papers;
          _feedbacks = feedbacks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportChatExcel() async {
    try {
      final res = await SupabaseService.client
          .from('school_ai_usage_log')
          .select()
          .order('created_at', ascending: false);
      final usageLogs = List<Map<String, dynamic>>.from(res);
      final instituteName = await SchoolService().getSchoolInstituteName() ?? '';

      if (!mounted) return;
      await SchoolExportService.exportSchoolChatbotUsageExcel(
        context: context,
        instituteName: instituteName,
        usageLogs: usageLogs,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  Future<void> _exportAiUsageExcel() async {
    try {
      final instituteName = await SchoolService().getSchoolInstituteName() ?? '';
      await SchoolExportService.exportSchoolAiUsageExcel(
        context: context,
        instituteName: instituteName,
        aiStats: _stats,
        remarksList: _remarks,
        questionPapers: _questionPapers,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  Future<void> _handleGenerateRemark() async {
    final sName = _studentNameCtrl.text.trim();
    final sUser = _studentUserCtrl.text.trim();
    final exam = _examCtrl.text.trim();
    final classId = _remarkClassCtrl.text.trim();
    final marks = double.tryParse(_marksCtrl.text.trim());
    final att = double.tryParse(_attCtrl.text.trim());
    if (sName.isEmpty || sUser.isEmpty || exam.isEmpty || classId.isEmpty || marks == null || att == null || marks < 0 || marks > 100 || att < 0 || att > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid student, class, exam, marks (0-100), and attendance (0-100).')),
      );
      return;
    }

    setState(() => _isGeneratingRemark = true);
    try {
      final rem = await _aiService.draftReportCardRemark(
        studentUsername: sUser,
        studentName: sName,
        examId: exam,
        classId: classId,
        marksPercentage: marks,
        attendancePercentage: att,
        behaviouralNotes: _notesCtrl.text.trim(),
        teacherUsername: _currentUsername,
      );

      setState(() {
        _remarks.insert(0, rem);
        _isGeneratingRemark = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('AI remark drafted successfully! Pending faculty sign-off.')),
              ],
            ),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGeneratingRemark = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Error: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _handleGenerateQuestionPaper() async {
    final sub = _qpSubjectCtrl.text.trim();
    final cls = _qpClassCtrl.text.trim();
    final chs = _qpChaptersCtrl.text.trim();
    final marks = int.tryParse(_qpMarksCtrl.text.trim());
    if (sub.isEmpty || cls.isEmpty || chs.isEmpty || marks == null || marks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter subject, class, chapters, and total marks.')),
      );
      return;
    }

    setState(() => _isGeneratingPaper = true);
    try {
      final qp = await _aiService.generateQuestionPaper(
        classId: cls,
        subject: sub,
        chapters: chs,
        totalMarks: marks,
        teacherUsername: _currentUsername,
      );

      setState(() {
        _questionPapers.insert(0, qp);
        _isGeneratingPaper = false;
      });

      _showPaperPreviewDialog(qp);
    } catch (e) {
      setState(() => _isGeneratingPaper = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Error: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _handleFeedbackDraft() async {
    final assignment = _feedbackAssignmentCtrl.text.trim();
    final student = _feedbackStudentCtrl.text.trim();
    final summary = _feedbackSummaryCtrl.text.trim();
    final score = double.tryParse(_feedbackScoreCtrl.text.trim());
    final maxScore = double.tryParse(_feedbackMaxCtrl.text.trim());
    if (assignment.isEmpty || student.isEmpty || summary.isEmpty || score == null || maxScore == null || maxScore <= 0 || score < 0 || score > maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter assignment, student, submission summary, and valid score.')),
      );
      return;
    }

    setState(() => _isGeneratingFeedback = true);
    try {
      final feedback = await _aiService.draftAssignmentFeedback(
        assignmentTitle: assignment,
        studentName: student,
        studentSubmissionSummary: summary,
        score: score,
        maxScore: maxScore,
        teacherUsername: _currentUsername,
      );
      if (mounted) {
        setState(() {
          _feedbacks.insert(0, feedback);
          _isGeneratingFeedback = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment feedback drafted!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGeneratingFeedback = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feedback draft failed: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: _ink,
      ),
    );
  }

  void _showPaperPreviewDialog(Map<String, dynamic> qp) {
    final title = qp['title'] ?? 'Examination Paper Blueprint';
    final content = qp['content']?.toString() ?? '';
    final subject = qp['subject'] ?? '';
    final classId = qp['class_id'] ?? '';
    final totalMarks = qp['total_marks'] ?? 80;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_outlined, color: _primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _ink)),
                          Text('$subject  •  Class $classId  •  Max Marks: ${totalMarks}M',
                              style: const TextStyle(fontSize: 12, color: _muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Draft — Subject to Mandatory Teacher Review & HOD Sign-off before official printing.',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        content,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.55,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Blueprint Text'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => _copyToClipboard(content, 'Question paper copied to clipboard!'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _askChat(String question) => _aiService.askRagAssistant(
        question: question,
        userRole: _currentRole,
        username: _currentUsername,
      );

  Future<void> _decideRemark(Map<String, dynamic> remark, bool approve) async {
    final author = (remark['teacher_username'] ?? remark['created_by'])?.toString() ?? '';
    if (author.isEmpty || author == _currentUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot approve own remarks under dual-custody verification.')),
      );
      return;
    }
    try {
      await _aiService.approveRemark(
        remarkId: remark['id'].toString(),
        teacherUsername: _currentUsername,
        approve: approve,
      );
      if (mounted) setState(() => remark['status'] = approve ? 'approved' : 'rejected');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Remark decision failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = _currentRole == 'teacher' ||
        _currentRole == 'class_teacher' ||
        _currentRole == 'admin' ||
        _currentRole == 'sadmin' ||
        _currentRole == 'superadmin' ||
        _currentRole == 'principal';
    final isAdmin = {'admin', 'sadmin', 'superadmin', 'principal'}.contains(_currentRole);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'School AI Copilot',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _ink),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Groq / Gemini Active',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Text(
              'Faculty Intelligence Hub & Retrieval-Augmented Helpdesk',
              style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (isAdmin) ...[
            IconButton(
              tooltip: 'Export AI Usage Report (Excel)',
              icon: const Icon(Icons.file_download_outlined, size: 20, color: _muted),
              onPressed: _exportAiUsageExcel,
            ),
            IconButton(
              tooltip: 'Export Chat Log Audit',
              icon: const Icon(Icons.history_edu_outlined, size: 20, color: _muted),
              onPressed: _exportChatExcel,
            ),
          ],
          IconButton(
            tooltip: 'Refresh Desk',
            icon: const Icon(Icons.refresh_rounded, size: 20, color: _muted),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: isStaff
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: _ink,
                    unselectedLabelColor: _muted,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rate_review_outlined, size: 15),
                            const SizedBox(width: 6),
                            const Text('Remarks Drafter'),
                            if (_remarks.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              _badgeCount(_remarks.length),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.quiz_outlined, size: 15),
                            const SizedBox(width: 6),
                            const Text('Paper Blueprint'),
                            if (_questionPapers.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              _badgeCount(_questionPapers.length),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined, size: 15),
                            const SizedBox(width: 6),
                            const Text('HW Feedback'),
                            if (_feedbacks.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              _badgeCount(_feedbacks.length),
                            ],
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.smart_toy_outlined, size: 15),
                            SizedBox(width: 6),
                            Text('RAG Knowledge Desk'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error: $_errorMessage', style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : isStaff
                  ? Column(
                      children: [
                        if (isAdmin) _buildKpiBanner(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRemarksTab(),
                              _buildQuestionPaperTab(),
                              _buildFeedbackTab(),
                              _buildRagChatTab(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _buildRagChatTab(),
    );
  }

  Widget _badgeCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primary),
      ),
    );
  }

  Widget _buildKpiBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;
        final approvalRate = (_stats['approval_rate_percent'] as num?)?.toDouble() ?? 0.0;

        final tile1 = _kpiTile('Remarks Drafted', '${_stats['total_remarks_drafted'] ?? 0}', Icons.edit_note_rounded, const Color(0xFF4F46E5), const Color(0xFFEEF2FF));
        final tile2 = _kpiTile('Faculty Approval', '${approvalRate.toStringAsFixed(1)}%', Icons.verified_rounded, const Color(0xFF059669), const Color(0xFFECFDF5));
        final tile3 = _kpiTile('Papers Generated', '${_stats['question_papers_generated'] ?? 0}', Icons.description_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF));
        final tile4 = _kpiTile('RAG Queries Answered', '${_stats['rag_chats_answered'] ?? 0}', Icons.forum_rounded, const Color(0xFF0284C7), const Color(0xFFF0F9FF));

        return isMobile
            ? Column(
                children: [
                  Row(children: [Expanded(child: tile1), const SizedBox(width: 8), Expanded(child: tile2)]),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: tile3), const SizedBox(width: 8), Expanded(child: tile4)]),
                ],
              )
            : Row(
                children: [
                  Expanded(child: tile1),
                  const SizedBox(width: 10),
                  Expanded(child: tile2),
                  const SizedBox(width: 10),
                  Expanded(child: tile3),
                  const SizedBox(width: 10),
                  Expanded(child: tile4),
                ],
              );
      }),
    );
  }

  Widget _kpiTile(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.auto_awesome_rounded, size: 20, color: _primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Report Card Remarks Drafter',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                          Text(
                            'Synthesizes marks, attendance & qualitative observations into encouraging CBSE report card comments.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        controller: _studentNameCtrl,
                        label: 'Student Name',
                        hint: 'e.g. Aarav Sharma',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput(
                        controller: _studentUserCtrl,
                        label: 'Student Username / ID',
                        hint: 'e.g. s10s01',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        controller: _remarkClassCtrl,
                        label: 'Class & Section',
                        hint: 'e.g. Class 10-A',
                        icon: Icons.class_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput(
                        controller: _examCtrl,
                        label: 'Exam Session',
                        hint: 'e.g. sess-midterm-2026',
                        icon: Icons.event_note_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        controller: _marksCtrl,
                        label: 'Academic Score %',
                        hint: 'e.g. 88.5',
                        keyboard: TextInputType.number,
                        icon: Icons.percent_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput(
                        controller: _attCtrl,
                        label: 'Attendance Rate %',
                        hint: 'e.g. 92.0',
                        keyboard: TextInputType.number,
                        icon: Icons.how_to_reg_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _notesCtrl,
                  label: 'Teacher Behavioural Observations & Traits',
                  hint: 'e.g. Active in science quizzes, highly cooperative in teams, needs practice in algebraic problem solving.',
                  icon: Icons.comment_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _presetChip('🌟 Academic Excellence', 'Outstanding diligence, sharp conceptual grasping, and exemplary class conduct.'),
                    _presetChip('📈 Consistent Progress', 'Shows steady improvement, proactive during discussions, eager to learn.'),
                    _presetChip('⚠️ Needs Practice', 'Good potential; requires disciplined revision in analytical formulas and math.'),
                    _presetChip('🤝 Team Leader', 'Excellent teamwork skills, polite demeanor, and strong communication.'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isGeneratingRemark
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      _isGeneratingRemark ? 'Synthesizing Remark with AI...' : 'Draft AI Remark with Verified Citation',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: _isGeneratingRemark ? null : _handleGenerateRemark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Remarks & Approval Desk',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              Text('${_remarks.length} Drafted', style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          if (_remarks.isEmpty)
            _buildEmptyCard('No AI remarks drafted yet. Fill out the form above to generate official report card comments.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _remarks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final rem = _remarks[i];
                final isApproved = rem['status'] == 'approved';
                final isRejected = rem['status'] == 'rejected';
                final draftText = rem['draft_remark'] ?? '';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isApproved
                          ? const Color(0xFFA7F3D0)
                          : isRejected
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFFDE68A),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            child: Text(
                              (rem['student_name']?.toString().isNotEmpty ?? false)
                                  ? rem['student_name'].toString().substring(0, 1).toUpperCase()
                                  : 'S',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isApproved ? const Color(0xFF059669) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(rem['student_name'] ?? 'Student',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _ink)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                            child: Text(rem['class_id'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _muted)),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? const Color(0xFFECFDF5)
                                  : isRejected
                                      ? const Color(0xFFFEF2F2)
                                      : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isApproved
                                  ? 'APPROVED'
                                  : isRejected
                                      ? 'REJECTED'
                                      : 'APPROVAL PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isApproved
                                    ? const Color(0xFF065F46)
                                    : isRejected
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        draftText,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: _border),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Copy Remark', style: TextStyle(fontSize: 11.5)),
                            style: TextButton.styleFrom(foregroundColor: _muted),
                            onPressed: () => _copyToClipboard(draftText, 'Remark text copied!'),
                          ),
                          const Spacer(),
                          if (!isApproved && !isRejected && _currentRole == 'principal') ...[
                            TextButton(
                              onPressed: () => _decideRemark(rem, false),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                              child: const Text('Reject', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 14),
                              label: const Text('Approve & Publish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: () => _decideRemark(rem, true),
                            ),
                          ] else if (isApproved) ...[
                            const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF059669)),
                            const SizedBox(width: 5),
                            const Text('Verified & Signed by Faculty',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionPaperTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF7C3AED)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Automated Question Paper Blueprint Generator',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                          Text(
                            'Balanced cognitive distribution: 40% Knowledge, 40% Application & Problem Solving, 20% Higher Order HOTS.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        controller: _qpSubjectCtrl,
                        label: 'Subject',
                        hint: 'e.g. Mathematics Standard (041)',
                        icon: Icons.calculate_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput(
                        controller: _qpClassCtrl,
                        label: 'Class',
                        hint: 'e.g. Class 10',
                        icon: Icons.school_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _qpChaptersCtrl,
                  label: 'Chapters / Units to Cover',
                  hint: 'e.g. Real Numbers, Polynomials, Pair of Linear Equations in Two Variables',
                  icon: Icons.layers_outlined,
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _qpMarksCtrl,
                  label: 'Total Marks',
                  hint: 'e.g. 80',
                  keyboard: TextInputType.number,
                  icon: Icons.grade_outlined,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _presetMarksChip('CBSE Board (80M)', '80'),
                    _presetMarksChip('Term / Half Yearly (50M)', '50'),
                    _presetMarksChip('Periodic Test (25M)', '25'),
                    _presetMarksChip('Chapter Quiz (20M)', '20'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isGeneratingPaper
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      _isGeneratingPaper ? 'Compiling Paper Blueprint...' : 'Generate Exam Blueprint & Marking Scheme',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: _isGeneratingPaper ? null : _handleGenerateQuestionPaper,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Generated Exam Blueprints',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              Text('${_questionPapers.length} Blueprints', style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          if (_questionPapers.isEmpty)
            _buildEmptyCard('No question papers generated yet. Fill out the subject and chapters above.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questionPapers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final qp = _questionPapers[i];
                final subject = qp['subject'] ?? 'Subject';
                final classId = qp['class_id'] ?? 'Class';
                final totalMarks = qp['total_marks'] ?? 80;
                final dateStr = qp['created_at']?.toString().split('T')[0] ?? '';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_outlined, color: Color(0xFF7C3AED), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$subject — $classId',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
                            const SizedBox(height: 3),
                            Text('Max: ${totalMarks}M  •  Generated on: $dateStr',
                                style: const TextStyle(fontSize: 12, color: _muted)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('Inspect Blueprint', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: _ink,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showPaperPreviewDialog(qp),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.rate_review_rounded, size: 20, color: Color(0xFF16A34A)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Assignment Qualitative Feedback Drafter',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                          Text(
                            'Generates constructive, actionable feedback tailored to students homework submissions.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        controller: _feedbackAssignmentCtrl,
                        label: 'Assignment Title',
                        hint: 'e.g. Chapter 4 Trigonometry Problem Set',
                        icon: Icons.assignment_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput(
                        controller: _feedbackStudentCtrl,
                        label: 'Student Name',
                        hint: 'e.g. Diya Patel',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _feedbackSummaryCtrl,
                  label: 'Student Submission Highlights / Weaknesses',
                  hint: 'e.g. Solved standard algebraic proofs correctly, but struggled with application identities in Q7 & Q9.',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInput(
                        controller: _feedbackScoreCtrl,
                        label: 'Marks Awarded',
                        hint: 'e.g. 18',
                        keyboard: TextInputType.number,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput(
                        controller: _feedbackMaxCtrl,
                        label: 'Maximum Marks',
                        hint: 'e.g. 20',
                        keyboard: TextInputType.number,
                        icon: Icons.grade_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isGeneratingFeedback
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      _isGeneratingFeedback ? 'Drafting Constructive Feedback...' : 'Draft Qualitative Feedback',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: _isGeneratingFeedback ? null : _handleFeedbackDraft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Assignment Feedback Queue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              Text('${_feedbacks.length} Feedbacks', style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          if (_feedbacks.isEmpty)
            _buildEmptyCard('No feedback drafts generated yet. Enter submission details above.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _feedbacks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final fb = _feedbacks[i];
                final student = fb['student_name'] ?? 'Student';
                final title = fb['assignment_id'] ?? fb['assignment_title'] ?? 'Assignment';
                final feedbackText = fb['draft_feedback'] ?? '';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: _muted),
                          const SizedBox(width: 6),
                          Text(student, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _ink)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                            child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted)),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: _muted),
                            tooltip: 'Copy Feedback',
                            onPressed: () => _copyToClipboard(feedbackText, 'Feedback text copied!'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(feedbackText, style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.45)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRagChatTab() {
    return Container(
      color: Colors.white,
      child: RagChatPanel(
        onSend: _askChat,
        inputHint: 'Ask about syllabi, academic regulations, CBSE criteria, or institute routines...',
        llmAvailable: SchoolAiService.isLlmConfigured,
        suggestions: const [
          AiChatSuggestion(
            label: 'Academic Calendar',
            prompt: 'Academic calendar',
            icon: Icons.calendar_today_outlined,
            dummyReply: 'Academic session 2026-27 runs as follows:\n'
                '• Term begins: 1 April 2026\n'
                '• Unit Test 1: 11 – 16 May 2026\n'
                '• Summer break: 25 May – 30 June 2026\n'
                '• Half-yearly exams: 14 – 26 September 2026\n'
                '• Annual exams: 15 February – 10 March 2027\n\n'
                'The full month-wise calendar is on the school notice board.',
          ),
          AiChatSuggestion(
            label: 'School Timings',
            prompt: 'School timings',
            icon: Icons.schedule_outlined,
            dummyReply: 'Monday to Friday:\n'
                '• Assembly: 7:50 – 8:15 AM\n'
                '• Periods 1–4: 8:15 – 11:00 AM\n'
                '• Lunch break: 11:00 – 11:35 AM\n'
                '• Periods 5–8: 11:35 AM – 2:15 PM\n'
                '• Dispersal: 2:15 PM\n\n'
                'Remedial classes and sports clubs run from 2:30 to 4:15 PM.',
          ),
          AiChatSuggestion(
            label: 'Fee Payment Terms',
            prompt: 'Fee payment',
            icon: Icons.payments_outlined,
            dummyReply: 'Fees are collected in four quarterly installments, due on the '
                '10th of April, July, October and January.\n'
                '• Pay by UPI, card or net banking from the Fee Desk.\n'
                '• A receipt (RCP-2026-XXXXX) is generated instantly.\n'
                '• A ₹50/week late fine applies after the 5-day grace period.',
          ),
          AiChatSuggestion(
            label: 'Library Circulation',
            prompt: 'Library policy',
            icon: Icons.local_library_outlined,
            dummyReply: 'Each borrower can issue up to 3 books for 14 days, renewable '
                'once if no hold is active.\n'
                '• Overdue fine: ₹5 per day.\n'
                '• Fines auto-post to the student fee ledger.\n'
                '• 1,200+ e-books are available in the Library section.',
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 18, color: _muted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _presetChip(String label, String note) {
    return ActionChip(
      avatar: const Icon(Icons.add_rounded, size: 14, color: _primary),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: () {
        final current = _notesCtrl.text.trim();
        _notesCtrl.text = current.isEmpty ? note : '$current $note';
      },
    );
  }

  Widget _presetMarksChip(String label, String marks) {
    return ActionChip(
      avatar: const Icon(Icons.format_list_numbered_rounded, size: 14, color: Color(0xFF7C3AED)),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
      backgroundColor: const Color(0xFFF5F3FF),
      side: const BorderSide(color: Color(0xFFDDD6FE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: () => _qpMarksCtrl.text = marks,
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
