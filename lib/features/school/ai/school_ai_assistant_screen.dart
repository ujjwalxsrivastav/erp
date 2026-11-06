import 'package:flutter/material.dart';
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

  // Controller for chat

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
      if (!{'teacher', 'class_teacher', 'admin', 'sadmin', 'principal', 'superadmin', 'student', 'sstudent', 'parent', 'sparent', 'staff', 'accountant', 'librarian', 'warden', 'nurse', 'conductor', 'alumni'}.contains(role)) throw Exception('This role cannot access AI tools.');
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the student, class, exam, marks, and attendance from verified records.')));
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI remark drafted! Review and approve before publishing.'),
          backgroundColor: Colors.indigo,
        ),
      );
    } catch (e) {
      setState(() => _isGeneratingRemark = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Error: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _handleGenerateQuestionPaper() async {
    final sub = _qpSubjectCtrl.text.trim();
    final cls = _qpClassCtrl.text.trim();
    final chs = _qpChaptersCtrl.text.trim();
    final marks = int.tryParse(_qpMarksCtrl.text.trim());
    if (sub.isEmpty || cls.isEmpty || chs.isEmpty || marks == null || marks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the allotted class, subject, chapters, and total marks.')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Error: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _handleFeedbackDraft() async {
    final assignment = _feedbackAssignmentCtrl.text.trim();
    final student = _feedbackStudentCtrl.text.trim();
    final summary = _feedbackSummaryCtrl.text.trim();
    final score = double.tryParse(_feedbackScoreCtrl.text.trim());
    final maxScore = double.tryParse(_feedbackMaxCtrl.text.trim());
    if (assignment.isEmpty || student.isEmpty || summary.isEmpty || score == null || maxScore == null || maxScore <= 0 || score < 0 || score > maxScore) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the assignment, student, submission summary, and valid score.')));
      return;
    }
    try {
      final feedback = await _aiService.draftAssignmentFeedback(
        assignmentTitle: assignment,
        studentName: student,
        studentSubmissionSummary: summary,
        score: score,
        maxScore: maxScore,
        teacherUsername: _currentUsername,
      );
      if (mounted) setState(() => _feedbacks.insert(0, feedback));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Feedback draft failed: $e')));
    }
  }

  void _showPaperPreviewDialog(Map<String, dynamic> qp) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(qp['title'] ?? 'Examination Paper Blueprint'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_outlined, size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI draft — teacher approval pending. Faculty review and sign-off required prior to printing.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    qp['content']?.toString() ?? '',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This draft has no verified maker identity for approval.')));
      return;
    }
    try {
      await _aiService.approveRemark(remarkId: remark['id'].toString(), teacherUsername: _currentUsername, approve: approve);
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
      appBar: AppBar(
        title: Text(isStaff ? 'AI Faculty Assistant & RAG Desk' : 'School Assistant'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (isAdmin) ...[
            IconButton(
              tooltip: 'Export AI Usage (SP-R15)',
              icon: const Icon(Icons.analytics_outlined),
              onPressed: _exportAiUsageExcel,
            ),
            IconButton(
              tooltip: 'Export Chat Audit (SP-R13)',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: _exportChatExcel,
            ),
          ],
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: isStaff
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.rate_review_outlined), text: 'Remarks Drafter'),
                  Tab(icon: Icon(Icons.quiz_outlined), text: 'Question Generator'),
                  Tab(icon: Icon(Icons.assignment_turned_in_outlined), text: 'Homework Feedback'),
                  Tab(icon: Icon(Icons.smart_toy_outlined), text: 'RAG Chatbot'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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

  Widget _buildKpiBanner() {
    return Container(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final approvalRate = (_stats['approval_rate_percent'] as num?)?.toDouble() ?? 0.0;

        return isMobile
            ? Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _kpiTile('Remarks Drafted', '${_stats['total_remarks_drafted'] ?? 0}', Icons.edit_note, Colors.indigo)),
                      const SizedBox(width: 8),
                      Expanded(child: _kpiTile('Faculty Approval', '${approvalRate.toStringAsFixed(1)}%', Icons.thumb_up_alt_outlined, Colors.green.shade700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _kpiTile('Papers Generated', '${_stats['question_papers_generated'] ?? 0}', Icons.menu_book, Colors.deepPurple)),
                      const SizedBox(width: 8),
                      Expanded(child: _kpiTile('RAG Queries', '${_stats['rag_chats_answered'] ?? 0}', Icons.forum_outlined, Colors.teal)),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _kpiTile('Remarks Drafted', '${_stats['total_remarks_drafted'] ?? 0}', Icons.edit_note, Colors.indigo)),
                  const SizedBox(width: 12),
                  Expanded(child: _kpiTile('Faculty Approval Rate', '${approvalRate.toStringAsFixed(1)}%', Icons.thumb_up_alt_outlined, Colors.green.shade700)),
                  const SizedBox(width: 12),
                  Expanded(child: _kpiTile('Question Papers Generated', '${_stats['question_papers_generated'] ?? 0}', Icons.menu_book, Colors.deepPurple)),
                  const SizedBox(width: 12),
                  Expanded(child: _kpiTile('RAG Queries Handled', '${_stats['rag_chats_answered'] ?? 0}', Icons.forum_outlined, Colors.teal)),
                ],
              );
      }),
    );
  }

  Widget _kpiTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 18,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Report Card Remarks Drafter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Generates personalized, encouraging remarks synthesized from marks, attendance, and observations. Mandatory "[AI draft — teacher approval pending]" tagging is enforced.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _studentNameCtrl,
                          decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _studentUserCtrl,
                          decoration: const InputDecoration(labelText: 'Student ID', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: _remarkClassCtrl, decoration: const InputDecoration(labelText: 'Allotted Class ID', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _examCtrl, decoration: const InputDecoration(labelText: 'Exam Session ID', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _marksCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Academic Marks %', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _attCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Attendance %', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Teacher Behavioural Observations', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF312E81), foregroundColor: Colors.white),
                      icon: _isGeneratingRemark
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isGeneratingRemark ? 'Drafting Remark...' : 'Draft AI Remark (Groq / Gemini)'),
                      onPressed: _isGeneratingRemark ? null : _handleGenerateRemark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Recent Remarks & Approval Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _remarks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final rem = _remarks[i];
              final isApproved = rem['status'] == 'approved';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: isApproved ? Colors.green.shade300 : Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(rem['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(rem['class_id'] ?? '', style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isApproved ? Colors.green.shade100 : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isApproved ? 'APPROVED' : 'APPROVAL PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isApproved ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rem['draft_remark'] ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isApproved && _currentRole == 'principal') ...[
                            TextButton(
                              onPressed: () => _decideRemark(rem, false),
                              child: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Approve & Publish'),
                              onPressed: () => _decideRemark(rem, true),
                            ),
                          ] else if (isApproved) ...[
                            const Icon(Icons.verified, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            const Text('Signed by Faculty', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ],
                  ),
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
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Automated Question Paper Blueprint Generator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Creates balanced exam blueprints adhering strictly to CBSE/ICSE distribution: 40% Easy, 40% Medium, 20% Hard across MCQs, Short Answer, and Analytical Long Answer questions.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qpSubjectCtrl,
                          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _qpClassCtrl,
                          decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _qpChaptersCtrl,
                    decoration: const InputDecoration(labelText: 'Chapters / Units to Cover', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _qpMarksCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Marks (e.g., 50 or 80)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF312E81), foregroundColor: Colors.white),
                      icon: _isGeneratingPaper
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.article_outlined),
                      label: Text(_isGeneratingPaper ? 'Compiling Question Paper...' : 'Generate Paper Blueprint'),
                      onPressed: _isGeneratingPaper ? null : _handleGenerateQuestionPaper,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Generated Exam Papers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questionPapers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final qp = _questionPapers[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: const Icon(Icons.assignment, color: Colors.indigo),
                  ),
                  title: Text('${qp['subject']} — ${qp['class_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Max Marks: ${qp['total_marks']}M | Created: ${qp['created_at']?.toString().split("T")[0]}'),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Inspect'),
                    onPressed: () => _showPaperPreviewDialog(qp),
                  ),
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
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Assignment Feedback Drafter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Drafts constructive, individualized qualitative feedback on student homework submissions for faculty review.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _feedbackAssignmentCtrl, decoration: const InputDecoration(labelText: 'Assignment title', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _feedbackStudentCtrl, decoration: const InputDecoration(labelText: 'Student name', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _feedbackSummaryCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Submission summary', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: _feedbackScoreCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Score', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _feedbackMaxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum score', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Draft Feedback'),
                    onPressed: _handleFeedbackDraft,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Assignment Feedbacks Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _feedbacks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No feedback drafts in queue. Click above to generate.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _feedbacks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final fb = _feedbacks[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${fb['student_name']} — ${fb['assignment_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(fb['draft_feedback'] ?? '', style: TextStyle(color: Colors.grey.shade800)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildRagChatTab() {
    return RagChatPanel(
      onSend: _askChat,
      inputHint: 'How can I help you today?',
      llmAvailable: SchoolAiService.isLlmConfigured,
      suggestions: const [
        AiChatSuggestion(
          label: 'Academic calendar',
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
          label: 'School timings',
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
          label: 'Fee payment',
          prompt: 'Fee payment',
          icon: Icons.payments_outlined,
          dummyReply: 'Fees are collected in four quarterly installments, due on the '
              '10th of April, July, October and January.\n'
              '• Pay by UPI, card or net banking from the Fee Desk.\n'
              '• A receipt (RCP-2026-XXXXX) is generated instantly.\n'
              '• A ₹50/week late fine applies after the 5-day grace period.',
        ),
        AiChatSuggestion(
          label: 'Library policy',
          prompt: 'Library policy',
          icon: Icons.local_library_outlined,
          dummyReply: 'Each borrower can issue up to 3 books for 14 days, renewable '
              'once if no hold is active.\n'
              '• Overdue fine: ₹5 per day.\n'
              '• Fines auto-post to the student fee ledger.\n'
              '• 1,200+ e-books are available in the Library section.',
        ),
      ],
    );
  }
}
